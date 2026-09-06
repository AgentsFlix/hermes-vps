#!/usr/bin/env bash
# Últimas linhas de log dos containers. Roda na VPS. Uso: logs.sh [linhas]
set -u
cd /opt/hermes || exit 1
docker compose logs --no-color --tail "${1:-150}"
