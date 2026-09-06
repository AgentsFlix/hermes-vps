#!/usr/bin/env bash
# Fase 1: a senha do painel entra por arquivo, nunca pelo chat.
#   criar    -> escreve config/senha.local com o campo vazio e abre no editor
#   validar  -> confere tamanho e caracteres sem mostrar o valor
#   apagar   -> remove o arquivo (o instalador já faz isso ao terminar)
source "$(dirname "$0")/lib.sh"

acao="${1:-}"
case "$acao" in
    criar)
        if [ -f "$SENHA_ARQ" ] && validar_senha_arquivo >/dev/null 2>&1; then
            ok "já existe senha válida em $SENHA_ARQ (não vou sobrescrever)"; exit 0
        fi
        umask 077
        cat > "$SENHA_ARQ" <<'ARQ'
# Digite a senha do painel do Hermes depois do sinal de igual, sem aspas, e salve.
# 12 a 64 caracteres. Letras, números e . _ - ! @ % * + = : , ~ ^
# Sem espaço, aspas, $, #, \ ou crase. Este arquivo é apagado depois de usado.
PAINEL_SENHA=
ARQ
        abrir_editor "$SENHA_ARQ"
        ok "abri $SENHA_ARQ. Digite a senha, salve, e rode: bash harness/05-senha.sh validar"
        ;;
    validar)
        validar_senha_arquivo
        ;;
    apagar)
        rm -f "$SENHA_ARQ" && ok "apagado $SENHA_ARQ"
        ;;
    *)
        echo "uso: bash harness/05-senha.sh criar|validar|apagar"; exit 2 ;;
esac
