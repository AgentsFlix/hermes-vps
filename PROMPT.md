# O que colar no seu agente

Abra o Claude Code ou o Codex numa pasta vazia e cole isto, do jeito que está:

```text
Acesse https://github.com/AgentsFlix/hermes-vps para instalar e configurar o meu Hermes Agent.
Clone o repositório aqui, leia o AGENTS.md inteiro antes de rodar qualquer comando e siga as
fases na ordem, usando só os scripts de harness/. Pare a cada fase que pedir algo meu e me diga
exatamente o que fazer. Comece me pedindo o acesso SSH da VPS.
```

O agente vai pedir, nesta ordem: a linha `ssh root@IP` da sua VPS; a senha root e a senha do
painel (num arquivo que ele abre para você, nunca no chat); a opção de código de dispositivo no
ChatGPT; um código para você digitar no navegador; cinco respostas sobre você e sobre o que quer
delegar; e as chaves do Maton e do Zernio (no mesmo arquivo, nunca no chat).

Do começo ao fim leva de 15 a 25 minutos. No fim você tem o painel no ar, o Hermes respondendo
pela sua assinatura do ChatGPT, com o seu nome, o seu tom e os dois hubs prontos para usar.
