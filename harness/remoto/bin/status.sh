#!/usr/bin/env bash
# Estado dos containers e do painel. Roda na VPS.
set -u
cd /opt/hermes 2>/dev/null || { echo "Hermes não instalado (/opt/hermes)"; exit 1; }
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Image}}'
echo
curl -fsS --max-time 5 http://127.0.0.1:9119/api/status 2>/dev/null | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("painel      : auth_required=%s providers=%s" % (d.get("auth_required"), d.get("auth_providers")))
print("versao      :", d.get("version") or d.get("agent_version") or "?")
print("gateway     : %s (estado=%s, canais=%s)" % ("rodando" if d.get("gateway_running") else "parado", d.get("gateway_state"), d.get("gateway_platforms") or "nenhum"))
print("saude       :", d.get("overall"))
' 2>/dev/null || echo "painel      : sem resposta em 127.0.0.1:9119"
echo
echo "disco livre : $(df -h / | awk 'NR==2{print $4}')   memoria livre: $(free -m | awk '/Mem:/{print $7" MB"}')"
