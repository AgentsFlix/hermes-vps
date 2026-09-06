#!/usr/bin/env bash
# Funções comuns do harness. Todo script faz: source "$(dirname "$0")/lib.sh"
# Regras: nunca imprimir segredo; toda função de rede falha alto; nada roda na VPS
# fora de harness/remoto.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$RAIZ/config"
CONFIG="$CONFIG_DIR/hermes-vps.env"
CONFIG_EXEMPLO="$CONFIG_DIR/hermes-vps.env.example"
SENHA_ARQ="$CONFIG_DIR/senha.local"
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

# Roda um comando na VPS. Uso: vps 'comando'   |   vps < script-por-stdin
vps() { ssh "${SSH_OPTS[@]}" "$SSH_USER@$VPS_HOST" "$@"; }

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

# --- senha (nunca ecoar) -----------------------------------------------------
# Lê a senha de config/senha.local para a variável PAINEL_SENHA_OK=1/0 sem imprimir.
# Regras: 12 a 64 caracteres, sem espaço, sem aspas, sem $ ` \ # (quebram .env do compose).
validar_senha_arquivo() {
    [ -f "$SENHA_ARQ" ] || { falha "não existe $SENHA_ARQ"; return 1; }
    local s
    s="$(sed -n 's/^PAINEL_SENHA=//p' "$SENHA_ARQ" | head -1 | tr -d '\r')"
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
