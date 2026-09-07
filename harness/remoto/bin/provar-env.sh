#!/usr/bin/env bash
# Prova que uma variável existe no .env do Hermes, imprimindo só nome e tamanho. Roda na VPS.
# Uso: provar-env.sh MATON_API_KEY ZERNIO_API_KEY
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"
for k in "$@"; do
    n="$(docker exec --user hermes "$C" sh -c "sed -n \"s/^$k=//p\" /opt/data/.env | head -1 | tr -d '\n' | wc -c" 2>/dev/null | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && echo "  $k: $n caracteres" || echo "  $k: ausente"
done
