#!/usr/bin/env bash
# Funções comuns do harness. Todo script faz: source "$(dirname "$0")/lib.sh"
# Regras: nunca imprimir segredo; toda função de rede falha alto; nada roda na VPS
# fora de harness/remoto.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${HERMES_VPS_CONFIG_DIR:-$RAIZ/config}"   # os testes apontam para um diretório próprio; o do usuário nunca é tocado
CONFIG="$CONFIG_DIR/hermes-vps.env"
CONFIG_EXEMPLO="$RAIZ/config/hermes-vps.env.example"
ACESSO_ARQ="$CONFIG_DIR/acesso.local"   # o que o usuário cola: senha root da VPS e senha do painel
ESTADO="$CONFIG_DIR/.estado"
# shellcheck disable=SC2034  # usados pelos scripts que fazem source
REMOTO_DIR="/opt/hermes"
# shellcheck disable=SC2034
REPO_URL="https://github.com/AgentsFlix/hermes-vps"

log()    { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()     { printf '\033[32m✔\033[0m %s\n' "$*"; }
aviso()  { printf '\033[33m!\033[0m %s\n' "$*"; }
falha()  { printf '\033[31m✖\033[0m %s\n' "$*" >&2; }
morrer() { falha "$@"; exit 1; }

# --- sistema local -----------------------------------------------------------
so_local() {
    case "$(uname -s)" in
        Darwin) echo mac ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi ;;
        MINGW*|MSYS*|CYGWIN*) echo windows ;;
        *) echo desconhecido ;;
    esac
}

# Abre um arquivo no editor de texto do sistema, para o usuário digitar algo
# que o agente não deve ver (senha). Não bloqueia.
abrir_editor() {
    local f="$1"
    case "$(so_local)" in
        mac)     open -e "$f" ;;
        wsl)     notepad.exe "$(wslpath -w "$f")" >/dev/null 2>&1 & ;;
        windows) notepad "$f" >/dev/null 2>&1 & ;;
        linux)   (xdg-open "$f" >/dev/null 2>&1 || "${EDITOR:-nano}" "$f") & ;;
        *)       aviso "abra você mesmo: $f" ;;
    esac
}

# Pasta Desktop do usuário, inclusive quando o harness roda no WSL ou no Git Bash.
pasta_desktop() {
    case "$(so_local)" in
        wsl)
            local up
            up="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)"
            if [ -n "$up" ]; then wslpath "$up"/Desktop; else echo "$HOME/Desktop"; fi ;;
        windows) echo "${USERPROFILE:-$HOME}/Desktop" ;;
        *) echo "$HOME/Desktop" ;;
    esac
}

# Resolve um nome para IPv4 sem depender de dig (não existe no Windows).
resolver() {
    local nome="$1" ip=""
    if command -v python3 >/dev/null 2>&1; then
        ip="$(python3 -c "import socket,sys; print(socket.gethostbyname(sys.argv[1]))" "$nome" 2>/dev/null || true)"
    fi
    if [ -z "$ip" ] && command -v nslookup >/dev/null 2>&1; then
        ip="$(nslookup "$nome" 2>/dev/null | awk '/^Address: /{print $2}' | grep -E '^[0-9.]+$' | head -1 || true)"
    fi
    echo "$ip"
}

# --- config ------------------------------------------------------------------
carregar_config() {
    [ -f "$CONFIG" ] || morrer "falta $CONFIG. Copie de $CONFIG_EXEMPLO e preencha VPS_HOST."
    set -a
    # shellcheck source=/dev/null
    . "$CONFIG"
    set +a
    VPS_HOST="${VPS_HOST:-}"
    SSH_USER="${SSH_USER:-root}"
    SSH_PORT="${SSH_PORT:-22}"
    SSH_KEY="${SSH_KEY:-$HOME/.ssh/hermes-vps}"
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
    MODO="${MODO:-publico}"
    DOMINIO="${DOMINIO:-}"
    PAINEL_USUARIO="${PAINEL_USUARIO:-admin}"

    [ -n "$VPS_HOST" ] || morrer "VPS_HOST está vazio em $CONFIG"
    case "$MODO" in publico|tunel) ;; *) morrer "MODO tem que ser publico ou tunel (está: $MODO)" ;; esac
    [[ "$PAINEL_USUARIO" =~ ^[a-z0-9._-]{3,32}$ ]] || morrer "PAINEL_USUARIO inválido: só a-z, 0-9, ponto, hífen, 3 a 32 caracteres"
    [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || morrer "SSH_PORT inválida"

    SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new
              -o LogLevel=ERROR -i "$SSH_KEY" -p "$SSH_PORT")
    export VPS_HOST SSH_USER SSH_PORT SSH_KEY MODO DOMINIO PAINEL_USUARIO
}

