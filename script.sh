#!/usr/bin/env bash

set -uo pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

NGINX_URL="${NGINX_URL:-http://localhost:8080}"

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

printf "\nVerificação da stack DevOps\n"
printf "============================\n\n"

# Verifica se o Docker está disponível.
if ! command -v docker >/dev/null 2>&1; then
  print_error "Docker não está instalado ou não foi encontrado."
  exit 1
fi

# Verifica se o serviço do Docker está acessível.
if ! docker info >/dev/null 2>&1; then
  print_error "Não foi possível acessar o Docker."
  exit 1
fi

print_info "Verificando os contêineres..."

if ! RUNNING_SERVICES="$(docker compose ps --status running --services 2>/dev/null)"; then
  print_error "Não foi possível consultar os serviços do Docker Compose."
  exit 1
fi

CONTAINERS_OK=true
RUNNING_COUNT=0

for SERVICE in "${EXPECTED_SERVICES[@]}"; do
  if grep -Fxq "$SERVICE" <<< "$RUNNING_SERVICES"; then
    print_ok "Contêiner $SERVICE está em execução."
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
  else
    print_error "Contêiner $SERVICE não está em execução."
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

printf "\nResumo\n"
printf "======\n"
printf "Contêineres em execução: %d/%d\n" \
  "$RUNNING_COUNT" "${#EXPECTED_SERVICES[@]}"
printf "Requisições HTTP 200: %d/10\n" "$SUCCESS_COUNT"
printf "Requisições com erro: %d/10\n\n" "$ERROR_COUNT"

if [[ "$CONTAINERS_OK" == true && "$SUCCESS_COUNT" -eq 10 ]]; then
  print_ok "Todos os serviços estão funcionando corretamente."
  exit 0
fi

print_error "Uma ou mais verificações falharam."
exit 1