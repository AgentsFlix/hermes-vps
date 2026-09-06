# hermes-vps · instale o Hermes Agent na sua VPS com um agente

Um harness: o repositório que o **seu agente** (Claude Code, Codex ou outro) lê e executa para
instalar o [Hermes Agent](https://github.com/NousResearch/hermes-agent) numa VPS, com painel web
protegido por senha, HTTPS automático e uma página de acesso no seu Desktop. Você cola o acesso
SSH da VPS, preenche um arquivo com as senhas e responde "Feito". O resto é dele.

Espelha uma instalação real em produção (Hermes num EasyPanel da Hostinger), sem o EasyPanel:
Docker, a imagem oficial `nousresearch/hermes-agent:latest`, Caddy na frente e o próprio
hostname da VPS como endereço.

## O que você precisa

| item | onde conseguir |
|---|---|
| VPS Ubuntu 24.04, 2 GB de RAM ou mais | Hostinger KVM 2 (template "Ubuntu 24.04" ou "Ubuntu 24.04 with Docker"; **não** o de EasyPanel) |
| IP e senha root da VPS | hPanel → VPS → Visão geral |
| Um agente no seu computador | [Claude Code](https://claude.com/claude-code) ou [Codex](https://openai.com/codex) |
| Uma chave de provedor de IA | OpenRouter, Anthropic, OpenAI… você cola **no painel**, depois |
| Windows? | Git Bash ou WSL (os scripts são bash) |

## Como usar

```bash
git clone https://github.com/AgentsFlix/hermes-vps.git
cd hermes-vps
claude        # ou: codex
```

O agente lê `AGENTS.md` e já começa perguntando o acesso SSH da VPS (a linha `ssh root@IP` do
hPanel). Depois ele abre um arquivo na sua tela: você cola a senha root, escolhe a senha do
painel, salva e responde **Feito**. A partir daí ele faz tudo: chave SSH, Docker, Hermes, HTTPS,
verificação e a pasta `Meu Hermes` no seu Desktop.

Quer fazer à mão? É a mesma sequência:

```bash
bash harness/configurar.sh "ssh root@IP"   # grava o config e abre o arquivo das senhas
bash harness/05-senha.sh validar           # confere sem mostrar
bash harness/00-preflight.sh               # entra com a senha, autoriza a chave, decide o https
bash harness/10-instalar.sh                # Docker + Hermes + Caddy na VPS
bash harness/20-verificar.sh               # só passa com o login ligado e o https válido
bash harness/30-desktop.sh                 # pasta "Meu Hermes" no seu Desktop
```

## O que fica pronto

- **Painel do Hermes** em `https://srvNNNNNN.hstgr.cloud` (ou no seu domínio), com usuário e
  senha. Chat, configuração, chaves, sessões, skills, cron, tudo pelo navegador.
- **Hermes Desktop** pode conectar nessa VPS (Settings → Gateways → Remote gateway).
- **Pasta `Meu Hermes` no Desktop** com a página de acesso, os primeiros passos e os comandos.
- **Operação por comando:** `status`, `logs`, `atualizar` (com backup antes), `backup`, `senha`.

Prefere não expor nada na internet? `MODO=tunel` no config: só a porta 22 fica aberta e o painel
abre por túnel SSH, com um atalho de dois cliques no Desktop.

## Estrutura

```text
AGENTS.md              o harness: o que o agente faz, em que ordem, e o que ele nunca faz
CLAUDE.md              importa AGENTS.md para o Claude Code
harness/configurar.sh  bootstrap: lê "ssh root@IP", grava o config, abre o arquivo das senhas
harness/00-preflight.sh, 05-senha.sh, 10-instalar.sh, 20-verificar.sh, 30-desktop.sh
harness/status.sh, logs.sh, atualizar.sh, backup.sh, senha.sh     operação (rodam na VPS por SSH)
harness/remoto/        o que vai para /opt/hermes na VPS: instalar-vps.sh, compose.yml, Caddyfile, bin/
desktop/template.html  a página gerada no Desktop
config/                seu config local (não versionado)
docs/                  referência do EasyPanel, decisões e problemas conhecidos
tests/run.sh           lint, validação do compose e do Caddyfile, geração da página
```

## Segurança

Leia [SECURITY.md](SECURITY.md). Resumo: a senha do painel vive só na VPS, com permissão 600;
a chave de IA nunca passa pelo agente; a porta 9119 do painel fica presa no loopback da VPS; o
login é obrigatório em toda rota. O provedor de login por senha é o "zero-infra" do Hermes; para
exposição pública com conta gerenciada, o Hermes oferece OAuth pelo Nous Portal.

## Licença

MIT. Hermes Agent é da [Nous Research](https://nousresearch.com), também MIT.
Este harness é mantido pela [AgentsFlix](https://agentsflix.ai).
