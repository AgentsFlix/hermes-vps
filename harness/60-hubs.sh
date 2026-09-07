#!/usr/bin/env bash
# Fase 7: os dois hubs de ferramentas. As chaves entram por arquivo (config/chaves.local), nunca
# pelo chat; vão pelo stdin do SSH para o .env do Hermes; e cada hub vira uma skill instalada.
#   criar    -> cria o arquivo com os campos vazios e abre no editor
#   validar  -> confere presença e tamanho, sem mostrar o valor
#   aplicar  -> grava as chaves no .env da VPS, reinicia o Hermes, instala as skills, apaga os valores locais
#   provar   -> lista o que ficou instalado e quais chaves existem (nome e tamanho, nunca o valor)
source "$(dirname "$0")/lib.sh"

# Fixados em tag: aula reproduzível. Para atualizar, troque a tag aqui e rode aplicar de novo.
MATON_SKILL_URL="${MATON_SKILL_URL:-https://raw.githubusercontent.com/AgentsFlix/hermes-maton/v0.2.0/skills/integrations/maton-operations/SKILL.md}"
ZERNIO_SKILL_URL="${ZERNIO_SKILL_URL:-https://raw.githubusercontent.com/AgentsFlix/hermes-zernio/v1.0.0/skills/integrations/zernio-operations/SKILL.md}"

valida_chave() { # valida_chave NOME  -> 0 presente e válida, 2 ausente, 1 inválida
    local v; v="$(campo_de "$CHAVES_ARQ" "$1")"
    [ -n "$v" ] || return 2
    local n=${#v}
    [ "$n" -ge 20 ] || { falha "$1 curta demais ($n caracteres): colou inteira?"; return 1; }
    [[ "$v" =~ ^[A-Za-z0-9._:-]+$ ]] || { falha "$1 tem espaço ou caractere estranho: cole só a chave, sem aspas"; return 1; }
    ok "$1 presente ($n caracteres). O valor não é mostrado."
}

case "${1:-}" in
    criar)
        if [ ! -f "$CHAVES_ARQ" ]; then
            umask 077
            cat > "$CHAVES_ARQ" <<'ARQ'
# Cole cada chave depois do sinal de igual, sem aspas, e salve. Este arquivo fica fora do git
# e os valores são apagados daqui depois de gravados na VPS.
#
# Maton (maton.ai > Settings > API Keys). Deixe vazio se não for usar o Maton agora.
MATON_API_KEY=
#
# Zernio (zernio.com > Settings > API). Deixe vazio se não for usar o Zernio agora.
ZERNIO_API_KEY=
ARQ
        fi
        abrir_editor "$CHAVES_ARQ"
        ok "abri $CHAVES_ARQ. Diga ao usuário: \"Cole a chave do Maton e a do Zernio, salve, e me responda: Feito.\"" ;;
    validar)
        [ -f "$CHAVES_ARQ" ] || morrer "não existe $CHAVES_ARQ. Rode: bash harness/60-hubs.sh criar"
        rc=0; tem=0
        for k in MATON_API_KEY ZERNIO_API_KEY; do
            r=0; valida_chave "$k" || r=$?
            case $r in 0) tem=$((tem+1)) ;; 2) aviso "$k vazia: esse hub fica de fora por enquanto" ;; *) rc=1 ;; esac
        done
        [ $rc -eq 0 ] || exit 1
        [ $tem -gt 0 ] || { aviso "nenhuma chave preenchida. Se for isso mesmo, pule para: bash harness/60-hubs.sh provar"; exit 3; }
        ok "chaves prontas para gravar" ;;
    aplicar)
        carregar_config
        bash "$0" validar >/dev/null || morrer "corrija as chaves antes: bash harness/60-hubs.sh criar"
        log "gravando as chaves no .env do Hermes (só as linhas preenchidas vão pelo stdin do SSH)"
        grep -E '^(MATON_API_KEY|ZERNIO_API_KEY)=.+' "$CHAVES_ARQ" | vps "bash $REMOTO_DIR/bin/env-add.sh" || morrer "não consegui gravar as chaves"
        # prova ANTES de apagar o que o usuário colou: gravação que falha em silêncio já custou uma colagem
        prova="$(vps "bash $REMOTO_DIR/bin/provar-env.sh MATON_API_KEY ZERNIO_API_KEY")"
        printf '%s\n' "$prova"
        for k in MATON_API_KEY ZERNIO_API_KEY; do
            [ -n "$(campo_de "$CHAVES_ARQ" "$k")" ] || continue
            printf '%s\n' "$prova" | grep -q "$k: [1-9]" || morrer "$k não chegou ao .env do Hermes. As chaves continuam em $CHAVES_ARQ; não apaguei nada."
        done
        ok "as duas pontas conferem: o que foi colado está no .env do Hermes"
        log "reiniciando o Hermes para carregar o .env"; reiniciar_hermes
        for par in "MATON_API_KEY|$MATON_SKILL_URL|maton-operations" "ZERNIO_API_KEY|$ZERNIO_SKILL_URL|zernio-operations"; do
            IFS='|' read -r k url nome <<< "$par"
            [ -n "$(campo_de "$CHAVES_ARQ" "$k")" ] || continue
            log "instalando a skill $nome (o scanner do Hermes roda antes; sem --force)"
            hermes_na_vps "skills install '$url' --yes" | grep -E 'Decision|Installed|BLOCKED' || true
            hermes_na_vps "skills list" | grep -q "$nome" || morrer "a skill $nome não aparece em 'hermes skills list'. Leia a decisão do scanner acima."
            ok "skill $nome instalada"
        done
        # apaga os valores locais: a partir daqui as chaves vivem só no .env da VPS
        tmp="$(mktemp)"; sed -E 's/^(MATON_API_KEY|ZERNIO_API_KEY)=.*/\1=/' "$CHAVES_ARQ" > "$tmp" && cat "$tmp" > "$CHAVES_ARQ"; rm -f "$tmp"
        ok "valores apagados de $CHAVES_ARQ"
        gravar_estado HUBS_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        ok "HUBS OK. Próximo: bash harness/60-hubs.sh provar" ;;
    provar)
        carregar_config
        echo "skills instaladas:"; hermes_na_vps "skills list" | grep -E 'maton|zernio' || echo "  (nenhuma das duas)"
        echo "chaves no .env do Hermes (nome e tamanho):"
        vps "bash $REMOTO_DIR/bin/provar-env.sh MATON_API_KEY ZERNIO_API_KEY"
        echo; echo "Teste real, pelo painel: peça ao agente \"faça o inventário de leitura do Maton\" e \"liste minhas contas no Zernio\"." ;;
    *) echo "uso: bash harness/60-hubs.sh criar|validar|aplicar|provar"; exit 2 ;;
esac
