#!/usr/bin/env bash
# Descobre o Hermes desta VPS: o do harness (container "hermes", /opt/hermes) ou o do template da
# Hostinger (imagem hostinger/hvps-hermes-agent, /docker/<projeto>). Toda função é somente-leitura,
# menos hermes_restart. Faça: source /opt/hermes/bin/_alvo.sh
hermes_container() {
    if docker inspect hermes >/dev/null 2>&1; then echo hermes; return; fi
    docker ps --format '{{.Names}} {{.Image}}' | awk '/hermes-agent/{print $1; exit}'
}
hermes_project_dir() { docker inspect "$(hermes_container)" --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null; }
hermes_ip() { docker inspect "$(hermes_container)" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' 2>/dev/null | awk '{print $1}'; }
hermes_port() { # porta do painel DENTRO do container
    local c; c="$(hermes_container)"
    local p; p="$(docker inspect "$c" --format '{{range $k,$v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' 2>/dev/null | sed -n 's/^traefik\.http\.services\..*\.loadbalancer\.server\.port=//p' | head -1)"
    echo "${p:-9119}"
}
hermes_status_url() { echo "http://$(hermes_ip):$(hermes_port)/api/status"; }
hermes_is_template() { [ "$(hermes_container)" != hermes ]; }
hermes_restart() {
    docker restart "$(hermes_container)" >/dev/null 2>&1 || return 1
    for _ in $(seq 1 60); do curl -fsS --max-time 5 "$(hermes_status_url)" >/dev/null 2>&1 && return 0; sleep 2; done
    return 1
}
