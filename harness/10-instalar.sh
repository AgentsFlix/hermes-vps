#!/usr/bin/env bash
# Fase 2: envia harness/remoto para a VPS e roda o instalador lá.
# Pré-requisitos: preflight OK (config/.estado) e senha do painel válida (config/acesso.local).
source "$(dirname "$0")/lib.sh"
carregar_config
carregar_estado
if [ "${TEMPLATE:-0}" = 1 ]; then
    log "modo template: subindo só os scripts de operação para $REMOTO_DIR/bin"
    vps "mkdir -p $REMOTO_DIR/bin"
    enviar "$RAIZ/harness/remoto/bin/." "$SSH_USER@$VPS_HOST:$REMOTO_DIR/bin/"
    vps "chmod 755 $REMOTO_DIR/bin/*.sh"
    log "fechando a porta do painel publicada no host (HTTP puro, aberta na internet); o Traefik continua servindo em $URL"
    vps "bash $REMOTO_DIR/bin/fechar-porta.sh" || morrer "não consegui fechar a porta publicada. Veja: bash harness/logs.sh"
    gravar_estado INSTALADO_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo; ok "PRONTO (modo template). Próximo passo: bash harness/20-verificar.sh"; exit 0
fi
validar_senha_arquivo || morrer "corrija a senha do painel antes: bash harness/05-senha.sh criar"

log "enviando harness/remoto para $SSH_USER@$VPS_HOST:$REMOTO_DIR/harness"
vps "mkdir -p $REMOTO_DIR/harness"
enviar "$RAIZ/harness/remoto/." "$SSH_USER@$VPS_HOST:$REMOTO_DIR/harness/"
ok "arquivos na VPS"

log "instalando (Docker, firewall, Hermes :latest$( [ "$MODO" = publico ] && echo ', Caddy com TLS')). Pode levar alguns minutos."
# Só a linha PAINEL_SENHA vai pelo stdin do SSH (a senha root não sai daqui): nada em argumento, log ou chat.
rc=0
grep '^PAINEL_SENHA=' "$ACESSO_ARQ" | vps "bash $REMOTO_DIR/harness/instalar-vps.sh --hostname '$HOSTNAME_TLS' --modo '$MODO' --usuario '$PAINEL_USUARIO' --ssh-port '$SSH_PORT'" || rc=$?
if [ $rc -ne 0 ]; then
    morrer "o instalador remoto falhou (código $rc). Leia a saída acima; para logs: bash harness/logs.sh"
fi
limpar_senha_painel
ok "senha do painel apagada de $ACESSO_ARQ (agora vive só na VPS); a senha root fica lá como credencial de gestão"
gravar_estado INSTALADO_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
ok "INSTALADO. Próximo passo: bash harness/20-verificar.sh"
