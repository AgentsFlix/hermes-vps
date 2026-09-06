# Harness hermes-vps · instruções para o agente

Você é o agente (Claude Code, Codex ou outro) que vai instalar o **Hermes Agent** numa VPS do
usuário e deixar um acesso pronto no Desktop dele. O usuário é leigo. Fale em português simples,
uma coisa por vez. Você executa; ele só fornece o IP da VPS, a senha root uma única vez (no
terminal dele, não para você) e escolhe uma senha para o painel (num arquivo, não no chat).

Tudo o que a instalação precisa está neste repositório. **Use só os scripts de `harness/`.**

## O que o usuário precisa ter antes

- Uma VPS **Ubuntu 24.04** (ou 22.04, ou Debian 12), com pelo menos **2 GB de RAM** e 20 GB de
  disco. Na Hostinger: plano KVM 2 ou maior, template "Ubuntu 24.04" ou "Ubuntu 24.04 with Docker".
  Não use template com painel (EasyPanel, CloudPanel): eles ocupam as portas 80 e 443.
- O **IP** da VPS e a **senha root** (Hostinger: hPanel → VPS → Visão geral).
- Uma **chave de provedor de IA** (OpenRouter, Anthropic, OpenAI…). Ele cola no painel do Hermes
  depois de instalado. **Você nunca pede essa chave.**
- Na máquina dele: `ssh`, `scp`, `curl`, `perl` (macOS e Linux já têm; no Windows, use Git Bash
  ou WSL).

## Regras que não se negociam

1. **Senha nunca no chat.** A senha do painel entra por `config/senha.local`, que o script cria e
   abre no editor. Você valida com `bash harness/05-senha.sh validar`, que não mostra o valor.
   Nunca faça `cat` desse arquivo. Nunca faça `cat /opt/hermes/.env` na VPS.
2. **A senha root da VPS é digitada pelo usuário no terminal dele**, no `ssh-copy-id`. Se ele
   colar a senha no chat, diga que não vai usar e peça para trocar a senha depois.
3. **Nenhum comando na VPS fora dos scripts.** Diagnóstico é `bash harness/status.sh` e
   `bash harness/logs.sh`. Se isso não bastar, pare e explique ao usuário o que viu.
4. **Cada fase termina em `exit 0`. Falhou, não avance.** Leia a mensagem, corrija a causa, rode
   a fase de novo. Os scripts são idempotentes.
5. **Não "melhore" o desenho.** Não troque a imagem `:latest` por outra, não abra a porta 9119,
   não desligue o login do painel, não mexa no Caddyfile. As razões estão em `docs/decisoes.md`.
6. Na máquina do usuário você só cria: a chave SSH em `~/.ssh/hermes-vps`, o arquivo de config
   em `config/` e a pasta `Meu Hermes` no Desktop.

## Procedimento

### Fase 0 · preflight

```bash
bash harness/00-preflight.sh
```

| saída | o que fazer |
|---|---|
| `exit 2` "criei config/hermes-vps.env" | pergunte o IP da VPS ao usuário, escreva em `VPS_HOST=` (pode editar o arquivo você mesmo: IP não é segredo) e rode de novo |
| `exit 3` "chave ainda não está autorizada" | mostre ao usuário o comando `ssh-copy-id` impresso, peça que ele rode **no terminal dele** e digite a senha root lá. Depois rode de novo |
| erro "já tem algo escutando na porta 80 ou 443" | a VPS não está limpa. Ou o usuário recria a VPS com template sem painel, ou define `MODO=tunel` no config |
| erro de RAM ou disco | avise o usuário e pergunte se quer seguir; abaixo de 2 GB, recomende trocar o plano |
| `PREFLIGHT OK` | siga |

O preflight grava `config/.estado` com o IP público, o hostname HTTPS decidido e a URL final.

### Fase 1 · senha do painel

```bash
bash harness/05-senha.sh criar      # cria o arquivo e abre no editor
# o usuário digita a senha depois de PAINEL_SENHA= e salva
bash harness/05-senha.sh validar    # 12 a 64 caracteres; não mostra o valor
```

Se `validar` falhar, diga o motivo (curta, caractere não permitido) e peça para editar de novo.

### Fase 2 · instalar

```bash
bash harness/10-instalar.sh
```

Envia `harness/remoto/` para `/opt/hermes/harness` na VPS e roda `instalar-vps.sh` lá, como
root: pacotes, Docker, firewall `ufw` (22, e 80/443 no modo público), `compose.yml`, `.env` com
permissão 600, `docker compose up`. A senha vai pelo stdin do SSH. Leva de 2 a 6 minutos; a
imagem tem alguns GB. No fim, o script apaga `config/senha.local`.

### Fase 3 · verificar

```bash
bash harness/20-verificar.sh
```

