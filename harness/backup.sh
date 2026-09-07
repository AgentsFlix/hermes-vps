#!/usr/bin/env bash
# Operação: roda /opt/hermes/bin/backup.sh na VPS.
source "$(dirname "$0")/lib.sh"
carregar_config
[ -f "$ESTADO" ] && carregar_estado && [ "${TEMPLATE:-0}" = 1 ] && morrer "modo template: atualização e backup são do painel da Hostinger (Gerenciador Docker → Gerenciar)"
vps "bash /opt/hermes/bin/backup.sh" "$@"
