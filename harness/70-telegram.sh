#!/usr/bin/env bash
# Fase 8: o Hermes passa a atender pelo Telegram. Duas coisas vêm do usuário, as duas por arquivo:
# o token do bot (@BotFather) e o Id numérico dele (@userinfobot), que é quem pode falar com o bot.
#   roteiro  -> o que o usuário faz no Telegram (gate humano; você não consegue fazer por ele)
#   criar    -> cria config/telegram.local e abre no editor
#   validar  -> confere formato do token e dos ids, sem mostrar o token
#   aplicar  -> grava no .env do Hermes, prova, reinicia e espera a plataforma conectar
#   provar   -> estado das plataformas do gateway
source "$(dirname "$0")/lib.sh"
TELEGRAM_ARQ="$CONFIG_DIR/telegram.local"

roteiro() {
    cat <<'TXT'
Duas coisas o usuário pega no Telegram, no celular ou no app do computador:

  O TOKEN DO BOT
  1. Abra uma conversa com @BotFather
  2. Mande /newbot
  3. Escolha um nome (o que aparece na conversa) e um usuário terminado em "bot"
  4. Ele devolve uma linha tipo 8123456789:AAF... — esse é o token

  O ID DELE
  5. Abra uma conversa com @userinfobot
  6. Mande /start
  7. Ele responde com "Id: 123456789" — esse número é o dele

O Id é quem pode falar com o bot: sem ele na lista, o Hermes ignora a mensagem em silêncio.
Depois disso rode: bash harness/70-telegram.sh criar
TXT
}

valida_token() { # não imprime o token
    local t; t="$(campo_de "$TELEGRAM_ARQ" TELEGRAM_BOT_TOKEN)"
    [ -n "$t" ] || { falha "TELEGRAM_BOT_TOKEN vazio"; return 2; }
    [[ "$t" =~ ^[0-9]{6,12}:[A-Za-z0-9_-]{30,50}$ ]] || {
        falha "o token não tem a forma do Telegram (números, dois-pontos, letras). Copie a linha inteira que o @BotFather mandou, sem espaço"; return 1; }
    ok "token presente (${#t} caracteres, formato do BotFather). O valor não é mostrado."
}
valida_ids() {
    local u; u="$(campo_de "$TELEGRAM_ARQ" TELEGRAM_ALLOWED_USERS)"
    [ -n "$u" ] || { falha "TELEGRAM_ALLOWED_USERS vazio: sem isso qualquer pessoa que achar o bot fala com o seu agente"; return 2; }
    [[ "$u" =~ ^[0-9]+(,[0-9]+)*$ ]] || { falha "os ids têm que ser só números, separados por vírgula, sem espaço (o @userinfobot devolve um número)"; return 1; }
    ok "ids autorizados: $u"
}

case "${1:-}" in
    roteiro) roteiro ;;
    criar)
        if [ ! -f "$TELEGRAM_ARQ" ]; then
            umask 077
            cat > "$TELEGRAM_ARQ" <<'ARQ'
# Cole depois do sinal de igual, sem aspas e sem espaço, e salve. Fica fora do git,
# e o token é apagado daqui depois de gravado na VPS.
#
# Token do bot, do @BotFather (a linha inteira, tipo 8123456789:AAF...)
TELEGRAM_BOT_TOKEN=
#
# Seu Id numérico, do @userinfobot. Só quem estiver aqui consegue falar com o bot.
# Mais de uma pessoa: separe por vírgula, sem espaço.
TELEGRAM_ALLOWED_USERS=
ARQ
        fi
        abrir_editor "$TELEGRAM_ARQ"
        ok "abri $TELEGRAM_ARQ. Diga ao usuário: \"Cole o token do bot e o seu Id, salve, e me responda: Feito.\"" ;;
    validar)
        [ -f "$TELEGRAM_ARQ" ] || morrer "não existe $TELEGRAM_ARQ. Rode: bash harness/70-telegram.sh criar"
        rc=0; valida_token || rc=$?; valida_ids || rc=$((rc?rc:$?))
        [ "$rc" -eq 0 ] || exit "$rc" ;;
    aplicar)
        carregar_config; carregar_estado
        bash "$0" validar >/dev/null || morrer "corrija o arquivo antes: bash harness/70-telegram.sh criar"
        log "gravando o token e a lista de ids no .env do Hermes"
        grep -E '^TELEGRAM_(BOT_TOKEN|ALLOWED_USERS)=.+' "$TELEGRAM_ARQ" | vps "bash $REMOTO_DIR/bin/env-add.sh" || morrer "não consegui gravar"
        prova="$(vps "bash $REMOTO_DIR/bin/provar-env.sh TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS")"
        printf '%s\n' "$prova"
        printf '%s\n' "$prova" | grep -q "TELEGRAM_BOT_TOKEN: [1-9]" || morrer "o token não chegou ao .env. O arquivo continua aqui; não apaguei nada."
        log "reiniciando o Hermes para o gateway abrir a conexão com o Telegram"
        reiniciar_hermes
        log "esperando a plataforma conectar (até 60 s)"
        conectou=0
        for _ in $(seq 1 12); do
            if vps "bash $REMOTO_DIR/bin/plataformas.sh telegram" >/dev/null 2>&1; then conectou=1; break; fi
            sleep 5
        done
        vps "bash $REMOTO_DIR/bin/plataformas.sh"
        if [ "$conectou" = 1 ]; then
            tmp="$(mktemp)"; sed -E 's/^TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=/' "$TELEGRAM_ARQ" > "$tmp" && cat "$tmp" > "$TELEGRAM_ARQ"; rm -f "$tmp"
            ok "token apagado de $TELEGRAM_ARQ (agora vive só na VPS); a lista de ids fica, não é segredo"
            gravar_estado TELEGRAM_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            ok "TELEGRAM OK. Diga ao usuário para abrir o bot no Telegram e mandar um oi."
        else
            falha "o Telegram não conectou. O token continua em $TELEGRAM_ARQ."
            aviso "causa mais comum: token colado pela metade, ou outro programa já usando o mesmo bot (o Telegram só deixa um)."
            aviso "veja o motivo: bash harness/logs.sh 200"
            exit 1
        fi ;;
    provar) carregar_config; vps "bash $REMOTO_DIR/bin/plataformas.sh" ;;
    *) echo "uso: bash harness/70-telegram.sh roteiro|criar|validar|aplicar|provar"; exit 2 ;;
esac
