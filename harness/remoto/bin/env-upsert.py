"""Upsert de variáveis no .env do Hermes. Lê linhas KEY=valor do stdin, nunca imprime valor.

Fica em arquivo próprio de propósito: quando o código ia por heredoc para `python3 -`, ele
ocupava o stdin e as linhas de dados chegavam vazias — o script gravava nada e saía com 0.
"""
import os
import re
import sys

PROIBIDOS = {"PATH", "PYTHONPATH", "LD_PRELOAD", "LD_LIBRARY_PATH", "HERMES_HOME"}
env = os.environ.get("HERMES_ENV_PATH", "/opt/data/.env")

linhas = []
if os.path.exists(env):
    with open(env, encoding="utf-8") as f:
        linhas = f.read().splitlines()

novas = {}
for linha in sys.stdin.read().splitlines():
    linha = linha.strip()
    if not linha or linha.startswith("#") or "=" not in linha:
        continue
    k, v = linha.split("=", 1)
    k, v = k.strip(), v.strip().strip('"').strip("'")
    if not re.fullmatch(r"[A-Z][A-Z0-9_]{2,63}", k):
        print("nome inválido: %s" % k, file=sys.stderr)
        sys.exit(1)
    if k in PROIBIDOS:
        print("nome proibido: %s" % k, file=sys.stderr)
        sys.exit(1)
    if v:
        novas[k] = v

if not novas:
    print("nenhuma variável no stdin: nada a gravar", file=sys.stderr)
    sys.exit(2)

saida = []
for l in linhas:
    m = re.match(r"^([A-Z][A-Z0-9_]*)=", l)
    if m and m.group(1) in novas:
        continue          # a linha antiga sai; a nova entra no fim
    saida.append(l)
for k, v in novas.items():
    saida.append("%s=%s" % (k, v))

fd = os.open(env, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as f:
    f.write("\n".join(saida).rstrip("\n") + "\n")
os.chmod(env, 0o600)

for k, v in novas.items():
    print("%s: gravada (%d caracteres)" % (k, len(v)))
