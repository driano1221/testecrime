# Data Dictionary

Dicionário de dados do SINESP-as-a-Service.

## Dados de Crime (facts)

Tabela principal retornada por `/v1/data`.

| Campo | Tipo | Descrição | Exemplo |
|-------|------|-----------|---------|
| `state` | string | Sigla da Unidade Federativa (UF) | `"SP"` |
| `city` | string | Nome do município | `"São Paulo"` |
| `year` | integer | Ano da ocorrência | `2022` |
| `month` | integer | Mês da ocorrência (1–12). Omitido quando `granularity=year` | `6` |
| `category` | string | Categoria do evento criminal (evento) | `"Homicídio doloso"` |
| `typology` | string | Tipologia específica do crime | `"Furto de veículo"` |
| `count` | number | Número de vítimas/ocorrências no período | `150` |
| `region` | string | Região geográfica (quando disponível) | `"Sudeste"` |

## Metadados do Snapshot (meta.json)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `snapshot_id` | string | Identificador único: `YYYYMMDD_<hash>` |
| `last_refresh` | datetime (ISO 8601) | Timestamp da última atualização |
| `row_count` | integer | Total de registros no snapshot |
| `col_count` | integer | Total de colunas |
| `columns` | array[string] | Nomes das colunas presentes |
| `coverage.states` | array[string] | Lista de UFs cobertas |
| `coverage.years` | array[integer] | Lista de anos cobertos |
| `coverage.categories` | array[string] | Lista de categorias cobertas |
| `source` | string | Descrição da fonte oficial |
| `source_url` | string | URL do portal SINESP |
| `notes` | string | Notas sobre limitações |
| `checksum` | string | Hash MD5 do dataframe (reprodutibilidade) |

## Resposta de Tendência (/v1/trend)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `direction` | string | `"rising"`, `"falling"` ou `"stable"` |
| `change_12m_pct` | number | Variação percentual últimos 12 meses |
| `change_24m_pct` | number | Variação percentual últimos 24 meses |
| `latest_period` | string | Último período da série (`"YYYY-MM"`) |
| `latest_value` | number | Valor do último período |
| `previous_12m_value` | number | Valor de 12 meses atrás |
| `previous_24m_value` | number | Valor de 24 meses atrás |

**Critério de direção:** variação > 5% = `rising`, < -5% = `falling`, caso contrário = `stable`.

## Resposta de Previsão (/v1/predict)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `model.method` | string | Método utilizado (`"auto.arima"`) |
| `model.order` | string | Ordem do modelo ARIMA ajustado |
| `forecast[].period` | string | Período previsto (`"YYYY-MM"`) |
| `forecast[].point` | number | Estimativa pontual |
| `forecast[].lower` | number | Limite inferior do intervalo de confiança |
| `forecast[].upper` | number | Limite superior do intervalo de confiança |

## Códigos de UF

| Sigla | Estado |
|-------|--------|
| AC | Acre |
| AL | Alagoas |
| AM | Amazonas |
| AP | Amapá |
| BA | Bahia |
| CE | Ceará |
| DF | Distrito Federal |
| ES | Espírito Santo |
| GO | Goiás |
| MA | Maranhão |
| MG | Minas Gerais |
| MS | Mato Grosso do Sul |
| MT | Mato Grosso |
| PA | Pará |
| PB | Paraíba |
| PE | Pernambuco |
| PI | Piauí |
| PR | Paraná |
| RJ | Rio de Janeiro |
| RN | Rio Grande do Norte |
| RO | Rondônia |
| RR | Roraima |
| RS | Rio Grande do Sul |
| SC | Santa Catarina |
| SE | Sergipe |
| SP | São Paulo |
| TO | Tocantins |

## Notas sobre Qualidade dos Dados

- **Subnotificação:** Dados oficiais podem não capturar todos os eventos reais.
- **Mudanças metodológicas:** O SINESP pode alterar classificações ao longo do tempo.
- **Cobertura temporal:** Dados disponíveis de 2015 a 2024.
- **Granularidade:** Dados mensais por município. Agregação anual disponível via API.
