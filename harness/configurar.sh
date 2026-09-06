#!/usr/bin/env bash
# Bootstrap: recebe o acesso SSH como o usuário colou (ex.: "ssh root@203.0.113.10",
# "root@203.0.113.10", "203.0.113.10", com ou sem "-p 2222"), escreve config/hermes-vps.env,
# cria config/acesso.local e abre para o usuário colar as senhas.
# Uso: bash harness/configurar.sh "ssh root@203.0.113.10" [publico|tunel]
source "$(dirname "$0")/lib.sh"

entrada="${1:-}"
modo="${2:-publico}"
[ -n "$entrada" ] || { echo "uso: bash harness/configurar.sh \"ssh root@IP\" [publico|tunel]"; exit 2; }

# porta: "-p 2222" ou "host:2222"
porta=22
if [[ "$entrada" =~ -p[[:space:]]+([0-9]+) ]]; then porta="${BASH_REMATCH[1]}"; fi
alvo="$(printf '%s' "$entrada" | sed -E 's/^[[:space:]]*ssh[[:space:]]+//; s/-p[[:space:]]+[0-9]+//; s/[[:space:]]//g')"
if [[ "$alvo" =~ ^(.*)@(.*)$ ]]; then usuario="${BASH_REMATCH[1]}"; host="${BASH_REMATCH[2]}"; else usuario=root; host="$alvo"; fi
if [[ "$host" =~ ^(.*):([0-9]+)$ ]]; then host="${BASH_REMATCH[1]}"; porta="${BASH_REMATCH[2]}"; fi
[[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || morrer "não entendi o host em: $entrada"
[[ "$usuario" =~ ^[a-z_][a-z0-9_-]*$ ]] || morrer "usuário SSH estranho: $usuario"
case "$modo" in publico|tunel) ;; *) morrer "modo tem que ser publico ou tunel" ;; esac

if [ -f "$CONFIG" ]; then cp "$CONFIG" "$CONFIG.bak"; fi
sed -e "s|^VPS_HOST=.*|VPS_HOST=$host|" -e "s|^SSH_USER=.*|SSH_USER=$usuario|" \
    -e "s|^SSH_PORT=.*|SSH_PORT=$porta|" -e "s|^MODO=.*|MODO=$modo|" "$CONFIG_EXEMPLO" > "$CONFIG"
ok "config: $usuario@$host porta $porta, modo $modo → $CONFIG"

criar_acesso_esqueleto
[ -n "${HERMES_VPS_SEM_ABRIR:-}" ] || abrir_editor "$ACESSO_ARQ"
ok "abri $ACESSO_ARQ para o usuário colar a senha root da VPS e escolher a senha do painel"
echo
echo "Diga ao usuário: \"Cole a senha root na linha VPS_ROOT_SENHA, escolha uma senha para o painel na linha PAINEL_SENHA, salve o arquivo e me responda: Feito.\""
