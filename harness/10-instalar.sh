#!/usr/bin/env bash
# Fase 2: envia harness/remoto para a VPS e roda o instalador lá.
# Pré-requisitos: preflight OK (config/.estado) e senha válida (config/senha.local).
source "$(dirname "$0")/lib.sh"
carregar_config
carregar_estado
validar_senha_arquivo || morrer "corrija a senha antes: bash harness/05-senha.sh criar"

log "enviando harness/remoto para $SSH_USER@$VPS_HOST:$REMOTO_DIR/harness"
vps "mkdir -p $REMOTO_DIR/harness"
enviar "$RAIZ/harness/remoto/." "$SSH_USER@$VPS_HOST:$REMOTO_DIR/harness/"
ok "arquivos na VPS"

log "instalando (Docker, firewall, Hermes :latest$( [ "$MODO" = publico ] && echo ', Caddy com TLS')). Pode levar alguns minutos."
# A senha vai pelo stdin do SSH: não aparece em argumento, em log nem no chat.
vps "bash $REMOTO_DIR/harness/instalar-vps.sh --hostname '$HOSTNAME_TLS' --modo '$MODO' --usuario '$PAINEL_USUARIO' --ssh-port '$SSH_PORT'" < "$SENHA_ARQ"
rc=$?
if [ $rc -ne 0 ]; then
    morrer "o instalador remoto falhou (código $rc). Leia a saída acima; para logs: bash harness/logs.sh"
fi
rm -f "$SENHA_ARQ"
ok "senha local apagada ($SENHA_ARQ)"
gravar_estado INSTALADO_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
ok "INSTALADO. Próximo passo: bash harness/20-verificar.sh"
