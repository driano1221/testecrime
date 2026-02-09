# SINESP-as-a-Service

API REST que expõe dados e insights de segurança pública do Brasil (SINESP VDE, 2015–2024) em JSON, com contrato estável (OpenAPI), para qualquer aplicação consumir — sem depender de R no cliente.

## O que é

Um **serviço web** que disponibiliza:

- **Dados** criminais oficiais por UF, município, categoria e tipologia
- **Tendências** (variação 12m/24m, direção)
- **Previsões** (ARIMA automático)
- **Metadados** de transparência (fonte, freshness, cobertura, snapshot_id)

## O que NÃO é

- Não faz consulta ao vivo ao portal a cada requisição (dados vêm de snapshot local)
- Não é "score de risco" determinista — é **tendência histórica oficial + transparência**

## Quick Start

### 1. Refresh (popular o cache de dados)

```bash
# Instalar dependências R necessárias primeiro
Rscript -e 'install.packages(c("jsonlite", "digest", "dplyr", "BrazilCrime"))'

# Executar o pipeline de refresh
Rscript R/refresh.R
```

### 2. Subir a API

```bash
# Instalar dependências da API
Rscript -e 'install.packages(c("plumber", "forecast", "ggplot2"))'

# Iniciar
Rscript R/run_api.R
```

A API estará disponível em `http://localhost:8000` com Swagger UI.

### Ou via Docker

```bash
# Build
docker build -t sinesp-api .

# Refresh (popular dados)
docker run --rm -v sinesp-data:/app/data/snapshots sinesp-api Rscript R/refresh.R

# API
docker run -p 8000:8000 -v sinesp-data:/app/data/snapshots sinesp-api
```

### Ou via Docker Compose

```bash
# Refresh + API
docker compose run refresh
docker compose up api
```

## Endpoints

| Método | Rota | Descrição |
|--------|------|-----------|
| `GET` | `/status` | Status do serviço, freshness, cobertura |
| `GET` | `/v1/data` | Consulta dados criminais (filtros + paginação) |
| `GET` | `/v1/trend` | Tendência e variação temporal |
| `GET` | `/v1/predict` | Previsão ARIMA automática |

### Parâmetros comuns

| Parâmetro | Tipo | Default | Descrição |
|-----------|------|---------|-----------|
| `state` | string | `all` | Sigla da UF (ex: `SP`, `SP,RJ`) |
| `city` | string | `all` | Nome do município |
| `year` | string | `all` | Ano(s) (ex: `2020`, `2020,2021,2022`) |
| `category` | string | `all` | Categoria do crime |
| `typology` | string | `all` | Tipologia (ex: `Furto de veículo`) |
| `granularity` | string | `month` | `month` ou `year` |

### Exemplos

**curl:**

```bash
# Dados de SP em 2022
curl "http://localhost:8000/v1/data?state=SP&year=2022"

# Tendência de homicídios no RJ
curl "http://localhost:8000/v1/trend?state=RJ&category=Homicidio"

# Previsão 6 meses para MG
curl "http://localhost:8000/v1/predict?state=MG&h=6"

# Status do serviço
curl "http://localhost:8000/status"
```

**JavaScript:**

```javascript
const response = await fetch('http://localhost:8000/v1/data?state=SP&year=2022');
const { meta, pagination, data } = await response.json();
console.log(`${pagination.total_records} registros (snapshot: ${meta.snapshot_id})`);
```

**Python:**

```python
import requests

resp = requests.get('http://localhost:8000/v1/data', params={
    'state': 'SP',
    'year': '2020,2021,2022',
    'category': 'Homicidio'
})
result = resp.json()
print(f"{result['pagination']['total_records']} registros")
```

## Arquitetura

