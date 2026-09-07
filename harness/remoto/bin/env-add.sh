#!/usr/bin/env bash
# Grava (ou substitui) variáveis no .env do Hermes, dentro do volume, como o usuário hermes.
# Roda NA VPS. As linhas KEY=valor chegam pelo stdin; nada é impresso além do nome e do tamanho.
set -euo pipefail
source "$(dirname "$0")/_alvo.sh"
C="$(hermes_container)"
[ -t 0 ] && { echo "as chaves têm que vir pelo stdin (o harness faz isso)" >&2; exit 2; }
docker inspect -f '{{.State.Status}}' "$C" 2>/dev/null | grep -qx running || { echo "container do Hermes não está running" >&2; exit 1; }
docker exec -i --user hermes -e HERMES_ENV_PATH=/opt/data/.env "$C" python3 - <<'PY'
import os, re, sys
env = os.environ.get("HERMES_ENV_PATH", "/opt/data/.env")
atual = {}
linhas = []
if os.path.exists(env):
    with open(env, encoding="utf-8") as f:
        linhas = f.read().splitlines()
novas = {}
for l in sys.stdin.read().splitlines():
    l = l.strip()
    if not l or l.startswith("#") or "=" not in l:
        continue
    k, v = l.split("=", 1)
    k, v = k.strip(), v.strip().strip('"').strip("'")
    if not re.fullmatch(r"[A-Z][A-Z0-9_]{2,63}", k):
        print(f"nome inválido: {k}", file=sys.stderr); sys.exit(1)
    if k in ("PATH", "PYTHONPATH", "LD_PRELOAD", "LD_LIBRARY_PATH", "HERMES_HOME"):
        print(f"nome proibido: {k}", file=sys.stderr); sys.exit(1)
    if v:
        novas[k] = v
saida = []
for l in linhas:
    m = re.match(r"^([A-Z][A-Z0-9_]*)=", l)
    if m and m.group(1) in novas:
        continue
    saida.append(l)
for k, v in novas.items():
    saida.append(f"{k}={v}")
fd = os.open(env, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as f:
    f.write("\n".join(saida).rstrip("\n") + "\n")
os.chmod(env, 0o600)
for k, v in novas.items():
    print(f"{k}: gravada ({len(v)} caracteres)")
PY
