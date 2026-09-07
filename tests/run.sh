#!/usr/bin/env bash
# Testes locais do harness: sintaxe, shellcheck (se houver docker), compose, Caddyfile, página.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=tests/.tmp; mkdir -p "$TMP/config"
# NUNCA tocar em config/ do usuário: todo teste usa um config isolado
export HERMES_VPS_CONFIG_DIR="$PWD/$TMP/config"; CFG="$HERMES_VPS_CONFIG_DIR"
falhas=0
passo() { printf '\n== %s\n' "$*"; }

passo "sintaxe bash"
for f in harness/*.sh harness/remoto/*.sh harness/remoto/bin/*.sh tests/run.sh; do bash -n "$f" && echo "ok $f"; done

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    passo "shellcheck"
    docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -x -S warning \
        harness/*.sh harness/remoto/*.sh harness/remoto/bin/*.sh && echo "ok shellcheck" || falhas=$((falhas+1))
    passo "caddy validate"
    docker run --rm -e HOSTNAME_TLS=exemplo.hstgr.cloud -v "$PWD/harness/remoto/Caddyfile:/etc/caddy/Caddyfile:ro" \
        caddy:2 caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -q "Valid configuration" && echo "ok caddy" || falhas=$((falhas+1))
    passo "compose config"
    cat > "$TMP/.env" <<ENV
HERMES_IMAGEM=nousresearch/hermes-agent:latest
MODO=publico
HOSTNAME_TLS=exemplo.hstgr.cloud
PAINEL_USUARIO=admin
PAINEL_SENHA=senha-de-teste-local-123
PAINEL_SEGREDO=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
COMPOSE_PROFILES=publico
ENV
    docker compose -p hermes-teste -f harness/remoto/compose.yml --env-file "$TMP/.env" config >/dev/null && echo "ok compose" || falhas=$((falhas+1))
else
    echo "(sem docker: pulando shellcheck, caddy e compose)"
fi

passo "página do desktop (modo publico e tunel)"
for modo in publico tunel; do
    mkdir -p "$TMP/cfg-$modo"
    cat > $CFG/hermes-vps.env <<CFG
VPS_HOST=203.0.113.10
SSH_USER=root
SSH_PORT=22
SSH_KEY=~/.ssh/hermes-vps
MODO=$modo
DOMINIO=
PAINEL_USUARIO=admin
CFG
    if [ "$modo" = publico ]; then url="https://srv000000.hstgr.cloud"; else url="http://localhost:9119"; fi
    printf 'IP_PUBLICO=203.0.113.10\nHOSTNAME_TLS=srv000000.hstgr.cloud\nURL=%s\nVERSAO=0.21.0\n' "$url" > $CFG/.estado
    HERMES_VPS_SEM_ABRIR=1 bash harness/30-desktop.sh "$TMP/desktop-$modo" >/dev/null
    html="$TMP/desktop-$modo/Meu Hermes.html"
    grep -q '{{' "$html" && { echo "FALHA: placeholder sobrou ($modo)"; falhas=$((falhas+1)); }
    grep -q "$url" "$html" && echo "ok página $modo ($url)"
    if [ "$modo" = tunel ]; then ls "$TMP/desktop-$modo/" | grep -q "túnel" && echo "ok atalho do túnel"; fi
    if [ "$modo" = publico ]; then grep -q "Modo túnel" "$html" && { echo "FALHA: bloco de túnel na página pública"; falhas=$((falhas+1)); }; fi
done
rm -f $CFG/hermes-vps.env $CFG/.estado

passo "configurar: parse do acesso SSH"
for ent in "ssh root@203.0.113.10" "root@203.0.113.10" "203.0.113.10" "ssh -p 2222 root@203.0.113.10" "ssh root@203.0.113.10 -p 2222" "root@srv1.hstgr.cloud:2222"; do
    HERMES_VPS_SEM_ABRIR=1 bash harness/configurar.sh "$ent" >/dev/null 2>&1 || { echo "FALHA: configurar não aceitou: $ent"; falhas=$((falhas+1)); continue; }
    h="$(sed -n 's/^VPS_HOST=//p' $CFG/hermes-vps.env)"; p="$(sed -n 's/^SSH_PORT=//p' $CFG/hermes-vps.env)"
    case "$ent" in *2222*) esp=2222 ;; *) esp=22 ;; esac
    if [ "$p" = "$esp" ] && [ -n "$h" ]; then echo "ok configurar: '$ent' → $h:$p"; else echo "FALHA: '$ent' → $h:$p"; falhas=$((falhas+1)); fi
done
[ -f $CFG/acesso.local ] && [ "$(stat -f %Lp $CFG/acesso.local 2>/dev/null || stat -c %a $CFG/acesso.local)" = 600 ] && echo "ok acesso.local criado com 600"
grep -q '^VPS_ROOT_SENHA=$' $CFG/acesso.local && grep -q '^PAINEL_SENHA=$' $CFG/acesso.local && echo "ok acesso.local com os dois campos vazios"
rm -f $CFG/hermes-vps.env $CFG/hermes-vps.env.bak $CFG/acesso.local

passo "senha: validação sem eco"
printf 'VPS_ROOT_SENHA=raiz-de-teste\nPAINEL_SENHA=curta\n' > $CFG/acesso.local
if bash harness/05-senha.sh validar >/dev/null 2>&1; then echo "FALHA: aceitou senha curta"; falhas=$((falhas+1)); else echo "ok recusa curta"; fi
printf 'VPS_ROOT_SENHA=raiz-de-teste\nPAINEL_SENHA=tem espaco dentro 123\n' > $CFG/acesso.local
if bash harness/05-senha.sh validar >/dev/null 2>&1; then echo "FALHA: aceitou espaço"; falhas=$((falhas+1)); else echo "ok recusa espaço"; fi
printf 'VPS_ROOT_SENHA=raiz-de-teste\nPAINEL_SENHA=Senha.valida-2026!\n' > $CFG/acesso.local
saida="$(bash harness/05-senha.sh validar 2>&1)"
echo "$saida" | grep -qE "Senha.valida|raiz-de-teste" && { echo "FALHA: ecoou senha"; falhas=$((falhas+1)); }
echo "$saida" | grep -q "senha válida" && echo "ok aceita válida sem ecoar"
bash harness/05-senha.sh limpar >/dev/null
grep -q '^PAINEL_SENHA=$' $CFG/acesso.local && grep -q '^VPS_ROOT_SENHA=raiz-de-teste$' $CFG/acesso.local && echo "ok limpar apaga só a senha do painel"
rm -f $CFG/acesso.local

passo "codex-login: parse do código no log (sem VPS)"
printf 'Signing in to OpenAI Codex...\n\n  1. Open this URL in your browser:\n     \033[94mhttps://auth.openai.com/codex/device\033[0m\n\n  2. Enter this code:\n     \033[94mABCD-EFGHJ\033[0m\n\nWaiting for sign-in... (press Ctrl+C to cancel)\n' > "$TMP/codex.log"
saida="$(CODEX_LOG="$TMP/codex.log" bash harness/remoto/bin/codex-login.sh codigo)"
echo "$saida" | grep -q '^URL=https://auth.openai.com/codex/device$' && echo "$saida" | grep -q '^CODIGO=ABCD-EFGHJ$' && echo "ok codigo lido sem ANSI" || { echo "FALHA: parse do código: $saida"; falhas=$((falhas+1)); }
rc=0; CODEX_LOG="$TMP/codex.log" bash harness/remoto/bin/codex-login.sh esperar 5 >/dev/null || rc=$?; [ "$rc" -eq 3 ] && echo "ok esperar devolve 3 enquanto espera" || { echo "FALHA: esperar"; falhas=$((falhas+1)); }
printf 'Saved openai-codex OAuth device-code credentials: "conta"\n' >> "$TMP/codex.log"
CODEX_LOG="$TMP/codex.log" bash harness/remoto/bin/codex-login.sh esperar 5 >/dev/null && echo "ok esperar devolve 0 ao entrar" || { echo "FALHA: esperar 0"; falhas=$((falhas+1)); }

passo "env-add: upsert no .env sem imprimir valor (python local)"
sed -n "/<<'PY'/,/^PY$/p" harness/remoto/bin/env-add.sh | sed '1d;$d' > "$TMP/env-add.py"
printf 'OUTRA=1\nMATON_API_KEY=velha\n' > "$TMP/env-teste"
saida="$(printf 'MATON_API_KEY=nova-chave-de-teste-1234567890\nZERNIO_API_KEY=sk_zernio_teste_0123456789\n' | HERMES_ENV_PATH="$TMP/env-teste" python3 "$TMP/env-add.py")"
echo "$saida" | grep -qE 'nova-chave|sk_zernio' && { echo "FALHA: env-add ecoou valor"; falhas=$((falhas+1)); }
grep -q '^OUTRA=1$' "$TMP/env-teste" && [ "$(grep -c '^MATON_API_KEY=' "$TMP/env-teste")" = 1 ] && grep -q '^MATON_API_KEY=nova-chave-de-teste-1234567890$' "$TMP/env-teste" && grep -q '^ZERNIO_API_KEY=' "$TMP/env-teste" && echo "ok upsert preserva o resto e substitui a chave" || { echo "FALHA: upsert"; falhas=$((falhas+1)); }
printf 'PATH=/x\n' | HERMES_ENV_PATH="$TMP/env-teste" python3 "$TMP/env-add.py" >/dev/null 2>&1 && { echo "FALHA: aceitou PATH"; falhas=$((falhas+1)); } || echo "ok recusa nome proibido"

passo "alma: template sem placeholder"
printf 'DONO=Maria\nAGENTE=Sofia\nFAZ=cuida de uma clínica em Manaus\nTOM=informal\nTAREFAS=responder e-mail; agendar consulta; resumir reunião\n' > $CFG/alma.env
saida="$(bash harness/50-alma.sh mostrar)"
echo "$saida" | grep -q '{{' && { echo "FALHA: sobrou placeholder"; falhas=$((falhas+1)); }
echo "$saida" | grep -q '^- agendar consulta$' && echo "$saida" | grep -q 'Você é Sofia, o agente pessoal de Maria' && echo "ok SOUL.md preenchido" || { echo "FALHA: SOUL.md"; falhas=$((falhas+1)); }
printf 'DONO=Maria\nAGENTE=Sofia\nFAZ=x\nTOM=gritando\nTAREFAS=a\n' > $CFG/alma.env
bash harness/50-alma.sh validar >/dev/null 2>&1 && { echo "FALHA: aceitou TOM inválido"; falhas=$((falhas+1)); } || echo "ok recusa TOM inválido"
rm -f $CFG/alma.env

passo "hubs: validação das chaves sem eco"
printf 'MATON_API_KEY=curta\nZERNIO_API_KEY=\n' > $CFG/chaves.local
bash harness/60-hubs.sh validar >/dev/null 2>&1 && { echo "FALHA: aceitou chave curta"; falhas=$((falhas+1)); } || echo "ok recusa curta"
printf 'MATON_API_KEY=\nZERNIO_API_KEY=\n' > $CFG/chaves.local
rc=0; bash harness/60-hubs.sh validar >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 3 ] && echo "ok duas vazias devolve 3" || { echo "FALHA: vazias"; falhas=$((falhas+1)); }
printf 'MATON_API_KEY=maton_chave_de_teste_0123456789\nZERNIO_API_KEY=sk_zernio_chave_teste_0123456789\n' > $CFG/chaves.local
saida="$(bash harness/60-hubs.sh validar 2>&1)"
echo "$saida" | grep -qE 'maton_chave|sk_zernio' && { echo "FALHA: ecoou chave"; falhas=$((falhas+1)); }
echo "$saida" | grep -q 'chaves prontas' && echo "ok aceita válidas sem ecoar" || { echo "FALHA: válidas"; falhas=$((falhas+1)); }
rm -f $CFG/chaves.local

passo "modelo: iniciar exige --confirmado"
bash harness/40-modelo.sh iniciar >/dev/null 2>&1 && { echo "FALHA: iniciou sem confirmação"; falhas=$((falhas+1)); } || echo "ok gate do ChatGPT"

echo
if [ "$falhas" -eq 0 ]; then echo "TODOS OS TESTES PASSARAM"; else echo "$falhas FALHA(S)"; exit 1; fi
