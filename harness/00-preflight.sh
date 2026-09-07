#!/usr/bin/env bash
# Fase 0: confere máquina local, chave SSH, acesso à VPS e decide o hostname HTTPS.
# Saída: config/.estado com IP_PUBLICO, HOSTNAME_TLS, URL. Exit 0 = pode instalar.
source "$(dirname "$0")/lib.sh"

log "harness hermes-vps · preflight"

# 1. o endereço vem do arquivo que o usuário preencheu (ou já está no config)
if [ ! -f "$ACESSO_ARQ" ]; then
    criar_acesso_esqueleto
    aviso "criei $ACESSO_ARQ: o usuário preenche o endereço da VPS e as duas senhas"
    abrir_editor "$ACESSO_ARQ"
    echo; aviso "peça para ele preencher e salvar, e rode de novo: bash harness/00-preflight.sh"
    exit 2
fi
if [ ! -f "$CONFIG" ] || ! grep -qE '^VPS_HOST=.+' "$CONFIG"; then
    endereco="$(campo_de "$ACESSO_ARQ" ACESSO_SSH)"
    if [ -z "$endereco" ]; then
        falha "falta o endereço da VPS em $ACESSO_ARQ (linha ACESSO_SSH)"
        aviso "peça ao usuário para trocar COLE_O_IP_AQUI pelo IP da VPS, salvar, e rode de novo"
        exit 2
    fi
    read -r u h pt <<< "$(parse_acesso "$endereco")" || { aviso "corrija a linha ACESSO_SSH em $ACESSO_ARQ e rode de novo"; exit 2; }
    escrever_config "$u" "$h" "$pt" "${MODO_INICIAL:-publico}"
    ok "endereço lido do arquivo: $u@$h porta $pt"
fi
carregar_config
ok "config: host=$VPS_HOST usuário=$SSH_USER porta=$SSH_PORT modo=$MODO painel_usuario=$PAINEL_USUARIO"

# 2. ferramentas locais
for t in ssh scp curl; do
    command -v "$t" >/dev/null 2>&1 || morrer "falta '$t' na sua máquina"
done
ok "ferramentas locais: ssh, scp, curl ($(ssh -V 2>&1 | cut -d, -f1))"
ssh_suporta_askpass || aviso "ssh antigo (< OpenSSH 8.4): o agente não vai conseguir entrar com a senha root; a alternativa é o ssh-copy-id pelo usuário"

# 3. chave SSH
if [ ! -f "$SSH_KEY" ]; then
    log "gerando chave SSH em $SSH_KEY (sem passphrase, só para esta VPS)"
    mkdir -p "$(dirname "$SSH_KEY")"
    ssh-keygen -q -t ed25519 -N "" -C "hermes-vps" -f "$SSH_KEY"
    ok "chave criada: $SSH_KEY.pub"
fi
[ -f "$SSH_KEY.pub" ] || morrer "existe $SSH_KEY mas não $SSH_KEY.pub"

# 4. acesso: chave; se não entrar, autoriza a chave com a senha root do arquivo
if ! ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" true 2>/dev/null; then
    if tem_senha_root && ssh_suporta_askpass; then
        log "chave ainda não autorizada: entrando com a senha root para autorizar"
        autorizar_chave >/dev/null || morrer "a senha root em $ACESSO_ARQ não entrou em $SSH_USER@$VPS_HOST:$SSH_PORT. Confira o IP e a senha (no hPanel dá para redefinir)."
        ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" true 2>/dev/null || morrer "autorizei a chave mas ela não entra. A VPS pode estar recusando chave (PubkeyAuthentication no no sshd_config)."
        ok "chave autorizada na VPS com a senha root; daqui em diante o agente entra com a chave (a senha fica em $ACESSO_ARQ como reserva)"
    else
        falha "não consegui entrar em $SSH_USER@$VPS_HOST com a chave, e não há VPS_ROOT_SENHA em $ACESSO_ARQ."
        cat <<MSG

  Duas saídas:
  a) o usuário preenche VPS_ROOT_SENHA em $ACESSO_ARQ (o agente abre o arquivo) e você roda de novo; ou
  b) o usuário roda no terminal dele:  ssh-copy-id -i "$SSH_KEY.pub" -p $SSH_PORT $SSH_USER@$VPS_HOST

MSG
        exit 3
    fi
