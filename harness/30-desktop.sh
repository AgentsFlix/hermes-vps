#!/usr/bin/env bash
# Fase 4: gera a pasta "Meu Hermes" no Desktop do usuário: uma página local com o
# acesso ao painel, os primeiros passos e os comandos de operação. Sem senha dentro.
source "$(dirname "$0")/lib.sh"
carregar_config
carregar_estado
command -v perl >/dev/null 2>&1 || morrer "preciso de perl (vem no macOS, Linux e Git Bash)"

DESTINO="${1:-$(pasta_desktop)/Meu Hermes}"
mkdir -p "$DESTINO"
so="$(so_local)"
ssh_cmd="ssh -i \"$SSH_KEY\" -p $SSH_PORT $SSH_USER@$VPS_HOST"
data="$(date +%d/%m/%Y)"
versao="${VERSAO:-não medida}"
[ "$MODO" = tunel ] && tunel_arq="Abrir Meu Hermes (túnel)" || tunel_arq=""

T_URL="$URL" T_HOST="$VPS_HOST" T_MODO="$MODO" T_SSH_CMD="$ssh_cmd" T_DATA="$data" \
T_USUARIO="${PAINEL_USUARIO_REAL:-$PAINEL_USUARIO}" T_VERSAO="$versao" T_REPO="$REPO_URL" T_HOSTNAME="${HOSTNAME_TLS:-$VPS_HOST}" \
T_TUNEL_ARQ="$tunel_arq" T_RAIZ="$RAIZ" \
perl -0pe '
    if ($ENV{T_MODO} eq "publico") { s/<!--TUNEL-->.*?<!--\/TUNEL-->//gs } else { s/<!--PUBLICO-->.*?<!--\/PUBLICO-->//gs }
    s/<!--\/?(TUNEL|PUBLICO)-->//g;
    for my $k (qw(URL HOST MODO SSH_CMD DATA USUARIO VERSAO REPO HOSTNAME TUNEL_ARQ RAIZ)) {
        my $v = $ENV{"T_$k"} // ""; s/\{\{$k\}\}/$v/g;
    }
' "$RAIZ/desktop/template.html" > "$DESTINO/Meu Hermes.html"
grep -q '{{' "$DESTINO/Meu Hermes.html" && morrer "sobrou placeholder na página gerada"
ok "página: $DESTINO/Meu Hermes.html"

if [ "$MODO" = tunel ]; then
    case "$so" in
        mac|linux)
            ext="command"; [ "$so" = linux ] && ext="sh"
            abrir="open"; [ "$so" = linux ] && abrir="xdg-open"
            cat > "$DESTINO/$tunel_arq.$ext" <<LAUNCH
#!/usr/bin/env bash
# Abre o túnel SSH até a VPS e o painel do Hermes no navegador. Feche esta janela para encerrar.
ssh -i "$SSH_KEY" -p $SSH_PORT -o ExitOnForwardFailure=yes -N -L 9119:127.0.0.1:9119 $SSH_USER@$VPS_HOST &
TUNEL=\$!
sleep 2
$abrir http://localhost:9119
echo "Túnel aberto. Painel em http://localhost:9119. Feche esta janela para encerrar."
wait \$TUNEL
LAUNCH
            chmod +x "$DESTINO/$tunel_arq.$ext"
            ok "atalho do túnel: $DESTINO/$tunel_arq.$ext" ;;
        wsl|windows)
            cat > "$DESTINO/$tunel_arq.bat" <<LAUNCH
@echo off
title Meu Hermes - tunel SSH
echo Abrindo tunel ate a VPS. Feche esta janela para encerrar.
start "" http://localhost:9119
ssh -i "$SSH_KEY" -p $SSH_PORT -o ExitOnForwardFailure=yes -N -L 9119:127.0.0.1:9119 $SSH_USER@$VPS_HOST
LAUNCH
            ok "atalho do túnel: $DESTINO/$tunel_arq.bat" ;;
    esac
fi

[ -n "${HERMES_VPS_SEM_ABRIR:-}" ] && so=nenhum
case "$so" in
    mac) open "$DESTINO/Meu Hermes.html" ;;
    linux) xdg-open "$DESTINO/Meu Hermes.html" >/dev/null 2>&1 || true ;;
    wsl) explorer.exe "$(wslpath -w "$DESTINO/Meu Hermes.html")" >/dev/null 2>&1 || true ;;
    windows) start "" "$DESTINO/Meu Hermes.html" >/dev/null 2>&1 || true ;;
esac
gravar_estado DESKTOP_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
ok "DESKTOP PRONTO. Painel $URL, usuário ${PAINEL_USUARIO_REAL:-$PAINEL_USUARIO}, senha a que o usuário digitou. Próximo: bash harness/40-modelo.sh roteiro"
