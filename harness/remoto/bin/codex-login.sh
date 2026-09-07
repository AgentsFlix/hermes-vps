#!/usr/bin/env bash
# Login do Hermes na assinatura ChatGPT/Codex por código de dispositivo. Roda NA VPS.
#   iniciar   -> dispara `hermes auth add openai-codex` dentro do container, em segundo plano, com log
#   codigo    -> imprime a URL e o código que o usuário digita (só isso; o log não tem segredo)
#   esperar N -> espera até N segundos pelo fim do login. exit 0 = entrou, 3 = ainda esperando, 1 = falhou
#   concluir  -> grava provider e modelo no config, reinicia o Hermes e prova o status
#   status    -> `hermes auth status openai-codex`
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"
LOG="${CODEX_LOG:-/opt/hermes/codex-login.log}"
MODELO="${HERMES_MODELO_CODEX:-gpt-5.6-terra}"
limpo() { sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$LOG" 2>/dev/null || true; }

case "${1:-}" in
    iniciar)
        docker inspect -f '{{.State.Status}}' "$C" 2>/dev/null | grep -qx running || { echo "container do Hermes não está running" >&2; exit 1; }
        rm -f "$LOG"
        # sem -t: o fluxo de device code não precisa de TTY e não faz pergunta nenhuma
        nohup docker exec "$C" hermes auth add openai-codex > "$LOG" 2>&1 &
        echo "login iniciado (pid $!). Em ~8 s rode: codigo" ;;
    codigo)
        for _ in $(seq 1 20); do
            if limpo | grep -q "Enter this code"; then break; fi
            sleep 1
        done
        if ! limpo | grep -q "Enter this code"; then
            echo "o código ainda não apareceu. Log até agora:" >&2; limpo | tail -5 >&2; exit 3
        fi
        url="$(limpo | grep -A1 'Open this URL' | tail -1 | tr -d ' ')"
        cod="$(limpo | grep -A1 'Enter this code' | tail -1 | tr -d ' ')"
        printf 'URL=%s\nCODIGO=%s\n' "$url" "$cod" ;;
    esperar)
        max="${2:-540}"; t=0
        while [ "$t" -lt "$max" ]; do
            if limpo | grep -qE 'Added .*credential|Saved .*credentials|Login successful'; then echo "ENTROU"; exit 0; fi
            if limpo | grep -qiE 'timed out|Error|Failed|Traceback|cancelled'; then echo "FALHOU:"; limpo | tail -8; exit 1; fi
            sleep 5; t=$((t+5))
        done
        echo "AINDA ESPERANDO (${t}s). O usuário já digitou o código na página?"; exit 3 ;;
    concluir)
        limpo | grep -qE 'Added .*credential|Saved .*credentials|Login successful' || { echo "o login não terminou; rode esperar" >&2; exit 1; }
        docker exec "$C" hermes config set model.provider openai-codex >/dev/null
        docker exec "$C" hermes config set model.default "$MODELO" >/dev/null
        hermes_restart || { echo "o Hermes não voltou depois do restart" >&2; exit 1; }
        rm -f "$LOG"
        echo "provider=$(docker exec "$C" hermes config get model.provider 2>/dev/null | tail -1)"
        echo "modelo=$(docker exec "$C" hermes config get model.default 2>/dev/null | tail -1)"
        docker exec "$C" hermes auth status openai-codex ;;
    status) docker exec "$C" hermes auth status openai-codex ;;
    *) echo "uso: codex-login.sh iniciar|codigo|esperar [seg]|concluir|status"; exit 2 ;;
esac
