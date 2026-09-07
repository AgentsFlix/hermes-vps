#!/usr/bin/env bash
# A chave SSH desta instalação: qual é, onde está, e como tirar o acesso deste computador.
#   mostrar   -> arquivo, impressão digital e o que está autorizado na VPS
#   remover   -> tira a chave DESTE computador da VPS (a senha root continua valendo)
source "$(dirname "$0")/lib.sh"
carregar_config
fp() { ssh-keygen -lf "$SSH_KEY.pub" 2>/dev/null | awk '{print $2}'; }

case "${1:-mostrar}" in
    mostrar)
        [ -f "$SSH_KEY.pub" ] || morrer "não existe $SSH_KEY.pub neste computador"
        echo "arquivo da chave     : $SSH_KEY"
        echo "impressão digital    : $(fp)"
        echo "entra na VPS como    : $SSH_USER@$VPS_HOST porta $SSH_PORT"
        echo
        echo "autorizadas na VPS agora:"
        vps "while read -r l; do [ -n \"\$l\" ] && printf '%s\n' \"\$l\" | ssh-keygen -lf - 2>/dev/null | awk '{print \"  \" \$2, \$3}'; done < ~/.ssh/authorized_keys"
        echo
        echo "Quem tiver o arquivo acima entra na sua VPS como administrador."
        echo "O endereço ($SSH_USER@$VPS_HOST) não é segredo sozinho, mas aparece em qualquer print"
        echo "da tela Visão geral do hPanel. Com ele e a senha root, alguém entra sem a chave."
        echo "Para tirar este computador: bash harness/chave.sh remover" ;;
    remover)
        f="$(fp)"; [ -n "$f" ] || morrer "não consegui ler a impressão digital de $SSH_KEY.pub"
        aviso "vou remover a chave DESTE computador ($f) da VPS."
        aviso "depois disso o harness não opera mais a VPS daqui; a senha root do hPanel continua valendo."
        vps "bash $REMOTO_DIR/bin/chave-remover.sh '$f'" || morrer "não removi. Confira: bash harness/chave.sh mostrar"
        ok "removida. Para voltar a operar deste computador, rode o preflight de novo (ele reautoriza pela senha root)." ;;
    *) echo "uso: bash harness/chave.sh mostrar|remover"; exit 2 ;;
esac
