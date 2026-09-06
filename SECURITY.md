# Segurança

## O que este harness faz com os seus segredos

- **Senha do painel**: você digita num arquivo local (`config/senha.local`) que o harness abre para você.
  O agente valida tamanho e caracteres sem mostrar o valor, envia para a VPS pelo stdin do SSH
  e apaga o arquivo. A senha vive só em `/opt/hermes/.env` na VPS, com permissão `600`.
- **Chave de provedor de IA** (OpenRouter, Anthropic, OpenAI...): nunca passa pelo agente.
  Você cola no painel do Hermes, em *API Keys*, depois de instalado.
- **Chave SSH**: gerada na sua máquina, sem passphrase, só para esta VPS. A senha root da VPS você
  digita uma vez no seu terminal, no `ssh-copy-id`. O agente não a vê.

## O que fica exposto na internet

No modo `publico`: portas 22 (SSH), 80 e 443 (Caddy com TLS automático). O painel do Hermes só
responde atrás do Caddy e exige usuário e senha em toda rota. A porta 9119 do painel fica presa em
`127.0.0.1` na VPS.

No modo `tunel`: só a porta 22. O painel é alcançado por `ssh -L`.

O provedor de login por usuário e senha é o que a documentação do Hermes chama de "zero-infra" e
recomenda para rede confiável ou VPN. Para exposição pública com conta gerenciada, o Hermes oferece
login via Nous Portal (OAuth). Este harness usa usuário e senha porque é o desenho da instalação de
referência e porque não depende de conta em terceiro. Use senha longa e o modo `tunel` se preferir
não expor nada.

## Reportar

Falha de segurança: escreva em privado para o mantenedor do repositório. Não abra issue pública
com material sensível.
