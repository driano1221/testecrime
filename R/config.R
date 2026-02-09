# ============================================================
# SINESP-as-a-Service — Configuração central
# ============================================================

# Carrega variáveis de ambiente (.env) se disponível
if (file.exists(".env")) {
  lines <- readLines(".env", warn = FALSE)
  lines <- lines[!grepl("^\\s*#", lines) & nchar(trimws(lines)) > 0]
  for (line in lines) {
    parts <- strsplit(line, "=", fixed = TRUE)[[1]]
    if (length(parts) >= 2) {
      key <- trimws(parts[1])
      val <- trimws(paste(parts[-1], collapse = "="))
      Sys.setenv(val)  # Workaround: usamos do.call abaixo
      do.call(Sys.setenv, setNames(list(val), key))
    }
  }
}

# ---- Constantes do projeto ----

CONFIG <- list(
  api_host      = Sys.getenv("API_HOST", "0.0.0.0"),
  api_port      = as.integer(Sys.getenv("API_PORT", "8000")),
  rate_limit_rpm = as.integer(Sys.getenv("RATE_LIMIT_RPM", "60")),
  snapshot_dir  = Sys.getenv("SNAPSHOT_DIR", "data/snapshots"),
  log_level     = Sys.getenv("LOG_LEVEL", "INFO"),

  # Metadados fixos
  source_label  = "SINESP VDE \u2014 Minist\u00e9rio da Justi\u00e7a e Seguran\u00e7a P\u00fablica",
  source_url    = "https://www.gov.br/mj/pt-br/assuntos/sua-seguranca/seguranca-publica/sinesp-1",
  api_version   = "v1",

  # Limites de paginação
  default_page     = 1L,
  default_per_page = 100L,
  max_per_page     = 1000L,

  # Previsão
  max_forecast_horizon = 60L,

  # Trend
  trend_threshold_pct = 5  # variação < 5% = "stable"
)

# ---- Helpers ----

#' Resolve o diretório do snapshot mais recente
latest_snapshot_dir <- function(base_dir = CONFIG$snapshot_dir) {
  dirs <- list.dirs(base_dir, recursive = FALSE, full.names = TRUE)
  if (length(dirs) == 0) return(NULL)
  # Ordena por nome (formato YYYYMMDD_hash) — mais recente por último

  dirs <- sort(dirs, decreasing = TRUE)
  dirs[1]
}

#' Lê meta.json do snapshot mais recente
read_snapshot_meta <- function(base_dir = CONFIG$snapshot_dir) {
  snap_dir <- latest_snapshot_dir(base_dir)
  if (is.null(snap_dir)) return(NULL)
  meta_path <- file.path(snap_dir, "meta.json")
  if (!file.exists(meta_path)) return(NULL)
  jsonlite::fromJSON(meta_path, simplifyVector = TRUE)
}
