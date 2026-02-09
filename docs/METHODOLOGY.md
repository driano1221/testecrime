# Metodologia e Ética

## Fonte dos Dados

Este serviço utiliza exclusivamente dados públicos oficiais do **Sistema Nacional de Informações de Segurança Pública (SINESP)**, disponibilizados pelo **Ministério da Justiça e Segurança Pública** do Brasil.

- **Portal oficial:** https://www.gov.br/mj/pt-br/assuntos/sua-seguranca/seguranca-publica/sinesp-1
- **Extração:** Realizada via pacote R [`BrazilCrime`](https://CRAN.R-project.org/package=BrazilCrime) (CRAN)
- **Cobertura:** 2015–2024, todos os estados e municípios brasileiros

## Pipeline de Dados

### Coleta
Os dados são coletados semanalmente via cron automatizado. O pipeline é **idempotente**: executar múltiplas vezes produz o mesmo resultado.

### Normalização
- Padronização de nomes de colunas para inglês (snake_case)
- Normalização de encoding (UTF-8)
- Tipagem correta (integer para ano/mês, numeric para contagens)
- Remoção de linhas completamente vazias

### Testes de Qualidade
Cada refresh executa automaticamente:

1. **Schema:** Verifica presença de colunas obrigatórias
2. **Ranges:** Garante valores não-negativos e datas válidas
3. **Consistência:** Valida meses (1–12), anos (2015–atual)
4. **Sanity check:** Verifica que o dataset não está vazio
5. **Cobertura:** Confirma presença de ao menos 1 UF

### Versionamento (Snapshots)
Cada atualização gera um `snapshot_id` único (`YYYYMMDD_<hash>`), permitindo:
- **Reprodutibilidade:** Qualquer resultado pode ser rastreado ao snapshot exato
- **Auditoria:** Todas as respostas da API incluem `snapshot_id` e `last_refresh`
- **Rollback:** Snapshots anteriores são preservados

## Análises

### Tendência (`/v1/trend`)
- Calcula variação percentual comparando o período mais recente com 12 e 24 meses anteriores
- Classifica como `rising` (>5%), `falling` (<-5%) ou `stable` (entre -5% e 5%)
- **Não implica causalidade** — apenas descreve a direção da série histórica

### Previsão (`/v1/predict`)
- Utiliza `auto.arima` do pacote `forecast` (Hyndman & Khandakar, 2008)
- Ajusta automaticamente a ordem (p,d,q) e sazonalidade
- Retorna estimativa pontual + intervalo de confiança configurável
- **É uma extrapolação estatística**, não uma predição determinista

## Princípios Éticos

### Transparência
- Toda resposta inclui `source`, `last_refresh`, `snapshot_id` e `coverage`
- Limitações dos dados são documentadas e comunicadas via `notes`
- O código é open source e auditável

### O que este serviço NÃO faz
- **Não determina "risco"** de áreas ou indivíduos
- **Não estabelece causalidade** entre variáveis
- **Não substitui** análise qualitativa de segurança pública
- **Não deve ser usado** para discriminação territorial ou social

### Limitações Conhecidas
- **Subnotificação:** Eventos reais podem ser maiores que os registrados
- **Mudanças metodológicas:** Classificações podem mudar entre anos
- **Defasagem:** Dados mais recentes podem ter cobertura parcial
- **Agregação:** Perda de nuance ao agregar por município ou estado

### Uso Responsável
Recomendamos que consumidores deste serviço:
1. Citem a fonte original (SINESP/SENASP)
2. Comuniquem as limitações ao apresentar os dados
3. Evitem linguagem causal ("por causa de...")
4. Considerem o contexto social e metodológico
5. Não usem os dados para estigmatizar regiões ou populações

## Referências

- SINESP — Ministério da Justiça e Segurança Pública. https://www.gov.br/mj/pt-br/assuntos/sua-seguranca/seguranca-publica/sinesp-1
- Hyndman, R.J. & Khandakar, Y. (2008). Automatic time series forecasting: the forecast package for R. *Journal of Statistical Software*, 27(3).
- Pacote BrazilCrime (CRAN). https://CRAN.R-project.org/package=BrazilCrime
