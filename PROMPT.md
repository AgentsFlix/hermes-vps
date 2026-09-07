# O que colar no seu agente

Abra o **Claude Code**, o **Codex** ou o **Antigravity** numa pasta vazia e cole isto, do jeito
que está:

```text
Instale e configure o meu Hermes Agent seguindo https://github.com/AgentsFlix/hermes-vps
Clone o repositório nesta pasta, leia o AGENTS.md inteiro antes de rodar qualquer comando, e
siga as fases na ordem usando só os scripts de harness/. Não improvise comando fora deles.
Pare em cada fase que precisar de mim, uma coisa por vez, e me diga exatamente o que fazer.
```

## O que ele vai pedir, nesta ordem

Nada de senha ou chave passa pelo chat. Toda vez que ele precisar de algo secreto, abre um
arquivo na sua tela, você preenche, salva e responde **Feito**.

1. **O endereço e as senhas da VPS**, num arquivo só: você troca `COLE_O_IP_AQUI` pelo IP que
   está no painel da Hostinger, cola a senha root e escolhe uma senha para o painel do agente.
2. **Uma opção no ChatGPT**: em Definições, Segurança e início de sessão, no fim da página,
   ativar a autorização por código de dispositivo para Codex. Depois ele te dá um código para
   digitar no navegador.
3. **Cinco respostas sobre você**: como quer ser chamado, que nome dar ao agente, o que você faz,
   o tom, e uma tarefa que quer tirar da sua mão nesta semana.
4. **As chaves do Maton e do Zernio**, se você tiver. Pode deixar em branco e ligar depois.
5. **O bot do Telegram**: o token do @BotFather e o seu Id do @userinfobot.

## No fim

Leva de 20 a 30 minutos. Você termina com:

- o painel do seu agente no ar, com HTTPS e senha
- ele respondendo pela sua assinatura do ChatGPT, com o nome e o tom que você escolheu
- Maton e Zernio prontos para usar, em modo leitura até você aprovar
- um bot no Telegram que só conversa com você
- a pasta **Meu Hermes** no seu Desktop, com o acesso, os comandos e o que abre a sua VPS

## Ainda não tem a VPS?

Compre uma **KVM 2** na Hostinger e escolha o aplicativo **Hermes Agent** na instalação. Os links
estão em [`docs/links-hostinger.md`](docs/links-hostinger.md). Serve também uma VPS limpa com
Ubuntu 24.04: o harness reconhece os dois casos e faz o certo em cada um.
