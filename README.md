# Monitoramento de Nginx com Prometheus e Grafana

Projeto desenvolvido como teste prático para demonstrar fundamentos de infraestrutura como código, gerenciamento de contêineres, coleta de métricas e automação com Shell Script.

Toda a stack é iniciada com um único comando:

```bash
docker compose up -d
```

## Arquitetura

```mermaid
flowchart LR
    A[Cliente] -->|HTTP :8080| B[Nginx]
    B -->|/nginx_status| C[NGINX Exporter]
    C -->|Métricas :9113| D[Prometheus]
    D -->|Data Source| E[Grafana]
```

A stack contém:

- **Nginx:** disponibiliza uma página HTML e o endpoint `/nginx_status`.
- **NGINX Prometheus Exporter:** transforma os dados do Nginx em métricas.
- **Prometheus:** coleta as métricas do exporter a cada 5 segundos.
- **Grafana:** apresenta as métricas em um dashboard provisionado automaticamente.
- **Shell Script:** verifica os contêineres e testa a resposta HTTP do Nginx.

## Tecnologias utilizadas

- Docker
- Docker Compose
- Nginx
- NGINX Prometheus Exporter 1.5.1
- Prometheus 3.13.1
- Grafana 13.1.0
- Bash

## Pré-requisitos

É necessário possuir o Docker e o Docker Compose instalados.

Para verificar:

```bash
docker --version
docker compose version
```

## Estrutura do projeto

```text
devops-bsa/
├── docker-compose.yml
├── grafana/
│   ├── dashboards/
│   │   └── nginx-dashboard.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboard.yml
│       └── datasources/
│           └── datasource.yml
├── nginx/
│   ├── default.conf
│   └── html/
│       └── index.html
├── prometheus/
│   └── prometheus.yml
├── README.md
└── script.sh
```

## Como executar

Após clonar o repositório, acesse a pasta do projeto:

```bash
cd devops-bsa
```

Inicie todos os serviços:

```bash
docker compose up -d
```

Confira o estado dos contêineres:

```bash
docker compose ps
```

Os quatro serviços devem aparecer com o estado `Up`:

- `nginx`
- `nginx-exporter`
- `prometheus`
- `grafana`

## Endereços dos serviços

| Serviço | Endereço |
|---|---|
| Página do Nginx | http://localhost:8080 |
| Status do Nginx | http://localhost:8080/nginx_status |
| Métricas do exporter | http://localhost:9113/metrics |
| Prometheus | http://localhost:9090 |
| Targets do Prometheus | http://localhost:9090/targets |
| Grafana | http://localhost:3000 |
| Dashboard do Nginx | http://localhost:3000/d/nginx-monitoring |

Credenciais locais do Grafana:

```text
Usuário: admin
Senha: admin
```

## Dashboard do Grafana

O Data Source do Prometheus e o dashboard são provisionados automaticamente durante a inicialização do Grafana. Não é necessário realizar configurações manuais pela interface.

O dashboard possui os seguintes painéis:

1. **Requisições por segundo (RPS)**

   Consulta PromQL utilizada:

   ```promql
   rate(nginx_http_requests_total[1m])
   ```

2. **Status/disponibilidade do Nginx**

   Consulta PromQL utilizada:

   ```promql
   nginx_up
   ```

   O valor `1` representa `UP` e o valor `0` representa `DOWN`.

3. **Conexões ativas do Nginx**

   Consulta PromQL utilizada:

   ```promql
   nginx_connections_active
   ```

   O painel apresenta a quantidade atual de conexões ativas no Nginx.

## Script de automação

O arquivo `script.sh` realiza as seguintes operações:

- Verifica se os quatro serviços estão em execução.
- Envia 10 requisições HTTP GET para o Nginx.
- Confere se cada resposta possui código HTTP 200.
- Exibe um resumo colorido no terminal.
- Retorna código de saída `0` em caso de sucesso e `1` em caso de falha.

Para executar:

```bash
chmod +x script.sh
./script.sh
```

Exemplo de resumo esperado:

```text
Contêineres em execução: 4/4
Requisições HTTP 200: 10/10
Requisições com erro: 0/10

[OK] Todos os serviços estão funcionando corretamente.
```

As requisições feitas pelo script também geram tráfego para o painel de RPS do Grafana.

## Verificação das métricas

Para confirmar que o exporter consegue acessar o Nginx:

```bash
curl -s http://localhost:9113/metrics | grep nginx_up
```

Resultado esperado:

```text
nginx_up 1
```

Para confirmar que o Prometheus está coletando a métrica:

```bash
curl -s "http://localhost:9090/api/v1/query?query=nginx_up"
```

A resposta deve apresentar `"status":"success"` e o valor `"1"`.

## Logs e solução de problemas

Para visualizar os logs de todos os serviços:

```bash
docker compose logs
```

Para acompanhar os logs em tempo real:

```bash
docker compose logs -f
```

Para visualizar os logs de um serviço específico:

```bash
docker compose logs nginx
docker compose logs nginx-exporter
docker compose logs prometheus
docker compose logs grafana
```

## Encerrar a stack

Para parar e remover os contêineres:

```bash
docker compose down
```

Para remover também os volumes com os dados do Prometheus e Grafana:

```bash
docker compose down -v
```

> O uso de `-v` remove os dados armazenados nos volumes do projeto.

## Autor

Samuel Arcanjo