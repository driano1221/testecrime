# ============================================================
# SINESP-as-a-Service — Dockerfile
# ============================================================
# Build:  docker build -t sinesp-api .
# Run:    docker run -p 8000:8000 sinesp-api
# ============================================================

FROM rocker/r-ver:4.3.2

LABEL maintainer="SINESP-as-a-Service"
LABEL description="API REST para dados de segurança pública do Brasil (SINESP VDE)"

# Dependências de sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Instala pacotes R
RUN R -e "install.packages(c( \
  'plumber', \
  'jsonlite', \
  'digest', \
  'dplyr', \
  'forecast', \
  'ggplot2', \
  'BrazilCrime' \
), repos = 'https://cloud.r-project.org')"

# Diretório de trabalho
WORKDIR /app

# Copia código da aplicação
COPY R/ R/
COPY openapi.yaml .
COPY .env.example .env

# Cria diretório de snapshots
RUN mkdir -p data/snapshots

# Expõe porta da API
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:8000/status || exit 1

# Comando padrão: inicia a API
CMD ["Rscript", "R/run_api.R"]
