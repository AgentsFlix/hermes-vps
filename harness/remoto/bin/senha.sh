#!/usr/bin/env bash
# Troca a senha do painel. A nova senha chega pelo stdin (linha PAINEL_SENHA=...). Roda na VPS.
set -euo pipefail
cd /opt/hermes
[ -t 0 ] && { echo "a senha vem pelo stdin"; exit 2; }
nova="$(sed -n 's/^PAINEL_SENHA=//p' | head -1 | tr -d '\r')"
[ "${#nova}" -ge 12 ] || { echo "senha curta"; exit 1; }
tmp="$(mktemp)"; grep -v '^PAINEL_SENHA=' .env > "$tmp"; printf 'PAINEL_SENHA=%s\n' "$nova" >> "$tmp"
chmod 600 "$tmp"; mv "$tmp" .env; unset nova
docker compose up -d hermes >/dev/null
echo "senha trocada; o container do painel foi recriado"
