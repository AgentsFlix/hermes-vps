# A instalação de referência (EasyPanel)

Medido em 06/09/2026 num EasyPanel v2.32.2 rodando numa VPS Hostinger KVM 2 (2 vCPU, 8 GB,
Ubuntu 24.04 com o template "Ubuntu 24.04 with Easypanel"). Um projeto, um serviço
`hermes-agent`. Sem valores de segredo aqui, só a forma.

| no EasyPanel | valor de referência | no harness |
|---|---|---|
| Fonte | imagem Docker `nousresearch/hermes-agent@sha256:1678…` (digest fixo) | `nousresearch/hermes-agent:latest` (pedido do desenho: simplificar; `atualizar.sh` puxa a nova) |
| Ambiente | `HERMES_DASHBOARD`, `HERMES_DASHBOARD_HOST`, `HERMES_DASHBOARD_PORT`, `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`, `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | as mesmas, mais `HERMES_DASHBOARD_BASIC_AUTH_SECRET` (sessão sobrevive a reinício) |
| Armazenamento | volume `hermes-data` em `/opt/data` | volume `hermes_hermes-data` em `/opt/data` |
| Domínio | `https://<projeto>-<app>.<id>.easypanel.host` → porta 80 do container, TLS pelo Traefik do EasyPanel | `https://srvNNNNNN.hstgr.cloud` (ou domínio próprio) → Caddy → `hermes:9119` |
| Portas | 9119 → 9119 publicada | 9119 só em `127.0.0.1` da VPS |
| Comando | padrão da imagem (`gateway run`) | idem; `:latest` era a **0.21.0** (2026.8.31) em 06/09/2026, imagem de 3,84 GB |
| Firewall da VPS (hPanel) | grupo com TCP 22, 80, 443 | `ufw` com 22 e, no modo público, 80/443 |
| Uso medido | ~1,8 GB de RAM, CPU 1 a 5% em repouso | a mesma imagem; por isso o preflight exige 2 GB |

O botão "Gerenciar painel" do hPanel abre `http://IP:3000`, porta que esse firewall bloqueia;
o EasyPanel real atende em `https://IP`. Não é problema do harness (ele não usa EasyPanel), mas
explica por que o template com painel não serve para este desenho: ocupa 80 e 443.
