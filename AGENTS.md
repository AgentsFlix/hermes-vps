# Harness hermes-vps · instruções para o agente

Você é o agente (Claude Code, Codex ou outro) que vai instalar o **Hermes Agent** numa VPS do
usuário e deixá-lo pronto para usar: painel no ar, Hermes respondendo pela assinatura do ChatGPT
do usuário, com o nome e o tom que ele escolher, e os dois hubs de ferramentas (Maton e Zernio)
instalados como skills. O usuário é leigo. Fale em português simples, uma coisa por vez. Você
executa; ele só cola, digita num arquivo que você abre e responde "Feito".

Tudo o que a instalação precisa está neste repositório. **Use só os scripts de `harness/`.**

## O que o usuário precisa ter antes

- Uma VPS **Ubuntu 24.04** (ou 22.04, ou Debian 12), com pelo menos **2 GB de RAM** e 20 GB de
  disco. Na Hostinger: plano KVM 2 ou maior, template "Ubuntu 24.04" ou "Ubuntu 24.04 with Docker".
  Não use template com painel (EasyPanel, CloudPanel): eles ocupam as portas 80 e 443.
- O **IP** e a **senha root** da VPS (Hostinger: hPanel → VPS → Visão geral).
- Uma **assinatura do ChatGPT** (Plus, Pro, Team ou Business). É por ela que o Hermes responde.
- Opcional: conta no **Maton** (maton.ai) e no **Zernio** (zernio.com), com a chave de API de cada um.
- Na máquina dele: `ssh`, `scp`, `curl`, `perl`, OpenSSH 8.4 ou mais novo (macOS e Linux já têm;
  no Windows, use Git Bash ou WSL).

## Regras que não se negociam

1. **Segredo nunca no chat.** Senha root, senha do painel e chaves de API entram por arquivos que
   o script cria e abre no editor (`config/acesso.local`, `config/chaves.local`). Você valida com
   os scripts, que não mostram o valor. Nunca faça `cat` desses arquivos. Nunca faça `cat` de
   `/opt/hermes/.env` nem de `/opt/data/.env` na VPS. Se o usuário colar um segredo no chat,
   diga que não vai usar e peça para trocar depois.
2. **Nenhum comando na VPS fora dos scripts.** Diagnóstico é `bash harness/status.sh` e
   `bash harness/logs.sh`. Se isso não bastar, pare e explique ao usuário o que viu.
3. **Cada fase termina em `exit 0`. Falhou, não avance.** Leia a mensagem, corrija a causa, rode
   a fase de novo. Os scripts são idempotentes.
4. **Não "melhore" o desenho.** Não troque a imagem `:latest`, não abra a porta 9119, não desligue
   o login do painel, não mexa no Caddyfile, não reescreva o SOUL.md por conta própria. As razões
   estão em `docs/decisoes.md`.
5. **Na máquina do usuário você só cria:** a chave SSH em `~/.ssh/hermes-vps`, os arquivos de
   `config/` e a pasta `Meu Hermes` no Desktop.
6. **Gate humano é humano.** Onde o script pede `--confirmado`, só rode depois que o usuário
   disser que fez a parte dele. Você não consegue verificar isso por comando.

## Procedimento

### Bootstrap · o acesso à VPS

Pergunte ao usuário a linha de acesso SSH da VPS (na Hostinger: hPanel → VPS → Visão geral,
algo como `ssh root@203.0.113.10`). Depois:

```bash
bash harness/configurar.sh "ssh root@203.0.113.10"      # ou: ... "ssh root@IP" tunel
```

O script grava `config/hermes-vps.env`, cria `config/acesso.local` e abre no editor. Diga ao
usuário: *"Cole a senha root na linha VPS_ROOT_SENHA, escolha uma senha para o painel na linha
PAINEL_SENHA, salve o arquivo e me responda: Feito."* Espere o "Feito".

### Fase 0 · preflight