# --- arquivo de acesso ---------------------------------------------------------
# Lê um campo de config/acesso.local sem imprimir. Uso: campo_acesso PAINEL_SENHA
campo_acesso() { sed -n "s/^$1=//p" "$ACESSO_ARQ" 2>/dev/null | head -1 | tr -d '\r' | sed 's/[[:space:]]*$//'; }
tem_senha_root() { [ -n "$(campo_acesso VPS_ROOT_SENHA)" ]; }

# OpenSSH >= 8.4 é o mínimo para o agente conseguir entrar na VPS pela senha do arquivo.
ssh_suporta_askpass() {
    local v; v="$(ssh -V 2>&1 | sed -n 's/^OpenSSH_\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')"
    [ -n "$v" ] || return 1
    local maior menor; read -r maior menor <<< "$v"
    [ "$maior" -gt 8 ] || { [ "$maior" -eq 8 ] && [ "$menor" -ge 4 ]; }
}

# ssh usando a senha root do arquivo de acesso (sem chave). Uso igual ao vps().
# O OpenSSH lê a senha de harness/askpass.sh, que a lê do arquivo: nada em argumento ou terminal.
vps_por_senha() {
    tem_senha_root || morrer "sem VPS_ROOT_SENHA em $ACESSO_ARQ"
    ssh_suporta_askpass || morrer "seu ssh é antigo demais (precisa OpenSSH 8.4+)"
    [ -x "$RAIZ/harness/askpass.sh" ] || chmod +x "$RAIZ/harness/askpass.sh"   # zip baixado perde o bit de execução
    SSH_ASKPASS="$RAIZ/harness/askpass.sh" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}" HERMES_VPS_ACESSO="$ACESSO_ARQ" \
        ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive \
            -o NumberOfPasswordPrompts=1 -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new \
            -o LogLevel=ERROR -p "$SSH_PORT" "$SSH_USER@$VPS_HOST" "$@"
}

# Autoriza a chave do harness na VPS usando a senha root (o que o ssh-copy-id faria).
autorizar_chave() {
    [ -f "$SSH_KEY.pub" ] || morrer "não existe $SSH_KEY.pub"
    vps_por_senha 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys' < "$SSH_KEY.pub"
}

# Roda um comando na VPS. Chave primeiro; se a conexão falhar (ssh devolve 255) e houver
# senha root no arquivo, reautoriza a chave com a senha e tenta de novo.
# Uso: vps 'comando'   |   vps 'comando' < entrada
vps() {
    local rc=0
    ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" "$@" || rc=$?
    if [ "$rc" -eq 255 ] && tem_senha_root; then
        aviso "a chave não entrou em $VPS_HOST; usando a senha root para autorizar a chave de novo" >&2
        autorizar_chave >/dev/null || morrer "nem a senha root entrou. Confira VPS_HOST e a senha em $ACESSO_ARQ (dá para redefinir no hPanel)."
        rc=0; ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" "$@" || rc=$?
    fi
    return "$rc"
}

# Copia arquivos para a VPS. Uso: enviar origem... destino
enviar() { scp -q -r -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -i "$SSH_KEY" -P "$SSH_PORT" "$@"; }

carregar_estado() {
    [ -f "$ESTADO" ] || morrer "falta $ESTADO. Rode antes: bash harness/00-preflight.sh"
    set -a
    # shellcheck source=/dev/null
    . "$ESTADO"
    set +a
}

