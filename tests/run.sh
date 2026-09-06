#!/usr/bin/env bash
# Testes locais do harness: sintaxe, shellcheck (se houver docker), compose, Caddyfile, página.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=tests/.tmp; mkdir -p "$TMP"
falhas=0
passo() { printf '\n== %s\n' "$*"; }

passo "sintaxe bash"
for f in harness/*.sh harness/remoto/*.sh harness/remoto/bin/*.sh tests/run.sh; do bash -n "$f" && echo "ok $f"; done

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    passo "shellcheck"
    docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -x -S warning \
        harness/*.sh harness/remoto/*.sh harness/remoto/bin/*.sh && echo "ok shellcheck" || falhas=$((falhas+1))
    passo "caddy validate"
    docker run --rm -e HOSTNAME_TLS=exemplo.hstgr.cloud -v "$PWD/harness/remoto/Caddyfile:/etc/caddy/Caddyfile:ro" \
        caddy:2 caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -q "Valid configuration" && echo "ok caddy" || falhas=$((falhas+1))
    passo "compose config"
    cat > "$TMP/.env" <<ENV
HERMES_IMAGEM=nousresearch/hermes-agent:latest
MODO=publico
HOSTNAME_TLS=exemplo.hstgr.cloud
PAINEL_USUARIO=admin
PAINEL_SENHA=senha-de-teste-local-123
PAINEL_SEGREDO=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
COMPOSE_PROFILES=publico
ENV
    docker compose -p hermes-teste -f harness/remoto/compose.yml --env-file "$TMP/.env" config >/dev/null && echo "ok compose" || falhas=$((falhas+1))
else
    echo "(sem docker: pulando shellcheck, caddy e compose)"
fi

passo "página do desktop (modo publico e tunel)"
for modo in publico tunel; do
    mkdir -p "$TMP/cfg-$modo"
    cat > config/hermes-vps.env <<CFG
VPS_HOST=203.0.113.10
SSH_USER=root
SSH_PORT=22
SSH_KEY=~/.ssh/hermes-vps
MODO=$modo
DOMINIO=
PAINEL_USUARIO=admin
CFG
    if [ "$modo" = publico ]; then url="https://srv000000.hstgr.cloud"; else url="http://localhost:9119"; fi
    printf 'IP_PUBLICO=203.0.113.10\nHOSTNAME_TLS=srv000000.hstgr.cloud\nURL=%s\nVERSAO=0.21.0\n' "$url" > config/.estado
    HERMES_VPS_SEM_ABRIR=1 bash harness/30-desktop.sh "$TMP/desktop-$modo" >/dev/null
    html="$TMP/desktop-$modo/Meu Hermes.html"
    grep -q '{{' "$html" && { echo "FALHA: placeholder sobrou ($modo)"; falhas=$((falhas+1)); }
    grep -q "$url" "$html" && echo "ok página $modo ($url)"
    if [ "$modo" = tunel ]; then ls "$TMP/desktop-$modo/" | grep -q "túnel" && echo "ok atalho do túnel"; fi
    if [ "$modo" = publico ]; then grep -q "Modo túnel" "$html" && { echo "FALHA: bloco de túnel na página pública"; falhas=$((falhas+1)); }; fi
done
rm -f config/hermes-vps.env config/.estado

passo "senha: validação sem eco"
printf 'PAINEL_SENHA=curta\n' > config/senha.local
if bash harness/05-senha.sh validar >/dev/null 2>&1; then echo "FALHA: aceitou senha curta"; falhas=$((falhas+1)); else echo "ok recusa curta"; fi
printf 'PAINEL_SENHA=tem espaco dentro 123\n' > config/senha.local
if bash harness/05-senha.sh validar >/dev/null 2>&1; then echo "FALHA: aceitou espaço"; falhas=$((falhas+1)); else echo "ok recusa espaço"; fi
printf 'PAINEL_SENHA=Senha.valida-2026!\n' > config/senha.local
saida="$(bash harness/05-senha.sh validar 2>&1)"
echo "$saida" | grep -q "Senha.valida" && { echo "FALHA: ecoou a senha"; falhas=$((falhas+1)); }
echo "$saida" | grep -q "senha válida" && echo "ok aceita válida sem ecoar"
rm -f config/senha.local

echo
if [ "$falhas" -eq 0 ]; then echo "TODOS OS TESTES PASSARAM"; else echo "$falhas FALHA(S)"; exit 1; fi