fi
ok "SSH entra com a chave"

# 5. sonda remota (uma conexão só)
sonda="$(vps bash -s <<'REMOTO'
set -u
. /etc/os-release 2>/dev/null || true
echo "OS_ID=${ID:-?}"
echo "OS_VER=${VERSION_ID:-?}"
echo "ARCH=$(uname -m)"
echo "ROOT=$([ "$(id -u)" = 0 ] && echo 1 || echo 0)"
echo "DOCKER=$(command -v docker >/dev/null 2>&1 && docker --version 2>/dev/null | sed 's/,.*//' || echo nao)"
echo "COMPOSE=$(docker compose version --short 2>/dev/null || echo nao)"
echo "HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)"
echo "IP_PUBLICO=$(curl -4 -s --max-time 8 https://api.ipify.org || curl -4 -s --max-time 8 https://ifconfig.me || true)"
echo "PORTA80=$(ss -ltn 2>/dev/null | awk '$4 ~ /:80$/' | wc -l)"
echo "PORTA443=$(ss -ltn 2>/dev/null | awk '$4 ~ /:443$/' | wc -l)"
echo "MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)"
echo "DISCO_LIVRE_GB=$(df -BG / | awk 'NR==2{print $4}' | tr -d G)"
echo "HERMES_JA=$([ -f /opt/hermes/compose.yml ] && echo 1 || echo 0)"
TC="$(docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk '/hermes-agent/{print $1; exit}')"
echo "TEMPLATE_CONTAINER=$TC"
if [ -n "$TC" ]; then
  echo "TEMPLATE_HOST=$(docker inspect "$TC" --format '{{range $k,$v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' | sed -n 's/^traefik\.http\.routers\..*\.rule=.*Host(`\([^`]*\)`).*/\1/p' | head -1)"
  echo "TEMPLATE_DIR=$(docker inspect "$TC" --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}')"
  echo "TEMPLATE_VERSAO=$(docker exec "$TC" hermes --version 2>/dev/null | head -1 | sed -E 's/.*v([0-9.]+).*/\1/')"
  echo "TEMPLATE_USUARIO=$(sed -n 's/^ADMIN_USERNAME=//p' "$(docker inspect "$TC" --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}')/.env" 2>/dev/null | head -1)"
  echo "TEMPLATE_PUB=$(docker port "$TC" 2>/dev/null | wc -l)"
fi
REMOTO
)"
# shellcheck disable=SC2086
eval "$(printf '%s\n' "$sonda" | grep -E '^[A-Z_0-9]+=' | sed "s/'/'\\\\''/g; s/^\([A-Z_0-9]*\)=\(.*\)$/S_\1='\2'/")"   # valores com espaço (ex.: "Docker version 29.7.2") entram entre aspas

[ "${S_ROOT:-0}" = 1 ] || morrer "o usuário SSH precisa ser root (ou ter sudo sem senha; este harness usa root)"
case "${S_OS_ID:-}" in
    ubuntu|debian) ok "VPS: ${S_OS_ID} ${S_OS_VER} (${S_ARCH})" ;;
    *) morrer "VPS com ${S_OS_ID:-SO desconhecido}. O harness cobre Ubuntu 22.04/24.04 e Debian 12." ;;
esac
[ "${S_MEM_MB:-0}" -ge 1800 ] || aviso "só ${S_MEM_MB} MB de RAM. O Hermes usa ~1,8 GB em uso normal; abaixo de 2 GB vai sofrer."
[ "${S_DISCO_LIVRE_GB:-0}" -ge 8 ] || aviso "só ${S_DISCO_LIVRE_GB} GB livres no disco. A imagem precisa de alguns GB."
[ -n "${S_IP_PUBLICO:-}" ] || morrer "a VPS não conseguiu descobrir o próprio IP público (sem saída para a internet?)"
ok "IP público da VPS: $S_IP_PUBLICO"
if [ "$S_DOCKER" = nao ]; then log "Docker não instalado: o instalador instala"; else ok "Docker presente: $S_DOCKER (compose $S_COMPOSE)"; fi
[ "$S_HERMES_JA" = 1 ] && aviso "já existe /opt/hermes/compose.yml na VPS: a instalação vai atualizar sem apagar dados"