gravar_estado() {
    # gravar_estado CHAVE valor  (append ou substitui)
    local k="$1" v="$2"
    touch "$ESTADO"
    if grep -q "^$k=" "$ESTADO"; then
        local tmp; tmp="$(mktemp)"; grep -v "^$k=" "$ESTADO" > "$tmp"; mv "$tmp" "$ESTADO"
    fi
    printf '%s=%s\n' "$k" "$v" >> "$ESTADO"
}

# --- senhas (nunca ecoar) ----------------------------------------------------
# Valida a senha do painel em config/acesso.local sem imprimir.
# Regras: 12 a 64 caracteres, sem espaço, sem aspas, sem $ ` \ # (quebram .env do compose).
validar_senha_arquivo() {
    [ -f "$ACESSO_ARQ" ] || { falha "não existe $ACESSO_ARQ"; return 1; }
    local s
    s="$(campo_acesso PAINEL_SENHA)"
    local n=${#s}
    if [ "$n" -lt 12 ]; then falha "senha curta: $n caracteres (mínimo 12)"; return 1; fi
    if [ "$n" -gt 64 ]; then falha "senha longa: $n caracteres (máximo 64)"; return 1; fi
    if [[ ! "$s" =~ ^[A-Za-z0-9._!@%*+=:,~^-]+$ ]]; then
        falha "senha com caractere não permitido. Use letras, números e . _ - ! @ % * + = : , ~ ^ (sem espaço, aspas, \$, #, \\ ou crase)"
        return 1
    fi
    ok "senha válida ($n caracteres). O valor não é mostrado."
    return 0
}

# Apaga só o valor da senha do painel (a senha root fica: é a credencial de gestão do agente).
limpar_senha_painel() {
    [ -f "$ACESSO_ARQ" ] || return 0
    local tmp; tmp="$(mktemp)"
    sed 's/^PAINEL_SENHA=.*/PAINEL_SENHA=/' "$ACESSO_ARQ" > "$tmp" && cat "$tmp" > "$ACESSO_ARQ"; rm -f "$tmp"
    chmod 600 "$ACESSO_ARQ" 2>/dev/null || true
}

# Cria config/acesso.local com os campos vazios, permissão 600. Não sobrescreve.
criar_acesso_esqueleto() {
    [ -f "$ACESSO_ARQ" ] && return 0
    umask 077
    cat > "$ACESSO_ARQ" <<'ARQ'
#  ACESSO À SUA VPS
#  Preencha as duas linhas em destaque, salve e volte ao chat: Feito


#  1 . SENHA ROOT DA VPS
#  No painel da Hostinger: VPS, Configurações principais, Alterar senha do root
#  Não anotou a sua? Gere uma nova ali e cole aqui
#  Cole logo depois do  =  , sem aspas e sem espaço

VPS_ROOT_SENHA=


#  2 . SENHA DO PAINEL DO SEU AGENTE
#  Esta você inventa. É com ela que você entra no painel pelo navegador
#  De 12 a 64 caracteres
#  Pode usar   letras, números e  . _ - ! @ % * + = : , ~ ^
#  Não pode    espaço, aspas, $, #, barra invertida, crase

PAINEL_SENHA=


#  A senha do painel some daqui assim que entra na VPS
#  Nenhum valor deste arquivo aparece no chat
ARQ
}

# --- onboarding (fases 40, 50 e 60) --------------------------------------------
# shellcheck disable=SC2034
CHAVES_ARQ="$CONFIG_DIR/chaves.local"    # o que o usuário cola: chaves do Maton e do Zernio
# shellcheck disable=SC2034
ALMA_ARQ="$CONFIG_DIR/alma.env"          # respostas do intake (não é segredo)

# Lê um campo KEY=valor de um arquivo sem imprimir. Uso: campo_de ARQUIVO CHAVE
campo_de() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

# Reinicia só o container do Hermes na VPS (relê config.yaml, .env e SOUL.md) e espera o painel.
reiniciar_hermes() {
    vps "bash $REMOTO_DIR/bin/reiniciar.sh" >/dev/null || morrer "o Hermes não voltou depois do restart. Veja: bash harness/logs.sh"
}

# Roda o hermes DENTRO do container, como o usuário hermes (o shim da imagem já rebaixa root).
# Uso: hermes_na_vps 'auth status openai-codex'
hermes_na_vps() { vps "bash $REMOTO_DIR/bin/hermes.sh $*"; }
