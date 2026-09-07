# Problemas conhecidos

- **Certificado demora até 1 minuto na primeira visita.** O Caddy emite sob demanda. `20-verificar.sh`
  pode falhar em "HTTPS válido" nesse intervalo: espere e rode de novo.
- **Firewall da Hostinger é separado do `ufw`.** Se a VPS tem um grupo de firewall no hPanel sem
  80/443, o HTTPS não chega. hPanel → VPS → Regras de firewall.
- **Template com painel (EasyPanel, CloudPanel) ocupa 80 e 443.** O preflight recusa. Recrie a VPS
  com "Ubuntu 24.04" ou use `MODO=tunel`.
- **Console web da Hostinger corrompe caracteres colados** (`:` vira `;`, `@` some). A própria
  documentação do Hermes avisa. O harness só usa SSH, mas se você for digitar algo na VPS, use SSH.
- **Menos de 2 GB de RAM sofre.** A referência usa ~1,8 GB em repouso. KVM 1 (4 GB) passa; abaixo
  disso o preflight avisa.
- **`sslip.io` pode não conseguir certificado** por cota compartilhada. Se cair nesse caso, aponte um
  domínio seu (`DOMINIO=` no config) e rode preflight + instalar de novo.
- **Windows sem Git Bash ou WSL não roda os scripts.** São bash. O `.bat` do túnel, sim, é nativo.
- **A imagem tem ~3,8 GB.** A primeira instalação depende da rede da VPS; na Hostinger leva de 1 a
  3 minutos. `docker compose pull` que falhar no meio se resolve rodando `10-instalar.sh` de novo.
- **Desktop remoto exige o painel acessível pelo mesmo host que você digita.** Com o Caddy isso é
  automático. Não troque o hostname sem reinstalar.

## Modo template (VPS com o aplicativo Hermes da Hostinger)

- **O painel é o da Hostinger, atrás do Traefik**, em `https://<projeto>.<hostname>.hstgr.cloud`.
  O usuário e a senha são os que você digitou na tela "Configurar Hermes Agent", não os do harness.
- **O template publica a porta do painel numa porta alta do host, em HTTP puro e aberta na
  internet.** O `10-instalar.sh` remove esse bloco `ports:` do compose (backup em
  `docker-compose.yml.antes-do-harness`) e sobe de novo. O Traefik continua servindo com TLS.
- **Atualizar e fazer backup são do painel da Hostinger** (Gerenciador Docker → Gerenciar). Os
  scripts `atualizar.sh` e `backup.sh` recusam rodar em modo template, de propósito.
- **O executor do Hermes bloqueia `sh -c` e `python3 -c` com script inline** (verdict "Command
  flagged as dangerous"). Skill que precise de chamada autenticada deve usar `curl` com a
  variável de ambiente, que passa. Medido em 07/09/2026 na v0.21.0.
- **`docker exec` não lê o `.env` do Hermes.** Um shell novo dentro do container não tem as
  variáveis; quem lê é o processo do gateway, ao subir. Testar credencial por `docker exec` dá
  falso negativo: use `bash harness/60-hubs.sh provar`, que lê o arquivo.