# 5b. template da Hostinger (Hermes já instalado pela plataforma, atrás do Traefik)
TEMPLATE=0
if [ "$S_HERMES_JA" = 0 ] && [ -n "${S_TEMPLATE_CONTAINER:-}" ] && [ "$(echo "$S_TEMPLATE_CONTAINER" | grep -c hermes)" = 1 ] && [ "$S_TEMPLATE_CONTAINER" != hermes ]; then
    TEMPLATE=1
    ok "TEMPLATE da Hostinger detectado: container $S_TEMPLATE_CONTAINER, Hermes ${S_TEMPLATE_VERSAO:-?}, painel em https://${S_TEMPLATE_HOST:-?}"
    [ "${S_TEMPLATE_PUB:-0}" != 0 ] && aviso "o template publica a porta do painel no host, em HTTP puro e aberta na internet; o instalador (modo template) fecha isso"
    log "modo template: o harness NÃO instala Docker, Hermes nem Caddy; só sobe os scripts de operação e faz o onboarding"
fi

# 6. hostname HTTPS
HOSTNAME_TLS=""
if [ "$TEMPLATE" = 1 ]; then
    HOSTNAME_TLS="$S_TEMPLATE_HOST"; URL="https://$HOSTNAME_TLS"
elif [ "$MODO" = publico ]; then
    if [ "${S_PORTA80:-0}" != 0 ] || [ "${S_PORTA443:-0}" != 0 ]; then
        if [ "$S_HERMES_JA" = 1 ]; then
            ok "portas 80/443 em uso pelo próprio Hermes (reinstalação)"
        else
            morrer "já tem algo escutando na porta 80 ou 443 da VPS (outro painel? EasyPanel?). Este harness quer uma VPS limpa, ou use MODO=tunel."
        fi
    fi
    if [ -n "$DOMINIO" ]; then
        ip_dom="$(resolver "$DOMINIO")"
        [ "$ip_dom" = "$S_IP_PUBLICO" ] || morrer "DOMINIO=$DOMINIO resolve para '${ip_dom:-nada}', e a VPS é $S_IP_PUBLICO. Ajuste o registro A e rode de novo."
        HOSTNAME_TLS="$DOMINIO"; ok "domínio próprio aponta para a VPS: $DOMINIO"
    elif [[ "$S_HOSTNAME_FQDN" == *.hstgr.cloud ]] && [ "$(resolver "$S_HOSTNAME_FQDN")" = "$S_IP_PUBLICO" ]; then
        HOSTNAME_TLS="$S_HOSTNAME_FQDN"
        ok "hostname da Hostinger resolve para a VPS: $HOSTNAME_TLS (hstgr.cloud está na Public Suffix List, então o Let's Encrypt trata cada VPS como domínio próprio)"
    else
        HOSTNAME_TLS="$(echo "$S_IP_PUBLICO" | tr . -).sslip.io"
        aviso "sem domínio e sem hostname resolvível: vou usar $HOSTNAME_TLS. Funciona, mas o sslip.io divide a cota de certificados do Let's Encrypt com todo mundo; se o certificado falhar, coloque um DOMINIO seu."
    fi
    URL="https://$HOSTNAME_TLS"
else
    URL="http://localhost:9119"
    ok "modo tunel: nada exposto além do SSH; o painel abre em $URL pelo túnel"
fi

: > "$ESTADO"
gravar_estado IP_PUBLICO "$S_IP_PUBLICO"
gravar_estado HOSTNAME_TLS "$HOSTNAME_TLS"
gravar_estado URL "$URL"
gravar_estado OS "${S_OS_ID}-${S_OS_VER}"
gravar_estado PREFLIGHT_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gravar_estado TEMPLATE "$TEMPLATE"
if [ "$TEMPLATE" = 1 ]; then
    gravar_estado CONTAINER "$S_TEMPLATE_CONTAINER"; gravar_estado TEMPLATE_DIR "$S_TEMPLATE_DIR"
    gravar_estado VERSAO "$S_TEMPLATE_VERSAO"; gravar_estado PAINEL_USUARIO_REAL "${S_TEMPLATE_USUARIO:-$PAINEL_USUARIO}"
fi
ok "estado gravado em $ESTADO"
echo
if [ "$TEMPLATE" = 1 ]; then ok "PREFLIGHT OK (modo template). Próximo passo: bash harness/10-instalar.sh"; else ok "PREFLIGHT OK. Próximo passo: bash harness/05-senha.sh validar"; fi
