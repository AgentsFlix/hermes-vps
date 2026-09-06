#!/usr/bin/env bash
# Roda NA VPS, como root, chamado por harness/10-instalar.sh. Idempotente.
# A senha do painel chega pelo stdin (linha PAINEL_SENHA=...). Nunca é impressa.
set -euo pipefail

HOSTNAME_TLS=""; MODO="publico"; USUARIO="admin"; SSH_PORT="22"
IMAGEM="${HERMES_IMAGEM:-nousresearch/hermes-agent:latest}"
DIR=/opt/hermes
while [ $# -gt 0 ]; do
    case "$1" in
        --hostname) HOSTNAME_TLS="$2"; shift 2 ;;
        --modo)     MODO="$2"; shift 2 ;;
        --usuario)  USUARIO="$2"; shift 2 ;;
        --ssh-port) SSH_PORT="$2"; shift 2 ;;
        --imagem)   IMAGEM="$2"; shift 2 ;;
        *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
    esac
done
log() { printf '[vps] %s\n' "$*"; }
morrer() { printf '[vps] ERRO: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || morrer "precisa rodar como root"
[ -t 0 ] && morrer "a senha tem que vir pelo stdin (o harness faz isso)"
SENHA="$(sed -n 's/^PAINEL_SENHA=//p' | head -1 | tr -d '\r')"
[ "${#SENHA}" -ge 12 ] || morrer "senha ausente ou curta no stdin"
case "$MODO" in publico) [ -n "$HOSTNAME_TLS" ] || morrer "--hostname obrigatório no modo publico" ;; tunel) ;; *) morrer "modo inválido" ;; esac

export DEBIAN_FRONTEND=noninteractive

# 1. pacotes base
log "pacotes base"
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg ufw openssl python3 >/dev/null

# 2. docker + compose
if ! command -v docker >/dev/null 2>&1; then
    log "instalando Docker (script oficial get.docker.com)"
    curl -fsSL https://get.docker.com | sh >/dev/null
fi
if ! docker compose version >/dev/null 2>&1; then
    apt-get install -y -qq docker-compose-plugin >/dev/null || morrer "sem docker compose"
fi
systemctl enable --now docker >/dev/null 2>&1 || true
log "docker $(docker --version | sed 's/,.*//') · compose $(docker compose version --short)"

# 3. firewall (ufw): SSH sempre; 80/443 só no modo publico
log "firewall"
ufw allow "$SSH_PORT/tcp" >/dev/null
if [ "$MODO" = publico ]; then
    ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ufw allow 443/udp >/dev/null
else
    ufw delete allow 80/tcp >/dev/null 2>&1 || true
    ufw delete allow 443/tcp >/dev/null 2>&1 || true
    ufw delete allow 443/udp >/dev/null 2>&1 || true
fi
ufw --force enable >/dev/null

# 4. arquivos
mkdir -p "$DIR/bin" "$DIR/backups"
cp "$DIR/harness/compose.yml" "$DIR/compose.yml"
cp "$DIR/harness/Caddyfile" "$DIR/Caddyfile"
cp "$DIR/harness/bin/"*.sh "$DIR/bin/"
chmod 755 "$DIR/bin/"*.sh

# 5. .env (preserva o segredo de sessão entre reinstalações)
SEGREDO=""
if [ -f "$DIR/.env" ]; then
    SEGREDO="$(sed -n 's/^PAINEL_SEGREDO=//p' "$DIR/.env" | head -1)"
fi
[ -n "$SEGREDO" ] || SEGREDO="$(openssl rand -hex 32)"
umask 077
{
    echo "# escrito por instalar-vps.sh em $(date -u +%Y-%m-%dT%H:%M:%SZ). Não versionar."
    echo "HERMES_IMAGEM=$IMAGEM"
    echo "MODO=$MODO"
    echo "HOSTNAME_TLS=$HOSTNAME_TLS"
    echo "PAINEL_USUARIO=$USUARIO"
    echo "PAINEL_SENHA=$SENHA"
    echo "PAINEL_SEGREDO=$SEGREDO"
    if [ "$MODO" = publico ]; then echo "COMPOSE_PROFILES=publico"; else echo "COMPOSE_PROFILES="; fi
} > "$DIR/.env"
chmod 600 "$DIR/.env"
unset SENHA

# 6. subir
cd "$DIR"
log "baixando a imagem $IMAGEM (pode demorar na primeira vez)"
docker compose pull -q
if [ "$MODO" = tunel ]; then
    docker compose rm -sf caddy >/dev/null 2>&1 || true
fi
docker compose up -d --remove-orphans
log "containers no ar"

# 7. esperar o painel
for _ in $(seq 1 90); do
    if curl -fsS --max-time 5 http://127.0.0.1:9119/api/status >/dev/null 2>&1; then break; fi
    sleep 2
done
status="$(curl -fsS --max-time 5 http://127.0.0.1:9119/api/status 2>/dev/null || true)"
[ -n "$status" ] || morrer "o painel não respondeu em 3 minutos. Veja: docker logs hermes"
printf '%s' "$status" | python3 -c '
import sys, json
d = json.load(sys.stdin)
ok = d.get("auth_required") is True and "basic" in (d.get("auth_providers") or [])
print("[vps] painel: auth_required=%s providers=%s versao=%s" % (d.get("auth_required"), d.get("auth_providers"), d.get("version") or d.get("agent_version") or "?"))
sys.exit(0 if ok else 1)
' || morrer "o gate de autenticação não ligou. Não exponha isso. Veja: docker logs hermes"

# 8. resultado
if [ "$MODO" = publico ]; then
    log "PRONTO. Painel: https://$HOSTNAME_TLS  (o certificado pode levar até 1 minuto na primeira vez)"
else
    log "PRONTO. Painel só por túnel: ssh -L 9119:127.0.0.1:9119 root@<vps>  e abra http://localhost:9119"
fi