```
┌──────────────────┐       ┌────────────────┐       ┌──────────────┐
│  BrazilCrime     │──────▶│  Refresh Job   │──────▶│  Snapshot    │
│  (SINESP VDE)    │       │  (R/refresh.R) │       │  (CSV.gz +   │
│                  │       │  - normaliza   │       │   meta.json) │
└──────────────────┘       │  - testes QA   │       └──────┬───────┘
                           └────────────────┘              │
                                                           ▼
                           ┌────────────────┐       ┌──────────────┐
                           │  Clientes      │◀──────│  Plumber API │
                           │  (JS/Python/   │       │  - /status   │
                           │   curl/apps)   │       │  - /v1/data  │
                           └────────────────┘       │  - /v1/trend │
                                                    │  - /v1/predict│
                                                    └──────────────┘
```

### Componentes

| Componente | Arquivo(s) | Responsabilidade |
|------------|-----------|------------------|
| **Config** | `R/config.R` | Configuração central, variáveis de ambiente |
| **Logger** | `R/logger.R` | Logging estruturado com níveis |
| **Refresh** | `R/refresh.R` | Pipeline de coleta, normalização, snapshot |
| **Data Loader** | `R/data_loader.R` | Leitura de snapshots, filtros, paginação |
| **Analytics** | `R/analytics.R` | Trend (variação temporal) e Predict (ARIMA) |
| **API** | `R/api.R` | Endpoints Plumber com rate-limit |
| **Runner** | `R/run_api.R` | Inicialização do servidor |

## Pipeline de Dados

O refresh é **idempotente** — rodar 2x gera o mesmo resultado (snapshot baseado em hash do conteúdo).

Cada execução:

1. **Coleta** dados via `BrazilCrime::get_sinesp_vde_data()`
2. **Normaliza** encoding, nomes de colunas, tipos
3. **Testa qualidade** (schema, ranges, consistência, sanity checks)
4. **Salva snapshot** com `snapshot_id` = `YYYYMMDD_<hash>` + `meta.json`

O cron (GitHub Actions) roda semanalmente. O snapshot é versionado para reprodutibilidade.

## Testes

```bash
# Rodar todos os testes
Rscript -e 'testthat::test_dir("tests/")'
```

Testes cobrem:
- Filtros e paginação (`test_data_loader.R`)
- Cálculos de tendência e previsão (`test_analytics.R`)
- Validações de qualidade de dados (`test_quality.R`)

## Estrutura do Projeto

```
testecrime/
├── R/
│   ├── config.R          # Configuração central
│   ├── logger.R          # Logger
│   ├── refresh.R         # Pipeline de atualização
│   ├── data_loader.R     # Leitura e filtragem
│   ├── analytics.R       # Trend + Predict
│   ├── api.R             # Endpoints Plumber
│   └── run_api.R         # Inicialização do servidor
├── tests/
│   ├── test_data_loader.R
│   ├── test_analytics.R
│   └── test_quality.R
├── data/
│   └── snapshots/        # Snapshots gerados pelo refresh
├── docs/
│   ├── DATA_DICTIONARY.md
│   ├── METHODOLOGY.md
│   └── USAGE_POLICY.md
├── .github/
│   └── workflows/
│       ├── ci.yml        # CI (lint + testes)
│       └── refresh.yml   # Cron de refresh semanal
├── openapi.yaml          # Contrato da API (OpenAPI 3.0)
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── .gitignore
├── .dockerignore
├── LICENSE
└── README.md
```

## Fonte dos Dados

Todos os dados são do **Sistema Nacional de Informações de Segurança Pública (SINESP)**, plataforma integrada mantida pela **Secretaria Nacional de Segurança Pública (SENASP)** do **Ministério da Justiça e Segurança Pública**.

- Portal: https://www.gov.br/mj/pt-br/assuntos/sua-seguranca/seguranca-publica/sinesp-1
- Extração via pacote R [`BrazilCrime`](https://CRAN.R-project.org/package=BrazilCrime)

## Licença

MIT — ver [LICENSE](LICENSE).
