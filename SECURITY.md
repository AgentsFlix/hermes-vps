# Segurança

## O que este harness faz com os seus segredos

- **Senha root da VPS e senha do painel**: você digita num arquivo local (`config/acesso.local`,
  permissão 600) que o harness abre para você. O agente valida sem mostrar o valor. A senha do
  painel vai para a VPS pelo stdin do SSH e é apagada do arquivo; vive só em `/opt/hermes/.env`,
  com permissão `600`. A senha root fica no arquivo como credencial de gestão: o OpenSSH a lê
  por `SSH_ASKPASS` só para autorizar a chave, e nunca em argumento, log ou chat.
- **Chave SSH**: gerada na sua máquina, sem passphrase, só para esta VPS.
- **Conta do ChatGPT**: o Hermes entra por código de dispositivo. Você digita o código numa
  página da OpenAI, no seu navegador; o agente só vê a URL e o código, que expira em 15 minutos.
  Os tokens ficam em `/opt/data/auth.json` na VPS, do usuário `hermes`.
- **Chaves do Maton e do Zernio**: você cola em `config/chaves.local` (permissão 600), que o
  harness abre para você. Validação por tamanho, sem mostrar; vão pela stdin do SSH para
  `/opt/data/.env` na VPS; os valores são apagados do arquivo local em seguida.
- **Skills** dos hubs: instaladas de tags fixas dos repositórios públicos, e passam pelo scanner
  de segurança do Hermes sem `--force`. Se o scanner bloquear, o harness para.

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
