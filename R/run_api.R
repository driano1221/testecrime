# ============================================================
# SINESP-as-a-Service — Inicia o servidor Plumber
# ============================================================
# Uso: Rscript R/run_api.R
# ============================================================

source("R/config.R")
source("R/logger.R")

log_info("Iniciando SINESP-as-a-Service API...")
log_info("Host: ", CONFIG$api_host, " | Port: ", CONFIG$api_port)
log_info("Rate limit: ", CONFIG$rate_limit_rpm, " req/min")
log_info("Snapshot dir: ", CONFIG$snapshot_dir)

pr <- plumber::plumb("R/api.R")

# Habilita CORS
pr$registerHooks(
  list(
    preroute = function(data, req, res) {
      res$setHeader("Access-Control-Allow-Origin", "*")
      res$setHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
      res$setHeader("Access-Control-Allow-Headers", "Content-Type")
    }
  )
)

# Habilita Swagger UI
pr$run(
  host    = CONFIG$api_host,
  port    = CONFIG$api_port,
  swagger = TRUE
)
