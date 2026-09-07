#!/usr/bin/env bash
# Sonda somente-leitura da VPS: o que já está instalado (template da Hostinger ou VPS limpa).
# Autoriza a chave do harness pela senha do arquivo se ainda não estiver. Não imprime valor de variável.
source "$(dirname "$0")/lib.sh"
carregar_config
tem_senha_root && ok "senha root presente (não mostrada)"
[ -f "$SSH_KEY" ] || { mkdir -p "$(dirname "$SSH_KEY")"; ssh-keygen -q -t ed25519 -N "" -C hermes-vps -f "$SSH_KEY"; }
if ! ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" true 2>/dev/null; then
    autorizar_chave >/dev/null && ok "chave autorizada pela senha root"
fi
ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" true && ok "SSH entra com a chave"
vps bash -s <<'REMOTO'
set -u
echo "=== SO / recursos"; . /etc/os-release; echo "$PRETTY_NAME $(uname -m) mem=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)MB disco_livre=$(df -BG / | awk 'NR==2{print $4}') host=$(hostname -f 2>/dev/null || hostname)"
echo "=== portas escutando"; ss -ltnp 2>/dev/null | awk 'NR>1{print $4, $NF}' | sed 's/users:((//; s/,.*//' | sort -u
echo "=== docker"; docker --version | sed 's/,.*//'; docker compose version --short
echo "=== projetos compose"; docker compose ls --all --format 'table {{.Name}}\t{{.Status}}\t{{.ConfigFiles}}'
echo "=== containers"; docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
C=$(docker ps --format '{{.Names}}' | grep -i hermes | head -1); echo "=== hermes: container=$C"
docker inspect "$C" --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
echo "env (só nomes): $(docker inspect "$C" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed 's/=.*//' | sort | tr '\n' ' ')"
docker inspect "$C" --format '{{range $k,$v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' | grep -iE 'traefik|compose' | sed -E 's/(basicauth|password|secret)=.*/\1=<omitido>/I'
echo "=== hermes: versão e HERMES_HOME"; docker exec "$C" hermes --version 2>&1 | head -3; docker exec "$C" sh -c 'echo HERMES_HOME=$HERMES_HOME; ls -la $HERMES_HOME 2>/dev/null | head -20'
IP=$(docker inspect "$C" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' | awk '{print $1}'); P=$(docker inspect "$C" --format '{{range $p,$_ := .Config.ExposedPorts}}{{$p}} {{end}}')
echo "=== /api/status: ip=$IP expostas=$P"; for port in 9119 8080 80 3000; do curl -fsS --max-time 5 "http://$IP:$port/api/status" 2>/dev/null | head -c 400 && { echo; echo "(porta $port)"; break; }; done
T=$(docker ps --format '{{.Names}}' | grep -i traefik | head -1); echo "=== traefik: container=$T"
docker inspect "$T" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
docker inspect "$T" --format '{{range .Args}}{{println .}}{{end}}' | grep -viE 'password|secret|token' | head -20
F=$(docker compose ls --all --format '{{.ConfigFiles}}' | tr ',' '\n' | grep -i hermes | head -1); echo "=== compose do hermes: $F"
[ -n "$F" ] && sed -E 's/(PASSWORD|SECRET|KEY|TOKEN)[A-Za-z_]*[:=].*/\1...=<omitido>/I' "$F"
D=$(dirname "$F"); echo "=== arquivos do projeto: $(ls -A "$D" 2>/dev/null | tr '\n' ' ')"; [ -f "$D/.env" ] && echo ".env (só nomes): $(sed 's/=.*//' "$D/.env" | tr '\n' ' ')"
REMOTO
