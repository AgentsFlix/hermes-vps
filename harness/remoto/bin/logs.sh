#!/usr/bin/env bash
# Últimas linhas de log do container do Hermes. Roda na VPS. Uso: logs.sh [linhas]
set -u
source "$(dirname "$0")/_alvo.sh"
docker logs --tail "${1:-150}" "$(hermes_container)" 2>&1
