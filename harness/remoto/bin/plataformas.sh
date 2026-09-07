#!/usr/bin/env bash
# Estado das plataformas do gateway, lido do /api/status. Roda na VPS.
# Uso: plataformas.sh            -> uma linha por plataforma
#      plataformas.sh telegram   -> exit 0 só se a plataforma estiver connected
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
json="$(curl -fsS --max-time 10 "$(hermes_status_url)")" || { echo "painel não respondeu" >&2; exit 1; }
printf '%s' "$json" | ALVO="${1:-}" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
p = d.get("gateway_platforms") or {}
alvo = os.environ.get("ALVO") or ""
if not alvo:
    print("gateway:", d.get("gateway_state"))
    for nome, v in sorted(p.items()):
        print("  %-12s %s%s" % (nome, v.get("state"), (" — " + str(v.get("error_message"))) if v.get("error_message") else ""))
    sys.exit(0)
v = p.get(alvo)
if not v:
    print("%s: não aparece no gateway (plataformas: %s)" % (alvo, ", ".join(sorted(p)) or "nenhuma")); sys.exit(1)
print("%s: %s%s" % (alvo, v.get("state"), (" — " + str(v.get("error_message"))) if v.get("error_message") else ""))
sys.exit(0 if v.get("state") == "connected" else 1)
'
