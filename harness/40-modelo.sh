#!/usr/bin/env bash
# Fase 5: o Hermes entra na assinatura ChatGPT/Codex do usuário por código de dispositivo.
#   roteiro              -> o que o usuário precisa ligar no ChatGPT ANTES (gate humano)
#   iniciar --confirmado -> dispara o login na VPS e imprime a URL e o código para o usuário
#   esperar [segundos]   -> espera o usuário terminar (exit 3 = ainda esperando; rode de novo)
#   concluir             -> grava provider e modelo, reinicia o Hermes, prova o status
#   status               -> `hermes auth status openai-codex`
source "$(dirname "$0")/lib.sh"

roteiro() {
    cat <<'TXT'
Antes de gerar o código, o usuário precisa ligar UMA opção no ChatGPT (uma vez só):

  1. Abra chatgpt.com e clique no seu nome (canto inferior esquerdo)
  2. Clique em Definições (a engrenagem)
  3. Entre em "Segurança e início de sessão"
  4. Role até o FIM da página
  5. Ative: "Ativar autorização por código de dispositivo para Codex"

Sem isso, o login fica esperando 15 minutos e termina em "timed out", sem dizer o motivo.
Quando o usuário responder "Ativei", rode: bash harness/40-modelo.sh iniciar --confirmado
TXT
}

case "${1:-}" in
    roteiro) roteiro ;;
    iniciar)
        [ "${2:-}" = "--confirmado" ] || { roteiro; echo; morrer "falta o --confirmado: só depois que o usuário disser que ativou a opção no ChatGPT"; }
        carregar_config
        vps "bash $REMOTO_DIR/bin/codex-login.sh iniciar"
        sleep 8
        saida="$(vps "bash $REMOTO_DIR/bin/codex-login.sh codigo")" || morrer "o código não apareceu. Veja: bash harness/logs.sh"
        url="$(printf '%s\n' "$saida" | sed -n 's/^URL=//p')"; cod="$(printf '%s\n' "$saida" | sed -n 's/^CODIGO=//p')"
        [ -n "$url" ] && [ -n "$cod" ] || morrer "não consegui ler URL e código da saída: $saida"
        echo
        ok "Diga ao usuário, exatamente assim:"
        cat <<MSG

  1. Abra no navegador, já logado no ChatGPT:  $url
  2. Digite este código:  $cod
  3. Confirme na página. O código vale 15 minutos.

MSG
        echo "Depois rode: bash harness/40-modelo.sh esperar" ;;
    esperar)
        carregar_config
        max="${2:-540}"
        vps "bash $REMOTO_DIR/bin/codex-login.sh esperar $max"; rc=$?
        case $rc in
            0) ok "o Hermes entrou na conta. Próximo: bash harness/40-modelo.sh concluir" ;;
            3) aviso "ainda esperando. Pergunte ao usuário se digitou o código e rode esperar de novo (o total é 15 min)"; exit 3 ;;
            *) morrer "o login falhou. Causa mais comum: a opção de código de dispositivo não foi ativada no ChatGPT (roteiro). Rode iniciar --confirmado de novo depois de ativar." ;;
        esac ;;
    concluir)
        carregar_config
        saida="$(vps "bash $REMOTO_DIR/bin/codex-login.sh concluir")" || morrer "concluir falhou: $saida"
        printf '%s\n' "$saida"
        printf '%s\n' "$saida" | grep -q 'provider=openai-codex' || morrer "model.provider não ficou openai-codex"
        printf '%s\n' "$saida" | grep -qi 'logged in' || aviso "auth status não disse 'logged in'; confira a saída acima"
        gravar_estado MODELO_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        ok "MODELO OK: o Hermes responde pela assinatura ChatGPT/Codex. Próximo: bash harness/50-alma.sh criar" ;;
    status) carregar_config; vps "bash $REMOTO_DIR/bin/codex-login.sh status" ;;
    *) echo "uso: bash harness/40-modelo.sh roteiro|iniciar --confirmado|esperar [seg]|concluir|status"; exit 2 ;;
esac
