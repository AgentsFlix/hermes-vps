#!/usr/bin/env bash
# Fase 1: as senhas entram por arquivo (config/acesso.local), nunca pelo chat.
#   criar    -> garante o arquivo com os campos e abre no editor
#   validar  -> confere a senha do painel (tamanho, caracteres) sem mostrar o valor
#   limpar   -> apaga só o valor de PAINEL_SENHA (a senha root fica)
#   apagar   -> remove o arquivo inteiro (desinstalação)
source "$(dirname "$0")/lib.sh"

case "${1:-}" in
    criar)
        criar_acesso_esqueleto
        grep -q '^PAINEL_SENHA=' "$ACESSO_ARQ" || printf 'PAINEL_SENHA=\n' >> "$ACESSO_ARQ"
        abrir_editor "$ACESSO_ARQ"
        ok "abri $ACESSO_ARQ. Preencha, salve, e rode: bash harness/05-senha.sh validar" ;;
    validar)
        if tem_senha_root; then ok "senha root presente (não mostrada)"; else aviso "sem VPS_ROOT_SENHA: o agente só entra na VPS pela chave, sem reserva"; fi
        validar_senha_arquivo ;;
    limpar)  limpar_senha_painel && ok "PAINEL_SENHA apagada do arquivo (a senha root fica)" ;;
    apagar)  rm -f "$ACESSO_ARQ" && ok "apagado $ACESSO_ARQ" ;;
    *) echo "uso: bash harness/05-senha.sh criar|validar|limpar|apagar"; exit 2 ;;
esac
