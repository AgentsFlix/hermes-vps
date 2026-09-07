#!/usr/bin/env bash
# Bootstrap. Dois jeitos:
#   bash harness/configurar.sh                      -> cria config/acesso.local e abre para o
#                                                      usuário colar endereço e senhas (o normal)
#   bash harness/configurar.sh "ssh root@IP" [modo] -> quando você já tem o endereço na mão
source "$(dirname "$0")/lib.sh"

modo="${2:-publico}"

if [ -z "${1:-}" ]; then
    criar_acesso_esqueleto
    [ -n "${HERMES_VPS_SEM_ABRIR:-}" ] || abrir_editor "$ACESSO_ARQ"
    ok "abri $ACESSO_ARQ"
    echo
    echo "Diga ao usuário: \"Nesse arquivo, troque COLE_O_IP_AQUI pelo IP da sua VPS, cole a senha"
    echo "root, escolha uma senha para o painel, salve e me responda: Feito.\""
    echo
    echo "Depois do Feito, rode: bash harness/00-preflight.sh"
    exit 0
fi

read -r usuario host porta <<< "$(parse_acesso "$1")" || exit 1
escrever_config "$usuario" "$host" "$porta" "$modo"
ok "config: $usuario@$host porta $porta, modo $modo → $CONFIG"

criar_acesso_esqueleto
# o endereço já veio por argumento: deixa a linha preenchida para o usuário não mexer nela
if grep -q '^ACESSO_SSH=' "$ACESSO_ARQ"; then
    tmp="$(mktemp)"; sed -E "s|^ACESSO_SSH=.*|ACESSO_SSH=ssh $usuario@$host|" "$ACESSO_ARQ" > "$tmp" && cat "$tmp" > "$ACESSO_ARQ"; rm -f "$tmp"
fi
[ -n "${HERMES_VPS_SEM_ABRIR:-}" ] || abrir_editor "$ACESSO_ARQ"
ok "abri $ACESSO_ARQ para o usuário colar a senha root da VPS e escolher a senha do painel"
echo
echo "Diga ao usuário: \"Cole a senha root na linha VPS_ROOT_SENHA, escolha uma senha para o painel"
echo "na linha PAINEL_SENHA, salve o arquivo e me responda: Feito.\""
