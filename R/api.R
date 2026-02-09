# ============================================================
# SINESP-as-a-Service — API Plumber
# ============================================================
# Endpoints:
#   GET /status         — Status e metadados do serviço
#   GET /v1/data        — Consulta dados criminais
#   GET /v1/trend       — Tendência e variação temporal
#   GET /v1/predict     — Previsão ARIMA automática
# ============================================================

library(plumber)

source("R/config.R")
source("R/logger.R")
source("R/data_loader.R")
source("R/analytics.R")

# ---- Rate Limiter (in-memory, por IP) ----

.rate_store <- new.env(parent = emptyenv())

#' Verifica rate limit por IP
#' @param req Plumber request
#' @return TRUE se dentro do limite, FALSE se excedeu
check_rate_limit <- function(req) {
  ip <- req$REMOTE_ADDR %||% "unknown"
  now <- as.numeric(Sys.time())
  window <- 60  # 1 minuto

  key <- paste0("rl_", ip)
  if (!exists(key, envir = .rate_store)) {
    assign(key, list(timestamps = now), envir = .rate_store)
    return(TRUE)
  }

  entry <- get(key, envir = .rate_store)
  # Remove timestamps fora da janela
  entry$timestamps <- entry$timestamps[entry$timestamps > (now - window)]
  entry$timestamps <- c(entry$timestamps, now)
  assign(key, entry, envir = .rate_store)

  length(entry$timestamps) <= CONFIG$rate_limit_rpm
}

# ---- Helpers de resposta ----

make_meta <- function(snapshot) {
  list(
    snapshot_id  = snapshot$meta$snapshot_id,
    last_refresh = snapshot$meta$last_refresh,
    source       = CONFIG$source_label,
    coverage     = paste(
      length(snapshot$meta$coverage$states), "UFs,",
      length(snapshot$meta$coverage$years), "anos"
    )
  )
}

make_error <- function(res, status, error_type, message) {
  res$status <- status
  list(error = error_type, message = message, status = status)
}

# ---- Null-coalescing operator ----
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a

# ============================================================
# PLUMBER ROUTER
# ============================================================

#* @apiTitle SINESP-as-a-Service API
#* @apiDescription API REST para dados de segurança pública do Brasil (SINESP VDE, 2015-2024).
#* @apiVersion 1.0.0
#* @apiContact list(name = "SINESP-as-a-Service")
#* @apiLicense list(name = "MIT", url = "https://opensource.org/licenses/MIT")

# ---- Filtro global: logging + rate limit ----

#* @filter logger
function(req, res) {
  start <- Sys.time()
  log_info(req$REQUEST_METHOD, " ", req$PATH_INFO,
           " | IP=", req$REMOTE_ADDR %||% "?")

  # Rate limit
  if (!check_rate_limit(req)) {
    log_warn("Rate limit excedido: ", req$REMOTE_ADDR)
    res$status <- 429L
    return(list(
      error   = "rate_limit_exceeded",
      message = paste("Limite de", CONFIG$rate_limit_rpm, "requisicoes/minuto excedido."),
      status  = 429L
    ))
  }

  plumber::forward()
}

# ---- GET /status ----

#* Status e metadados do servico
#* @get /status
#* @serializer json
function(req, res) {
  snapshot <- load_snapshot()

  if (is.null(snapshot)) {
    return(make_error(res, 503L, "service_unavailable",
                      "Nenhum snapshot disponivel. Execute o refresh primeiro."))
  }

  list(
    status      = "ok",
    snapshot_id = snapshot$meta$snapshot_id,
    last_refresh = snapshot$meta$last_refresh,
    coverage    = snapshot$meta$coverage,
    row_count   = snapshot$meta$row_count,
    source      = CONFIG$source_label,
    source_url  = CONFIG$source_url,
    notes       = snapshot$meta$notes
  )
}

# ---- GET /v1/data ----

