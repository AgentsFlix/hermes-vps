#!/usr/bin/env bash
# Remove uma chave pública autorizada da VPS, pela impressão digital. Roda na VPS.
# Uso: chave-remover.sh SHA256:xxxxx      (a impressão digital vem de ssh-keygen -lf chave.pub)
set -euo pipefail
fp="${1:-}"
[ -n "$fp" ] || { echo "uso: chave-remover.sh SHA256:..." >&2; exit 2; }
ARQ=~/.ssh/authorized_keys
[ -f "$ARQ" ] || { echo "não existe $ARQ" >&2; exit 1; }
cp "$ARQ" "$ARQ.antes-do-harness"
: > "$ARQ.novo"
removidas=0
while IFS= read -r linha; do
    [ -n "$linha" ] || continue
    atual="$(printf '%s\n' "$linha" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')"
    if [ "$atual" = "$fp" ]; then removidas=$((removidas+1)); else printf '%s\n' "$linha" >> "$ARQ.novo"; fi
done < "$ARQ"
[ "$removidas" -gt 0 ] || { rm -f "$ARQ.novo"; echo "nenhuma chave com essa impressão digital"; exit 1; }
restam="$(grep -c . "$ARQ.novo" || true)"
mv "$ARQ.novo" "$ARQ"; chmod 600 "$ARQ"
echo "removidas: $removidas · autorizadas agora: $restam · backup: $ARQ.antes-do-harness"
[ "$restam" = 0 ] && echo "AVISO: nenhuma chave autorizada. O acesso agora é só pela senha root do hPanel."
