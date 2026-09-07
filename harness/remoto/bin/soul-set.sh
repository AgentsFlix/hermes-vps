#!/usr/bin/env bash
# Grava o SOUL.md (e opcionalmente o USER.md) do Hermes no volume, como o usuário hermes. Roda NA VPS.
# Uso: soul-set.sh SOUL.md < arquivo   |   soul-set.sh USER.md < arquivo
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"
alvo="${1:-}"
case "$alvo" in SOUL.md|USER.md) ;; *) echo "uso: soul-set.sh SOUL.md|USER.md < arquivo" >&2; exit 2 ;; esac
[ -t 0 ] && { echo "o conteúdo tem que vir pelo stdin" >&2; exit 2; }
docker inspect -f '{{.State.Status}}' "$C" 2>/dev/null | grep -qx running || { echo "container do Hermes não está running" >&2; exit 1; }
docker exec -i --user hermes "$C" sh -c "cat > /opt/data/$alvo.novo && mv /opt/data/$alvo.novo /opt/data/$alvo"
docker exec --user hermes "$C" sh -c "wc -c < /opt/data/$alvo" | sed "s/^/$alvo: /; s/\$/ bytes/"
