#!/usr/bin/env bash
# Atualiza para a imagem :latest com backup antes. Roda na VPS.
set -euo pipefail
cd /opt/hermes
bash bin/backup.sh
antes="$(docker inspect -f '{{.Image}}' hermes 2>/dev/null || true)"
docker compose pull -q
docker compose up -d --remove-orphans
depois="$(docker inspect -f '{{.Image}}' hermes 2>/dev/null || true)"
if [ "$antes" = "$depois" ]; then echo "imagem já estava na última versão"; else echo "imagem atualizada"; fi
docker image prune -f >/dev/null
for _ in $(seq 1 60); do curl -fsS --max-time 5 http://127.0.0.1:9119/api/status >/dev/null 2>&1 && break; sleep 2; done
bash bin/status.sh
