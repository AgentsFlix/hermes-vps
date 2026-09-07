#!/usr/bin/env bash
# Fase 3: critérios de aceite binários. Exit 0 só se TODOS passarem.
source "$(dirname "$0")/lib.sh"
carregar_config
carregar_estado

total=0; falhas=0
teste() { # teste "nome" comando...
    local nome="$1"; shift; total=$((total+1))
    if "$@" >/dev/null 2>&1; then ok "$nome"; else falha "$nome"; falhas=$((falhas+1)); fi
}

# 1. ssh
teste "SSH entra na VPS" vps true

# 2. container
C="${CONTAINER:-hermes}"
st="$(vps "docker inspect -f '{{.State.Status}}' $C" 2>/dev/null || true)"
teste "container $C está running" test "$st" = running

# 3. gate de autenticação (medido dentro da VPS, na rede do Docker)
if [ "${TEMPLATE:-0}" = 1 ]; then
    status_json="$(vps "bash $REMOTO_DIR/bin/_alvo.sh; source $REMOTO_DIR/bin/_alvo.sh; curl -fsS --max-time 10 \"\$(hermes_status_url)\"" 2>/dev/null || true)"
else
    status_json="$(vps "curl -fsS --max-time 10 http://127.0.0.1:9119/api/status" 2>/dev/null || true)"
fi
teste "/api/status responde no loopback da VPS" test -n "$status_json"
teste "auth_required = true" bash -c "printf '%s' \"\$1\" | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get(\"auth_required\") is True else 1)'" _ "$status_json"
teste "provedor de login 'basic' ativo" bash -c "printf '%s' \"\$1\" | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if \"basic\" in (d.get(\"auth_providers\") or []) else 1)'" _ "$status_json"
versao="$(printf '%s' "$status_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("version") or d.get("agent_version") or "")' 2>/dev/null || true)"
[ -n "$versao" ] && gravar_estado VERSAO "$versao"

# 4. acesso de fora
if [ "${TEMPLATE:-0}" = 1 ]; then
    nt="$(vps "docker ps --format '{{.Names}}' | grep -c traefik" 2>/dev/null || echo 0)"
    teste "traefik está running" test "$nt" -gt 0
    teste "HTTPS válido em $URL (certificado emitido)" curl -fsS --max-time 30 -o /dev/null "$URL/api/status"
    teste "página de login responde" bash -c "code=\$(curl -s --max-time 30 -o /dev/null -w '%{http_code}' '$URL/'); [ \"\$code\" = 200 ] || [ \"\$code\" = 302 ] || [ \"\$code\" = 401 ]"
    np="$(vps "docker port $C | wc -l" 2>/dev/null | tr -d ' ' || echo 1)"
    teste "nenhuma porta do painel publicada no host" test "$np" -eq 0
elif [ "$MODO" = publico ]; then
    sc="$(vps "docker inspect -f '{{.State.Status}}' hermes-caddy" 2>/dev/null || true)"
    teste "caddy está running" test "$sc" = running
    teste "HTTPS válido em $URL (certificado emitido)" curl -fsS --max-time 30 -o /dev/null "$URL/api/status"
    teste "página de login responde" bash -c "code=\$(curl -s --max-time 30 -o /dev/null -w '%{http_code}' '$URL/'); [ \"\$code\" = 200 ] || [ \"\$code\" = 302 ] || [ \"\$code\" = 401 ]"
    teste "porta 9119 NÃO responde de fora" bash -c "! curl -s --max-time 8 -o /dev/null http://$IP_PUBLICO:9119/api/status"
else
    porta_local=19119
    ssh "${SSH_OPTS[@]}" -f -N -L "$porta_local:127.0.0.1:9119" "$SSH_USER@$VPS_HOST" 2>/dev/null || true
    sleep 1
    teste "túnel SSH alcança o painel" curl -fsS --max-time 10 -o /dev/null "http://127.0.0.1:$porta_local/api/status"
    pkill -f "ssh.*-L $porta_local:127.0.0.1:9119" 2>/dev/null || true
    teste "porta 9119 NÃO responde de fora" bash -c "! curl -s --max-time 8 -o /dev/null http://$IP_PUBLICO:9119/api/status"
fi

echo
if [ "$falhas" -eq 0 ]; then
    gravar_estado VERIFICADO_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ok "VERIFICADO: $total/$total. Versão do Hermes: ${versao:-?}. Painel: $URL"
    ok "Próximo passo: bash harness/30-desktop.sh"
    exit 0
else
    falha "$falhas de $total falharam. Não siga para o desktop. Diagnóstico: bash harness/logs.sh"
    exit 1
fi
