#!/usr/bin/env bash
# Programa auxiliar do OpenSSH (SSH_ASKPASS). Imprime a senha root lida de config/acesso.local
# para o ssh, e só para ele. Não chame na mão: a saída é a senha.
sed -n 's/^VPS_ROOT_SENHA=//p' "${HERMES_VPS_ACESSO:?}" | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//'
