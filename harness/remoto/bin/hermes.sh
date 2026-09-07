#!/usr/bin/env bash
# Roda o CLI do Hermes dentro do container certo (o shim da imagem rebaixa root para hermes).
# Uso: hermes.sh auth status openai-codex
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
exec docker exec "$(hermes_container)" hermes "$@"
