#!/usr/bin/env bash
# Operação: troca a senha do painel. Fluxo: criar (arquivo abre) -> aplicar (envia e apaga).
source "$(dirname "$0")/lib.sh"
carregar_config
case "${1:-}" in
    criar)   bash "$RAIZ/harness/05-senha.sh" criar ;;
    aplicar)
        validar_senha_arquivo || exit 1
        vps "bash /opt/hermes/bin/senha.sh" < "$SENHA_ARQ"
        rm -f "$SENHA_ARQ"; ok "senha local apagada" ;;
    *) echo "uso: bash harness/senha.sh criar | aplicar"; exit 2 ;;
esac