```bash
bash harness/05-senha.sh validar      # senha root presente e senha do painel válida, sem mostrar
bash harness/00-preflight.sh
```

O preflight gera a chave SSH, entra na VPS com a senha root do arquivo para autorizar a chave, e
daí em diante só usa a chave. Ele mede SO, RAM, disco, Docker, portas e decide o hostname HTTPS.

| saída | o que fazer |
|---|---|
| `exit 2` "criei config/..." | faltou o bootstrap; rode `configurar.sh` |
| `exit 3` "não consegui entrar" | a senha root em `acesso.local` está errada ou o IP não é esse. O usuário pode redefinir a senha no hPanel e colar de novo |
| erro "já tem algo escutando na porta 80 ou 443" | a VPS não está limpa: recriar com template sem painel, ou `MODO=tunel` no config |
| erro de RAM ou disco | avise e pergunte se quer seguir; abaixo de 2 GB, recomende trocar o plano |
| `PREFLIGHT OK` | siga |

### Fase 1 · senha do painel

Já está no arquivo desde o bootstrap. Se `05-senha.sh validar` falhar, diga o motivo (curta,
caractere não permitido) e rode `bash harness/05-senha.sh criar` para abrir o arquivo de novo.

### Fase 2 · instalar

```bash
bash harness/10-instalar.sh
```

Envia `harness/remoto/` para `/opt/hermes/harness` na VPS e roda `instalar-vps.sh` lá, como
root: pacotes, Docker, firewall `ufw`, `compose.yml`, `.env` com permissão 600, `docker compose
up`. A senha do painel vai pelo stdin do SSH. Leva de 2 a 6 minutos; a imagem tem alguns GB. No
fim, o script apaga a senha do painel do arquivo local (a senha root fica: é a credencial de
gestão da VPS).

### Fase 3 · verificar

```bash
bash harness/20-verificar.sh
```

Critérios binários: SSH entra; container `hermes` running; `/api/status` no loopback da VPS diz
`auth_required: true` e provedor `basic`; no modo público, HTTPS válido e porta 9119 fechada de
fora; no modo túnel, o túnel alcança o painel. **Só siga com todos passando.** Certificado
recém-emitido pode falhar no primeiro minuto: espere 60 s e rode de novo.

### Fase 4 · desktop

```bash
bash harness/30-desktop.sh
```

Gera `~/Desktop/Meu Hermes/Meu Hermes.html` (página local: botão do painel, primeiros passos,
comandos) e, no modo túnel, o atalho que abre a ponte SSH. Nada de senha dentro.

### Fase 5 · modelo: o Hermes entra na assinatura do ChatGPT

O Hermes vai responder pela conta do ChatGPT do usuário (provider `openai-codex`), por código de
dispositivo. Antes do código, existe uma opção que o usuário precisa ligar no ChatGPT, e você não
consegue verificar isso por comando. Mostre o roteiro e espere:

```bash
bash harness/40-modelo.sh roteiro
```

Diga ao usuário os 5 passos que o script imprime (nome → Definições → Segurança e início de
sessão → fim da página → "Ativar autorização por código de dispositivo para Codex"). Só quando
ele responder **"Ativei"**:

```bash
bash harness/40-modelo.sh iniciar --confirmado
```

O script dispara o login na VPS e imprime a URL e o código. Passe os dois ao usuário, do jeito
que o script imprime. Depois:

```bash
bash harness/40-modelo.sh esperar        # espera até 9 min; exit 3 = ainda esperando, rode de novo
bash harness/40-modelo.sh concluir       # grava provider e modelo, reinicia, prova o status
```

Se `esperar` terminar em falha, a causa mais comum é a opção do ChatGPT não ter sido ativada:
volte ao roteiro. O código vale 15 minutos; passou disso, rode `iniciar --confirmado` de novo.

### Fase 6 · alma: nome, tom e primeira semana

Cinco perguntas, no chat (nada aqui é segredo):

