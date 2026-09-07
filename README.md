# hermes-vps · instale o Hermes Agent na sua VPS com um agente

Um harness: o repositório que o **seu agente** (Claude Code, Codex ou outro) lê e executa para
instalar o [Hermes Agent](https://github.com/NousResearch/hermes-agent) numa VPS e deixá-lo
pronto: painel web com senha e HTTPS, Hermes respondendo pela **sua assinatura do ChatGPT**, com
o nome e o tom que você escolher, e os hubs **Maton** e **Zernio** instalados como skills. Você
cola o acesso SSH da VPS, preenche dois arquivos que ele abre para você e responde "Feito". O
resto é dele.

Harness é o conjunto de regras que segura o agente no trilho. Aqui ele é o `AGENTS.md` mais os
scripts de `harness/`, cada um com uma prova binária no fim.

Espelha uma instalação real em produção (Hermes num EasyPanel da Hostinger), sem o EasyPanel:
Docker, a imagem oficial `nousresearch/hermes-agent:latest`, Caddy na frente e o próprio
hostname da VPS como endereço.

## O que você precisa

| item | onde conseguir |
|---|---|
| VPS Ubuntu 24.04, 2 GB de RAM ou mais | Hostinger KVM 2 (template "Ubuntu 24.04" ou "Ubuntu 24.04 with Docker"; **não** o de EasyPanel) |
| IP e senha root da VPS | hPanel → VPS → Visão geral |
| Um agente no seu computador | [Claude Code](https://claude.com/claude-code) ou [Codex](https://openai.com/codex) |
| Assinatura do ChatGPT (Plus, Pro, Team ou Business) | é por ela que o Hermes responde; o login é por código de dispositivo |
| Opcional: chaves do Maton e do Zernio | maton.ai e zernio.com; você cola **num arquivo**, nunca no chat |
| Windows? | Git Bash ou WSL (os scripts são bash) |

## Como usar

Abra o Claude Code ou o Codex numa pasta vazia e cole o texto de [`PROMPT.md`](PROMPT.md):

```text
Acesse https://github.com/AgentsFlix/hermes-vps para instalar e configurar o meu Hermes Agent.
Clone o repositório aqui, leia o AGENTS.md inteiro antes de rodar qualquer comando e siga as
fases na ordem, usando só os scripts de harness/. Pare a cada fase que pedir algo meu e me diga
exatamente o que fazer. Comece me pedindo o acesso SSH da VPS.
```

O agente lê `AGENTS.md` e começa perguntando o acesso SSH da VPS (a linha `ssh root@IP` do
hPanel). Depois ele abre um arquivo na sua tela: você cola a senha root, escolhe a senha do
painel, salva e responde **Feito**. Ele instala, verifica, e segue para o onboarding: liga o
Hermes na sua conta do ChatGPT (você digita um código numa página), faz cinco perguntas sobre
você e sobre o que quer delegar, e abre um segundo arquivo para as chaves do Maton e do Zernio.

Quer fazer à mão? É a mesma sequência:

```bash
bash harness/configurar.sh "ssh root@IP"   # grava o config e abre o arquivo das senhas
bash harness/05-senha.sh validar           # confere sem mostrar
bash harness/00-preflight.sh               # entra com a senha, autoriza a chave, decide o https
bash harness/10-instalar.sh                # Docker + Hermes + Caddy na VPS
bash harness/20-verificar.sh               # só passa com o login ligado e o https válido
bash harness/30-desktop.sh                 # pasta "Meu Hermes" no seu Desktop
bash harness/40-modelo.sh roteiro          # o que ligar no ChatGPT; depois: iniciar --confirmado, esperar, concluir
bash harness/50-alma.sh criar              # 5 respostas → SOUL.md e USER.md; depois: mostrar, aplicar
bash harness/60-hubs.sh criar              # chaves do Maton e do Zernio; depois: validar, aplicar, provar
bash harness/70-telegram.sh roteiro        # bot do @BotFather e Id do @userinfobot; depois: criar, validar, aplicar
```

## O que fica pronto

- **Painel do Hermes** em `https://srvNNNNNN.hstgr.cloud` (ou no seu domínio), com usuário e
  senha. Chat, configuração, chaves, sessões, skills, cron, tudo pelo navegador.
- **Hermes logado na sua assinatura do ChatGPT** (modelo `gpt-5.6-terra`), com o seu nome, o seu
  tom e as três tarefas da primeira semana no `SOUL.md`.
- **Maton e Zernio como skills**, com as chaves no `.env` do Hermes. As duas começam em modo
  leitura e pedem um sim antes de qualquer escrita.
- **Um bot no Telegram** que só conversa com quem você autorizou, para falar com o agente do
  celular sem abrir o painel.
- **Hermes Desktop** pode conectar nessa VPS (Settings → Gateways → Remote gateway).
- **Pasta `Meu Hermes` no Desktop** com a página de acesso, os primeiros passos e os comandos.
- **Operação por comando:** `status`, `logs`, `atualizar` (com backup antes), `backup`, `senha`.

Prefere não expor nada na internet? `MODO=tunel` no config: só a porta 22 fica aberta e o painel
abre por túnel SSH, com um atalho de dois cliques no Desktop.

## Estrutura

```text
PROMPT.md              o que o usuário cola no agente
AGENTS.md              o harness: o que o agente faz, em que ordem, e o que ele nunca faz
CLAUDE.md              importa AGENTS.md para o Claude Code
harness/configurar.sh  bootstrap: lê "ssh root@IP", grava o config, abre o arquivo das senhas
harness/00-preflight.sh, 05-senha.sh, 10-instalar.sh, 20-verificar.sh, 30-desktop.sh   instalação
harness/40-modelo.sh, 50-alma.sh, 60-hubs.sh, 70-telegram.sh                            onboarding
harness/status.sh, logs.sh, atualizar.sh, backup.sh, senha.sh     operação (rodam na VPS por SSH)
harness/remoto/        o que vai para /opt/hermes na VPS: instalar-vps.sh, compose.yml, Caddyfile, bin/
alma/                  os templates do SOUL.md e do USER.md; só os cinco campos mudam
desktop/template.html  a página gerada no Desktop
config/                seu config local (não versionado)
docs/                  referência do EasyPanel, decisões e problemas conhecidos
tests/run.sh           lint, validação do compose e do Caddyfile, geração da página
```

## Segurança

Leia [SECURITY.md](SECURITY.md). Resumo: senha e chaves entram por arquivo, nunca pelo chat;
vivem só na VPS, com permissão 600; a porta 9119 do painel fica presa no loopback da VPS; o
login é obrigatório em toda rota; as skills passam pelo scanner do Hermes sem `--force`. O provedor de login por senha é o "zero-infra" do Hermes; para
exposição pública com conta gerenciada, o Hermes oferece OAuth pelo Nous Portal.

## Estado

**Provado de ponta a ponta numa VPS real em 07/09/2026** (nove fases), no caminho que o cliente compra: VPS
Hostinger KVM 2 com o aplicativo "Hermes Agent" (Docker + Traefik), Hermes v0.21.0. As oito fases
passaram, com prova em cada uma:

| fase | prova |
|---|---|
| bootstrap + preflight | template reconhecido; chave SSH autorizada pela senha do arquivo |
| instalar (modo template) | porta do painel em HTTP puro fechada, com backup do compose |
| verificar | 9 de 9: gate de senha, HTTPS pelo Traefik, nenhuma porta publicada |
| desktop | página `Meu Hermes` com o usuário certo do painel |
| modelo | o agente respondeu "Modelo: gpt-5.6-terra; provedor: openai-codex" |
| alma | o agente se apresentou pelo nome escolhido e disse quem é o dono |
| hubs | as duas chaves no `.env`, as duas skills instaladas sem `--force`, as duas APIs em 200 |
| telegram | o gateway passou a reportar `telegram connected` e o bot respondeu no celular |

Duas coisas que só apareceram na VPS real e já estão corrigidas aqui: o modo template (o preflight
antigo recusava a VPS por causa das portas do Traefik) e uma gravação de credencial que falhava em
silêncio (o código Python ocupava o mesmo canal dos dados). Hoje a fase de hubs confere as duas
pontas antes de apagar o que você colou.

## Licença

MIT. Hermes Agent é da [Nous Research](https://nousresearch.com), também MIT.
Este harness é mantido pela [AgentsFlix](https://agentsflix.ai).
