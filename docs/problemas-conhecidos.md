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