1. Como você quer ser chamado?
2. Que nome você quer dar ao seu agente?
3. O que você faz? Uma frase começando com verbo ("cuido de uma clínica em Manaus").
4. Tom: informal ou formal?
5. Três tarefas que você quer tirar da sua mão na primeira semana.

```bash
bash harness/50-alma.sh criar          # cria config/alma.env; preencha os 5 campos você mesmo
bash harness/50-alma.sh validar
bash harness/50-alma.sh mostrar        # o SOUL.md pronto; mostre ao usuário e peça um "ok"
bash harness/50-alma.sh aplicar        # grava SOUL.md e USER.md na VPS e reinicia
```

O SOUL.md vem de `alma/SOUL.md.template`, e só os cinco campos mudam. **Não reescreva o
template**: identidade parafraseada é outro agente, e ninguém percebe.

### Fase 7 · hubs: Maton e Zernio

```bash
bash harness/60-hubs.sh criar          # cria config/chaves.local e abre no editor
```

Diga ao usuário: *"Cole a chave do Maton e a do Zernio, salve o arquivo e me responda: Feito."*
Se ele não tiver uma delas, pode deixar vazia: esse hub fica de fora. Depois do "Feito":

```bash
bash harness/60-hubs.sh validar        # presença e tamanho, sem mostrar o valor
bash harness/60-hubs.sh aplicar        # grava no .env do Hermes, reinicia, instala as skills
bash harness/60-hubs.sh provar
```

As skills são instaladas de tags fixas e passam pelo scanner do Hermes **sem `--force`**. Se o
scanner bloquear, não force: pare e mostre a decisão ao usuário.

### Fase 8 · entrega

Diga ao usuário, nesta ordem:

1. A URL do painel e o usuário (`PAINEL_USUARIO`, padrão `admin`). A senha é a que ele digitou.
2. **Chat**: o Hermes já responde pela assinatura dele, com o nome e o tom que ele escolheu.
   Sugira o primeiro pedido: uma das três tarefas da primeira semana.
3. Maton e Zernio: peça "faça o inventário de leitura do Maton" ou "liste minhas contas no
   Zernio". As skills começam sempre em modo leitura e pedem um sim antes de qualquer escrita.
4. Canais de mensagem (Telegram, WhatsApp, Discord) se configuram no painel, em API Keys.
5. A página `Meu Hermes` no Desktop tem tudo isso e os comandos de operação.

## Operação depois de instalado

| pedido do usuário | comando |
|---|---|
| "está no ar?" | `bash harness/status.sh` |
| "deu erro / travou" | `bash harness/logs.sh` (aceita número de linhas: `bash harness/logs.sh 400`) |
| "atualiza o Hermes" | `bash harness/atualizar.sh` (faz backup antes, puxa `:latest`, sobe de novo) |
| "faz backup" | `bash harness/backup.sh` (guarda os 5 últimos em `/opt/hermes/backups`) |
| "trocar a senha do painel" | `bash harness/senha.sh criar` → usuário digita → `bash harness/senha.sh aplicar` |
| "o Hermes saiu da minha conta do ChatGPT" | `bash harness/40-modelo.sh status`; se `logged out`, refaça a Fase 5 |
| "mudar o nome ou o tom do agente" | edite `config/alma.env` e rode `bash harness/50-alma.sh aplicar` |
| "trocar uma chave do Maton ou do Zernio" | `bash harness/60-hubs.sh criar` → usuário cola → `aplicar` |
| "refaz a página do Desktop" | `bash harness/30-desktop.sh` |

## Quando algo falha

