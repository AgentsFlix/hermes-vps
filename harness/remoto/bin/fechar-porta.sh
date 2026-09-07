#!/usr/bin/env bash
# Modo template: o compose da Hostinger publica a porta do painel numa porta aleatória do host,
# em HTTP puro e aberta na internet. O Traefik não precisa dela (fala com o container pela rede
# do Docker). Remove o bloco `ports:` do compose, com backup, e sobe de novo.
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
D="$(hermes_project_dir)"; F="$D/docker-compose.yml"
[ -f "$F" ] || { echo "compose não encontrado em $D" >&2; exit 1; }
if ! grep -qE '^\s*ports:' "$F"; then echo "já sem porta publicada"; exit 0; fi
cp -n "$F" "$F.antes-do-harness" 2>/dev/null || true
python3 - "$F" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
# remove "ports:" e as linhas "- ..." imediatamente abaixo, no mesmo nível de indentação
s=re.sub(r'\n([ \t]*)ports:\n(?:\1[ \t]+-[^\n]*\n)+', '\n', s)
open(p,"w").write(s)
PY
cd "$D" && docker compose up -d --remove-orphans >/dev/null 2>&1
for _ in $(seq 1 60); do curl -fsS --max-time 5 "$(hermes_status_url)" >/dev/null 2>&1 && break; sleep 2; done
pub="$(docker port "$(hermes_container)" 2>/dev/null | wc -l | tr -d ' ')"
[ "$pub" = 0 ] && echo "porta publicada removida (backup em $F.antes-do-harness)" || { echo "ainda há porta publicada: $(docker port "$(hermes_container)")" >&2; exit 1; }
