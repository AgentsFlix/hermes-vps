#!/usr/bin/env bash
# Operação: roda /opt/hermes/bin/status.sh na VPS.
source "$(dirname "$0")/lib.sh"
carregar_config
vps "bash /opt/hermes/bin/status.sh" "$@"
