#!/usr/bin/env bash
# Fase 6: personalização. O usuário responde 5 perguntas no chat (nada é segredo), o agente grava
# em config/alma.env, e o harness preenche o SOUL.md e o USER.md a partir dos templates de alma/.
#   criar     -> cria config/alma.env com os campos vazios
#   validar   -> confere que os 5 campos estão preenchidos
#   mostrar   -> imprime o SOUL.md já preenchido (para o usuário aprovar antes de gravar)
#   aplicar   -> grava SOUL.md e USER.md no Hermes da VPS e reinicia
source "$(dirname "$0")/lib.sh"
command -v perl >/dev/null 2>&1 || morrer "preciso de perl"

campos=(DONO AGENTE FAZ TOM TAREFAS)
ler_alma() {
    [ -f "$ALMA_ARQ" ] || morrer "falta $ALMA_ARQ. Rode: bash harness/50-alma.sh criar"
    for c in "${campos[@]}"; do
        v="$(campo_de "$ALMA_ARQ" "$c")"
        [ -n "$v" ] || morrer "campo vazio em $ALMA_ARQ: $c"
        printf -v "A_$c" '%s' "$v"
    done
    case "$A_TOM" in
        informal) A_TOM="num tom informal e leve" ;;
        formal)   A_TOM="num tom formal e sóbrio" ;;
        *) morrer "TOM tem que ser informal ou formal (está: $A_TOM)" ;;
    esac
    # TAREFAS: separadas por ponto e vírgula, viram lista
    A_TAREFAS="$(printf '%s' "$A_TAREFAS" | tr ';' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sed 's/^/- /')"
    [ "${#A_DONO}" -le 60 ] || morrer "DONO longo demais"
    [ "${#A_AGENTE}" -le 40 ] || morrer "AGENTE longo demais"
    [ "${#A_FAZ}" -le 300 ] || morrer "FAZ longo demais (máximo 300 caracteres)"
    export A_DONO A_AGENTE A_FAZ A_TOM A_TAREFAS
}
render() { # render TEMPLATE
    perl -0pe 'for my $k (qw(DONO AGENTE FAZ TOM TAREFAS)) { my $v = $ENV{"A_$k"} // ""; s/\{\{$k\}\}/$v/g; }' "$1"
}

case "${1:-}" in
    criar)
        if [ -f "$ALMA_ARQ" ]; then ok "já existe $ALMA_ARQ"; exit 0; fi
        cat > "$ALMA_ARQ" <<'ARQ'
# Respostas do usuário (nada aqui é segredo). O agente preenche a partir da conversa.
# Nome do usuário, como ele quer ser chamado
DONO=
# Nome que o usuário escolheu para o agente (ex.: Hermes, Zé, Sofia)
AGENTE=
# O que o usuário faz, numa frase começando com verbo (ex.: "cuida de uma clínica de fisioterapia em Manaus")
FAZ=
# informal ou formal
TOM=
# Três tarefas que ele quer tirar da mão na primeira semana, separadas por ponto e vírgula
TAREFAS=
ARQ
        ok "criei $ALMA_ARQ. Faça as 5 perguntas ao usuário e preencha os campos (pode editar o arquivo você mesmo)." ;;
    validar) ler_alma; ok "alma completa: $A_DONO / $A_AGENTE / tom ${A_TOM}" ;;
    mostrar) ler_alma; render "$RAIZ/alma/SOUL.md.template" ;;
    aplicar)
        ler_alma; carregar_config
        soul="$(render "$RAIZ/alma/SOUL.md.template")"; user="$(render "$RAIZ/alma/USER.md.template")"
        printf '%s\n' "$soul" | grep -q '{{' && morrer "sobrou placeholder no SOUL.md"
        printf '%s\n' "$user" | grep -q '{{' && morrer "sobrou placeholder no USER.md"
        printf '%s\n' "$soul" | vps "bash $REMOTO_DIR/bin/soul-set.sh SOUL.md"
        printf '%s\n' "$user" | vps "bash $REMOTO_DIR/bin/soul-set.sh USER.md"
        log "reiniciando o Hermes para ler a nova identidade"; reiniciar_hermes
        gravar_estado ALMA_EM "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        ok "ALMA OK: o agente se chama $A_AGENTE e sabe quem é $A_DONO. Próximo: bash harness/60-hubs.sh criar" ;;
    *) echo "uso: bash harness/50-alma.sh criar|validar|mostrar|aplicar"; exit 2 ;;
esac
