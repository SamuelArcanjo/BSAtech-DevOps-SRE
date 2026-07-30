#!/usr/bin/env bash

set -uo pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

NGINX_URL="${NGINX_URL:-http://localhost:8080}"
NGINX_STATUS_URL="${NGINX_STATUS_URL:-http://localhost:8080/nginx_status}"
EXPORTER_URL="${EXPORTER_URL:-http://localhost:9113/metrics}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090/-/ready}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000/api/health}"

EXPECTED_SERVICES=(
  "nginx"
  "nginx-exporter"
  "prometheus"
  "grafana"
)

print_ok() {
  printf "${GREEN}[OK]${RESET} %s\n" "$1"
}

print_error() {
  printf "${RED}[ERRO]${RESET} %s\n" "$1"
}

print_info() {
  printf "${YELLOW}[INFO]${RESET} %s\n" "$1"
}

check_http_200() {
  local NAME="$1"
  local URL="$2"
  local HTTP_CODE

  HTTP_CODE="$(
    curl \
      --silent \
      --output /dev/null \
      --write-out "%{http_code}" \
      --max-time 5 \
      "$URL" || true
  )"

  if [[ "$HTTP_CODE" == "200" ]]; then
    print_ok "$NAME está respondendo HTTP 200."
    ENDPOINT_COUNT=$((ENDPOINT_COUNT + 1))
  else
    print_error "$NAME retornou HTTP ${HTTP_CODE:-sem resposta}."
    ENDPOINTS_OK=false
  fi
}

printf "\nVerificação da stack DevOps\n"
printf "============================\n\n"

if ! command -v docker >/dev/null 2>&1; then
  print_error "Docker não está instalado ou não foi encontrado."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  print_error "curl não está instalado ou não foi encontrado."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  print_error "Não foi possível acessar o Docker."
  exit 1
fi

print_info "Verificando execução e saúde dos contêineres..."

CONTAINERS_OK=true
RUNNING_COUNT=0
HEALTHY_COUNT=0

for SERVICE in "${EXPECTED_SERVICES[@]}"; do
  CONTAINER_ID="$(docker compose ps -q "$SERVICE" 2>/dev/null)"

  if [[ -z "$CONTAINER_ID" ]]; then
    print_error "Contêiner $SERVICE não foi encontrado."
    CONTAINERS_OK=false
    continue
  fi

  RUNNING_STATUS="$(
    docker inspect \
      --format '{{.State.Running}}' \
      "$CONTAINER_ID" 2>/dev/null || true
  )"

  HEALTH_STATUS="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}' \
      "$CONTAINER_ID" 2>/dev/null || true
  )"

  if [[ "$RUNNING_STATUS" == "true" ]]; then
    print_ok "Contêiner $SERVICE está em execução."
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
  else
    print_error "Contêiner $SERVICE não está em execução."
    CONTAINERS_OK=false
  fi

  if [[ "$HEALTH_STATUS" == "healthy" ]]; then
    print_ok "Contêiner $SERVICE está saudável."
    HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
  else
    print_error "Contêiner $SERVICE não está saudável: ${HEALTH_STATUS:-desconhecido}."
    CONTAINERS_OK=false
  fi
done

printf "\n"
print_info "Enviando 10 requisições HTTP para $NGINX_URL..."

SUCCESS_COUNT=0
ERROR_COUNT=0

for REQUEST_NUMBER in {1..10}; do
  HTTP_CODE="$(
    curl \
      --silent \
      --output /dev/null \
      --write-out "%{http_code}" \
      --max-time 5 \
      "$NGINX_URL" || true
  )"

  if [[ "$HTTP_CODE" == "200" ]]; then
    print_ok "Requisição $REQUEST_NUMBER: HTTP 200"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    print_error "Requisição $REQUEST_NUMBER: HTTP ${HTTP_CODE:-sem resposta}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
done

printf "\n"
print_info "Validando os endpoints dos serviços..."

ENDPOINTS_OK=true
ENDPOINT_COUNT=0

if NGINX_STATUS_RESPONSE="$(
  curl --silent --fail --max-time 5 "$NGINX_STATUS_URL" 2>/dev/null
)" && grep -q "Active connections" <<< "$NGINX_STATUS_RESPONSE"; then
  print_ok "Endpoint de status do Nginx está funcionando."
  ENDPOINT_COUNT=$((ENDPOINT_COUNT + 1))
else
  print_error "Endpoint de status do Nginx não está funcionando."
  ENDPOINTS_OK=false
fi

if EXPORTER_RESPONSE="$(
  curl --silent --fail --max-time 5 "$EXPORTER_URL" 2>/dev/null
)" && grep -Eq '^nginx_up(\{[^}]*\})?[[:space:]]+1(\.0+)?$' <<< "$EXPORTER_RESPONSE"; then
  print_ok "Nginx Exporter está expondo métricas com nginx_up = 1."
  ENDPOINT_COUNT=$((ENDPOINT_COUNT + 1))
else
  print_error "Nginx Exporter não está expondo métricas válidas."
  ENDPOINTS_OK=false
fi

check_http_200 "Prometheus" "$PROMETHEUS_URL"
check_http_200 "Grafana" "$GRAFANA_URL"

printf "\nResumo\n"
printf "======\n"
printf "Contêineres em execução: %d/%d\n" \
  "$RUNNING_COUNT" "${#EXPECTED_SERVICES[@]}"
printf "Contêineres saudáveis: %d/%d\n" \
  "$HEALTHY_COUNT" "${#EXPECTED_SERVICES[@]}"
printf "Requisições HTTP 200: %d/10\n" "$SUCCESS_COUNT"
printf "Requisições com erro: %d/10\n" "$ERROR_COUNT"
printf "Endpoints validados: %d/4\n\n" "$ENDPOINT_COUNT"

if [[ "$CONTAINERS_OK" == true &&
      "$ENDPOINTS_OK" == true &&
      "$SUCCESS_COUNT" -eq 10 ]]; then
  print_ok "Todos os serviços estão funcionando e saudáveis."
  exit 0
fi

print_error "Uma ou mais verificações falharam."
exit 1