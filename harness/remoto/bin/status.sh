#!/usr/bin/env bash
# Estado dos containers e do painel. Roda na VPS.
set -u
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"; [ -n "$C" ] || { echo "nenhum container do Hermes rodando"; exit 1; }
docker ps --filter "name=$C" --filter name=caddy --filter name=traefik --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
echo
curl -fsS --max-time 5 "$(hermes_status_url)" 2>/dev/null | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("painel      : auth_required=%s providers=%s" % (d.get("auth_required"), d.get("auth_providers")))
print("versao      :", d.get("version") or d.get("agent_version") or "?")
print("gateway     : %s (estado=%s, canais=%s)" % ("rodando" if d.get("gateway_running") else "parado", d.get("gateway_state"), d.get("gateway_platforms") or "nenhum"))
print("saude       :", d.get("overall"))
' 2>/dev/null || echo "painel      : sem resposta em $(hermes_status_url)"
echo
echo "disco livre : $(df -h / | awk 'NR==2{print $4}')   memoria livre: $(free -m | awk '/Mem:/{print $7" MB"}')"
