# Decisões de desenho (e o que foi recusado)

**Imagem `:latest`, não digest.** A referência fixa um digest; o pedido do harness é simplificar
e `atualizar.sh` cobre a atualização com backup antes. Custo: uma atualização upstream pode mudar
comportamento sem aviso. O Hermes muda rápido (0.19 → 0.21 entre julho e setembro de 2026), então
o `status.sh` sempre imprime a versão medida.

**Caddy, não EasyPanel nem Traefik.** EasyPanel é um painel inteiro com login próprio, licença e
porta 3000; para um único serviço é peso morto. Traefik exige labels e um arquivo de config
maior. O Caddy faz TLS automático com duas linhas e cai para ZeroSSL se o Let's Encrypt falhar.

**Hostname da VPS como endereço HTTPS.** `hstgr.cloud` está na Public Suffix List (entrada
submetida pela própria Hostinger), então `srvNNNNNN.hstgr.cloud` é tratado pelo Let's Encrypt
como domínio registrado próprio, sem dividir cota. `sslip.io` e `nip.io` **não** estão na lista:
todo mundo que os usa compartilha a mesma cota de certificados. Por isso a ordem é: domínio do
usuário > hostname `hstgr.cloud` que resolve para o IP > `sslip.io` com aviso.

**Painel em `0.0.0.0` dentro do container, publicado só em `127.0.0.1` na VPS.** O gate de
autenticação do Hermes só liga em bind não-loopback (`web_server.py`, `should_require_auth`). Bind
em loopback = painel sem senha. Publicar só no loopback da VPS garante que a única porta de
entrada é o Caddy (ou o túnel). O guard de Host aceita qualquer Host quando o bind é `0.0.0.0`,
então proxy com hostname e túnel com `localhost` passam.

**Login por usuário e senha, não OAuth.** É o desenho da referência, não depende de conta em
terceiro e a documentação do Hermes o chama de "zero-infra". A mesma documentação diz que, para
exposição pública, o provedor Nous Portal (OAuth) é o indicado. Mitigação aqui: senha de 12 a 64
caracteres, HTTPS obrigatório, `SECRET` de sessão, e o modo `tunel` para quem não quer expor.

**Modo túnel no mesmo compose.** Só muda o `COMPOSE_PROFILES` (sem Caddy) e o `ufw` (sem 80/443).
O painel continua com senha, porque o bind interno continua `0.0.0.0`.

**Sem `HERMES_GATEWAY_BOOTSTRAP_STATE`.** O comentário em `docker/stage2-hook.sh` diz que, sem
`gateway_state.json`, o gateway começa parado. Medido na 0.21.0 (06/09/2026), num volume novo, o
gateway subiu sozinho (`gateway_running: true`, canal `api_server`). Então a variável não é
necessária; se uma versão futura voltar ao comportamento do comentário, `status.sh` mostra
"gateway: parado" e o usuário liga pelo painel.

**Senha por arquivo, nunca por chat, inclusive a senha root.** O agente cria `config/acesso.local`
vazio, abre no editor, valida sem imprimir e manda a senha do painel pelo stdin do SSH. A senha
root entra no mesmo arquivo e o OpenSSH a lê por `SSH_ASKPASS` para autorizar a chave (decisão de
06/09/2026: o `ssh-copy-id` digitado pelo usuário foi recusado, porque o usuário é leigo e o
terminal dele é onde as coisas dão errado). Custo: a senha root fica num arquivo 600 na máquina
do usuário como credencial de gestão. O `vps()` usa isso para se recuperar se a chave falhar.

**Volume nomeado, não bind mount.** Evita o problema de UID/GID (`HERMES_UID`) do compose oficial
e é o que a referência usa. Backup é um `tar` do volume via container `alpine`.

**Uma conexão SSH para a sonda do preflight.** Tudo o que precisa ser medido na VPS (SO, RAM,
disco, Docker, portas, hostname, IP público) sai numa chamada só, em linhas `CHAVE=valor`.

**Login na assinatura do ChatGPT por código de dispositivo, não por cópia de token.** O Hermes
tem `hermes auth add openai-codex` com esse fluxo, sem pergunta interativa. A alternativa,
copiar o `~/.codex/auth.json` da máquina do usuário, foi recusada: o refresh token é de uso
único e a cópia derruba as duas sessões. A opção "código de dispositivo para Codex" no ChatGPT
é gate humano com `--confirmado`, porque o sintoma de esquecê-la é um timeout mudo de 15 min.

**Modelo padrão `gpt-5.6-terra`.** O `auth add` não grava `model.provider`; o `concluir` grava
provider e modelo e reinicia. Terra é o meio da linha 5.6 (Sol e Luna são os extremos), e é o
que a instância de referência usa há mais tempo. Trocar é uma linha em `codex-login.sh`.

**SOUL.md por template literal, cinco campos.** O modelo do agente instalador não escreve o
SOUL.md: ele preenche `alma/SOUL.md.template`. Motivo: LLM não transcreve, melhora; um SOUL.md
parafraseado é outro agente, e ninguém percebe. O que é procedimento vai para skill; o SOUL.md
só carrega identidade, autoridade, fronteiras e padrão de qualidade.

**Maton e Zernio como skills, não como servidores MCP.** Tool MCP entra no schema de toda
chamada e custa tokens por mensagem mesmo sem uso; skill só carrega quando o pedido é sobre
aquilo. As duas skills (`AgentsFlix/hermes-maton` v0.2.0, `AgentsFlix/hermes-zernio`
v1.0.0) fazem descoberta em modo leitura e pedem aprovação antes de escrever. Instalação por
tag fixa, e o critério de aceite é passar no scanner do Hermes numa instância limpa sem
`--force` (medido na v0.21.0 em 06/09/2026: as duas passam).

**Chaves dos hubs no `.env` do Hermes, gravadas por script dentro do container.** O `.env` vive em
`/opt/data`, do usuário `hermes` (UID 10000). Escrever nele como root pelo host deixaria o
arquivo ilegível para o gateway; por isso `env-add.sh` roda `docker exec --user hermes` e faz
upsert por nome, com lista de nomes proibidos (`PATH`, `LD_PRELOAD`...). Chave nova só vale
depois do restart, e o script reinicia.
