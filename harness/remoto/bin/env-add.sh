#!/usr/bin/env bash
# Grava (ou substitui) variáveis no .env do Hermes, dentro do volume, como o usuário hermes.
# Roda NA VPS. As linhas KEY=valor chegam pelo stdin; nada é impresso além do nome e do tamanho.
# O código Python vai por `-c` (não por heredoc): heredoc ocuparia o stdin que carrega os dados.
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"
if [ -t 0 ]; then echo "as chaves têm que vir pelo stdin (o harness faz isso)" >&2; exit 2; fi
docker inspect -f '{{.State.Status}}' "$C" 2>/dev/null | grep -qx running || { echo "container do Hermes não está running" >&2; exit 1; }
docker exec -i --user hermes -e HERMES_ENV_PATH=/opt/data/.env "$C" \
    python3 -c "$(cat "$(dirname "$0")/env-upsert.py")"