| sintoma | causa provável | ação |
|---|---|---|
| preflight não entra na VPS | senha root errada em `acesso.local`, IP errado, ou firewall da Hostinger sem a porta 22 | redefinir a senha no hPanel e colar de novo; hPanel → VPS → Regras de firewall |
| verificar falha em "HTTPS válido" | certificado ainda sendo emitido; ou firewall do hPanel sem 80/443 | esperar 60 s; conferir o firewall na Hostinger |
| verificar falha em "auth_required" | variáveis do painel não chegaram ao container | `bash harness/logs.sh`; procurar "dashboard" e "auth" |
| `esperar` termina em "timed out" | opção de código de dispositivo desligada no ChatGPT | roteiro da Fase 5, depois `iniciar --confirmado` |
| `concluir` diz `logged out` | o login não gravou credencial | `bash harness/logs.sh`; refazer a Fase 5 |
| chat responde "authentication failed" | provider gravado sem credencial, ou credencial expirada | `bash harness/40-modelo.sh status` e refazer a Fase 5 |
| skill bloqueada pelo scanner | a skill mudou upstream | não use `--force`; mostre a decisão ao usuário |
| "porta 80 ou 443 em uso" no preflight | template com painel ou outro serviço | VPS limpa ou `MODO=tunel` |
| `docker compose pull` lento ou falha | rede da VPS | rodar `bash harness/10-instalar.sh` de novo; é idempotente |

## Fatos sobre o desenho, para você não corrigir o que não está errado

- A imagem é `nousresearch/hermes-agent:latest`, oficial, com o painel embutido. Medida em
  06/09/2026: **v0.21.0** (`2026.8.31`). O gateway e o painel são supervisionados pelo s6 dentro
  do mesmo container.
- `docker exec hermes hermes ...` roda o CLI dentro do container. O shim da imagem rebaixa root
  para o usuário `hermes` (UID 10000), então `auth.json`, `config.yaml` e `.env` ficam com o dono
  certo. Os scripts de `harness/remoto/bin/` já fazem isso; não chame `docker exec` por fora.
- O `HERMES_HOME` dentro do container é `/opt/data` (volume `hermes_hermes-data`). Lá vivem
  `config.yaml`, `.env`, `auth.json`, `SOUL.md`, `USER.md`, skills, sessões e memórias.
  Reinstalar e atualizar não apagam. `atualizar.sh` faz backup antes.
- O painel escuta em `0.0.0.0:9119` **dentro** do container, e a porta só é publicada em
  `127.0.0.1` da VPS. Quem entrega para fora é o Caddy (TLS automático) no modo público, ou o
  túnel SSH no modo túnel. Bind em `0.0.0.0` é o que liga o gate de autenticação do Hermes; com
  bind em loopback o painel sobe **sem senha**.
- O hostname HTTPS de uma VPS Hostinger é o próprio `srvNNNNNN.hstgr.cloud`: já resolve para o
  IP e `hstgr.cloud` está na Public Suffix List, então o Let's Encrypt trata cada VPS como um
  domínio separado. Sem isso, o harness cai para `sslip.io`, que divide a cota com o mundo.
- O login na assinatura do ChatGPT é `hermes auth add openai-codex`: fluxo de código de
  dispositivo, sem pergunta interativa, polling de até 15 minutos. Ele **não** grava
  `model.provider`; por isso `concluir` grava `model.provider=openai-codex` e
  `model.default=gpt-5.6-terra` e reinicia. Nunca copie o `~/.codex/auth.json` da máquina do
  usuário para a VPS: o refresh token é de uso único e derruba as duas sessões.
- O `.env` de `/opt/data` é lido pelo Hermes ao subir. Chave nova só vale depois do restart, e
  os scripts já reiniciam. O Hermes semeia um `SOUL.md` padrão no primeiro boot e nunca mais
  toca num `SOUL.md` customizado: o da Fase 6 fica.
- Maton e Zernio entram como **skills**, não como servidores MCP. Tool MCP entra no schema de
  toda chamada e custa tokens por mensagem mesmo sem uso; a skill só carrega quando o pedido é
  sobre aquilo. As duas skills fazem descoberta em modo leitura e pedem aprovação antes de
  escrever.
