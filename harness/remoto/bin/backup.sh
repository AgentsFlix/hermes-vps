#!/usr/bin/env bash
# Backup do volume /opt/data (config, chaves, sessões, memórias) em /opt/hermes/backups.
# Mantém os 5 mais recentes. Roda na VPS.
set -euo pipefail
cd /opt/hermes
mkdir -p backups
arq="backups/hermes-$(date -u +%Y%m%d-%H%M%S).tgz"
docker run --rm -v hermes_hermes-data:/opt/data:ro -v /opt/hermes/backups:/b alpine \
    sh -c "tar czf /b/$(basename "$arq") -C /opt/data ."
chmod 600 "$arq"
ls -1t backups/hermes-*.tgz | tail -n +6 | xargs -r rm -f
echo "backup: $arq ($(du -h "$arq" | cut -f1))"
