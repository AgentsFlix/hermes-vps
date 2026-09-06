#!/usr/bin/env bash
# Operação: troca a senha do painel. Fluxo: criar (arquivo abre) -> aplicar (envia e limpa a linha).
source "$(dirname "$0")/lib.sh"
carregar_config
case "${1:-}" in
    criar)   bash "$RAIZ/harness/05-senha.sh" criar ;;
    aplicar)
        validar_senha_arquivo || exit 1
        grep '^PAINEL_SENHA=' "$ACESSO_ARQ" | vps "bash /opt/hermes/bin/senha.sh"
        limpar_senha_painel; ok "senha do painel apagada do arquivo local" ;;
    *) echo "uso: bash harness/senha.sh criar | aplicar"; exit 2 ;;
esac
