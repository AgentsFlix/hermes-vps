#!/usr/bin/env bash
# Remove variáveis do .env do Hermes. Roda na VPS. Uso: env-del.sh NOME [NOME...]
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"
[ $# -gt 0 ] || { echo "uso: env-del.sh NOME [NOME...]" >&2; exit 2; }
for k in "$@"; do
    case "$k" in [A-Z]*) ;; *) echo "nome inválido: $k" >&2; exit 1 ;; esac
    docker exec --user hermes "$C" sh -c "grep -v '^$k=' /opt/data/.env > /opt/data/.env.novo && mv /opt/data/.env.novo /opt/data/.env && chmod 600 /opt/data/.env"
    echo "$k: removida"
done