#* Consulta dados criminais
#* @get /v1/data
#* @param state:character UF (ex: SP, RJ). Default: all
#* @param city:character Municipio. Default: all
#* @param year:character Ano(s). Default: all
#* @param category:character Categoria do crime. Default: all
#* @param typology:character Tipologia do crime. Default: all
#* @param granularity:character month ou year. Default: month
#* @param page:int Pagina. Default: 1
#* @param per_page:int Registros por pagina. Default: 100
#* @serializer json
function(req, res,
         state = "all", city = "all", year = "all",
         category = "all", typology = "all",
         granularity = "month",
         page = 1, per_page = 100) {

  snapshot <- load_snapshot()
  if (is.null(snapshot)) {
    return(make_error(res, 503L, "service_unavailable",
                      "Nenhum snapshot disponivel."))
  }

  # Validação de granularity
  if (!granularity %in% c("month", "year")) {
    return(make_error(res, 400L, "bad_request",
                      "Parametro 'granularity' deve ser 'month' ou 'year'."))
  }

  # Validação de year (se fornecido)
  if (!identical(tolower(year), "all")) {
    years_parsed <- trimws(unlist(strsplit(as.character(year), ",")))
    if (any(is.na(suppressWarnings(as.integer(years_parsed))))) {
      return(make_error(res, 400L, "bad_request",
                        "Parametro 'year' deve ser numerico (ex: 2020 ou 2020,2021)."))
    }
  }

  # Filtra
  filtered <- filter_data(
    snapshot$data,
    state = state, city = city, year = year,
    category = category, typology = typology,
    granularity = granularity
  )

  if (nrow(filtered) == 0) {
    return(make_error(res, 404L, "not_found",
                      "Nenhum registro encontrado para os filtros informados."))
  }

  # Pagina
  result <- paginate(filtered, page = as.integer(page), per_page = as.integer(per_page))

  list(
    meta       = make_meta(snapshot),
    pagination = result$pagination,
    data       = result$data
  )
}

# ---- GET /v1/trend ----

#* Tendencia e variacao temporal
#* @get /v1/trend
#* @param state:character UF. Default: all
#* @param city:character Municipio. Default: all
#* @param category:character Categoria. Default: all
#* @param typology:character Tipologia. Default: all
#* @serializer json
function(req, res,
         state = "all", city = "all",
         category = "all", typology = "all") {

  snapshot <- load_snapshot()
  if (is.null(snapshot)) {
    return(make_error(res, 503L, "service_unavailable",
                      "Nenhum snapshot disponivel."))
  }

  filtered <- filter_data(
    snapshot$data,
    state = state, city = city,
    category = category, typology = typology
  )

  if (nrow(filtered) == 0) {
    return(make_error(res, 404L, "not_found",
                      "Nenhum registro encontrado para os filtros informados."))
  }

  tryCatch({
    trend <- calculate_trend(filtered)
    list(
      meta  = make_meta(snapshot),
      trend = trend
    )
  }, error = function(e) {
    make_error(res, 400L, "bad_request", conditionMessage(e))
  })
}

# ---- GET /v1/predict ----

#* Previsao ARIMA automatica
#* @get /v1/predict
#* @param state:character UF. Default: all
#* @param city:character Municipio. Default: all
#* @param category:character Categoria. Default: all
#* @param typology:character Tipologia. Default: all
#* @param h:int Horizonte de previsao. Default: 12
#* @param level:int Nivel de confianca (%). Default: 95
#* @serializer json
function(req, res,
         state = "all", city = "all",
         category = "all", typology = "all",
         h = 12, level = 95) {

  snapshot <- load_snapshot()
  if (is.null(snapshot)) {
    return(make_error(res, 503L, "service_unavailable",
                      "Nenhum snapshot disponivel."))
  }

  # Validações
  h <- as.integer(h)
  level <- as.integer(level)

  if (is.na(h) || h < 1 || h > CONFIG$max_forecast_horizon) {
    return(make_error(res, 400L, "bad_request",
                      paste0("Parametro 'h' deve ser entre 1 e ", CONFIG$max_forecast_horizon, ".")))
  }
  if (is.na(level) || level < 50 || level > 99) {
    return(make_error(res, 400L, "bad_request",
                      "Parametro 'level' deve ser entre 50 e 99."))
  }

  filtered <- filter_data(
    snapshot$data,
    state = state, city = city,
    category = category, typology = typology
  )

  if (nrow(filtered) == 0) {
    return(make_error(res, 404L, "not_found",
                      "Nenhum registro encontrado para os filtros informados."))
  }

  tryCatch({
    prediction <- generate_forecast(filtered, h = h, level = level)
    list(
      meta     = make_meta(snapshot),
      model    = prediction$model,
      forecast = prediction$forecast
    )
  }, error = function(e) {
    make_error(res, 400L, "bad_request", conditionMessage(e))
  })
}
