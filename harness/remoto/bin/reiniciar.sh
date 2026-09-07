#!/usr/bin/env bash
# Reinicia o container do Hermes e espera o painel responder. Roda na VPS.
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
hermes_restart && echo "hermes de volta: $(hermes_status_url)" || { echo "o Hermes não voltou" >&2; exit 1; }