Critérios binários: SSH entra; container `hermes` running; `/api/status` no loopback da VPS diz
`auth_required: true` e provedor `basic`; no modo público, HTTPS válido na URL e porta 9119
fechada de fora; no modo túnel, o túnel alcança o painel. **Só siga com todos passando.**
Um certificado recém-emitido pode falhar no primeiro minuto: espere 60 s e rode de novo antes
de investigar.

### Fase 4 · desktop

```bash
bash harness/30-desktop.sh
```

Gera `~/Desktop/Meu Hermes/Meu Hermes.html` (página local: botão do painel, primeiros passos,
comandos) e, no modo túnel, o atalho que abre a ponte SSH. Abre a página. Nada de senha dentro.

### Fase 5 · entrega

Diga ao usuário, nesta ordem:

1. A URL do painel e o usuário (`PAINEL_USUARIO`, padrão `admin`). A senha é a que ele digitou.
2. Primeiro passo dentro do painel: **API Keys → colar a chave do provedor de IA**. Sem isso o
   Hermes não responde.
3. Depois: **Chat**. É o Hermes completo.
4. Canais de mensagem (Telegram, WhatsApp, Discord) se configuram no painel, em API Keys. O
   gateway já sobe com o container; sem canal configurado ele só atende o painel.
5. A página `Meu Hermes` no Desktop tem tudo isso e os comandos de operação.

## Operação depois de instalado

| pedido do usuário | comando |
|---|---|
| "está no ar?" | `bash harness/status.sh` |
| "deu erro / travou" | `bash harness/logs.sh` (aceita número de linhas: `bash harness/logs.sh 400`) |
| "atualiza o Hermes" | `bash harness/atualizar.sh` (faz backup antes, puxa `:latest`, sobe de novo) |
| "faz backup" | `bash harness/backup.sh` (guarda os 5 últimos em `/opt/hermes/backups`) |
| "trocar a senha" | `bash harness/senha.sh criar` → usuário digita → `bash harness/senha.sh aplicar` |
| "refaz a página do Desktop" | `bash harness/30-desktop.sh` |

## Quando algo falha

| sintoma | causa provável | ação |
|---|---|---|
| `ssh` não entra mesmo depois do `ssh-copy-id` | firewall da Hostinger sem a porta 22, ou senha root errada | hPanel → VPS → Regras de firewall; ou redefinir a senha root no hPanel |
| verificar falha em "HTTPS válido" | certificado ainda sendo emitido; ou hPanel com firewall bloqueando 80/443 | esperar 60 s; conferir regras do firewall na Hostinger (80 e 443 TCP, e 443 UDP se quiser HTTP/3) |
| verificar falha em "auth_required" | variáveis do painel não chegaram ao container | `bash harness/logs.sh`; procurar "dashboard" e "auth" |
| painel abre mas o chat não responde | falta a chave do provedor | API Keys no painel |
| "porta 80 ou 443 em uso" no preflight | template com painel ou outro serviço | VPS limpa ou `MODO=tunel` |
| `docker compose pull` lento ou falha | rede da VPS | rodar `bash harness/10-instalar.sh` de novo; é idempotente |

## Fatos sobre o desenho, para você não corrigir o que não está errado

- A imagem é `nousresearch/hermes-agent:latest`, oficial, com o painel embutido. O gateway e o
  painel são supervisionados pelo s6 dentro do mesmo container.
- O painel escuta em `0.0.0.0:9119` **dentro** do container, e a porta só é publicada em
  `127.0.0.1` da VPS. Quem entrega para fora é o Caddy (TLS automático) no modo público, ou o
  túnel SSH no modo túnel. Bind em `0.0.0.0` é o que liga o gate de autenticação do Hermes; com
  bind em loopback o painel sobe **sem senha**.
- O hostname HTTPS de uma VPS Hostinger é o próprio `srvNNNNNN.hstgr.cloud`: já resolve para o
  IP e `hstgr.cloud` está na Public Suffix List, então o Let's Encrypt trata cada VPS como um
  domínio separado. Sem isso, o harness cai para `sslip.io`, que divide a cota com o mundo.
- O gateway sobe junto com o container (medido na 0.21.0 em 06/09/2026: `gateway_running: true`,
  único canal `api_server`). O comentário do `stage2-hook.sh` sobre gateway começar parado descreve
  versões anteriores; a medição vale mais que o comentário.
- Dados (config, chaves, sessões, memórias, skills) vivem no volume `hermes_hermes-data`,
  montado em `/opt/data`. Reinstalar não apaga. `atualizar.sh` faz backup antes.
- A instalação de referência (um cliente real, no EasyPanel) usa exatamente estas variáveis:
  `HERMES_DASHBOARD`, `HERMES_DASHBOARD_HOST`, `HERMES_DASHBOARD_PORT`,
  `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`, `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD`. O harness soma
  `HERMES_DASHBOARD_BASIC_AUTH_SECRET` para a sessão sobreviver a reinício. Detalhes em
  `docs/referencia-easypanel.md`.
