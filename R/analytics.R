# ============================================================
# SINESP-as-a-Service — Analytics (Trend + Predict)
# ============================================================

source("R/config.R")
source("R/logger.R")

# ---- Trend ----

#' Calcula tendência (variação 12m e 24m + direção)
#' @param df data.frame filtrado com colunas: year, month, count
#' @return lista com métricas de tendência
calculate_trend <- function(df) {
  if (!"count" %in% names(df) || !"year" %in% names(df)) {
    stop("Dados insuficientes para calcular tendencia (colunas: year, count).")
  }

  # Ordena e agrega por período mensal
  if ("month" %in% names(df)) {
    agg <- stats::aggregate(count ~ year + month, data = df, FUN = sum, na.rm = TRUE)
    agg <- agg[order(agg$year, agg$month), ]
    agg$period <- sprintf("%04d-%02d", agg$year, agg$month)
  } else {
    agg <- stats::aggregate(count ~ year, data = df, FUN = sum, na.rm = TRUE)
    agg <- agg[order(agg$year), ]
    agg$period <- as.character(agg$year)
  }

  n <- nrow(agg)
  if (n < 2) {
    stop("Dados insuficientes para calcular tendencia (menos de 2 periodos).")
  }

  latest_value <- agg$count[n]
  latest_period <- agg$period[n]

  # Variação 12 meses
  change_12m_pct <- NA_real_
  prev_12m_value <- NA_real_
  if (n > 12) {
    prev_12m_value <- agg$count[n - 12]
    if (prev_12m_value != 0) {
      change_12m_pct <- round((latest_value - prev_12m_value) / prev_12m_value * 100, 2)
    }
  }

  # Variação 24 meses
  change_24m_pct <- NA_real_
  prev_24m_value <- NA_real_
  if (n > 24) {
    prev_24m_value <- agg$count[n - 24]
    if (prev_24m_value != 0) {
      change_24m_pct <- round((latest_value - prev_24m_value) / prev_24m_value * 100, 2)
    }
  }

  # Direção
  threshold <- CONFIG$trend_threshold_pct
  direction <- "stable"
  ref_change <- if (!is.na(change_12m_pct)) change_12m_pct else change_24m_pct
  if (!is.na(ref_change)) {
    if (ref_change > threshold)       direction <- "rising"
    else if (ref_change < -threshold) direction <- "falling"
  }

  list(
    direction          = direction,
    change_12m_pct     = change_12m_pct,
    change_24m_pct     = change_24m_pct,
    latest_period      = latest_period,
    latest_value       = latest_value,
    previous_12m_value = prev_12m_value,
    previous_24m_value = prev_24m_value
  )
}

# ---- Predict ----

#' Gera previsão ARIMA automática
#' @param df data.frame filtrado com colunas: year, month (opcional), count
#' @param h Horizonte de previsão
#' @param level Nível de confiança (%)
#' @return lista com modelo e forecast
generate_forecast <- function(df, h = 12L, level = 95L) {
  if (!requireNamespace("forecast", quietly = TRUE)) {
    stop("Pacote 'forecast' nao instalado.")
  }

  if (!"count" %in% names(df) || !"year" %in% names(df)) {
    stop("Dados insuficientes para previsao (colunas: year, count).")
  }

  # Agrega por período
  has_month <- "month" %in% names(df)
  if (has_month) {
    agg <- stats::aggregate(count ~ year + month, data = df, FUN = sum, na.rm = TRUE)
    agg <- agg[order(agg$year, agg$month), ]
    freq <- 12
    start_val <- c(agg$year[1], agg$month[1])
  } else {
    agg <- stats::aggregate(count ~ year, data = df, FUN = sum, na.rm = TRUE)
    agg <- agg[order(agg$year), ]
    freq <- 1
    start_val <- agg$year[1]
  }

  if (nrow(agg) < 4) {
    stop("Serie temporal curta demais para modelagem ARIMA (minimo: 4 periodos).")
  }

  # Cria ts
  ts_data <- stats::ts(agg$count, frequency = freq, start = start_val)

  # Auto ARIMA
  fit <- forecast::auto.arima(ts_data)
  fc  <- forecast::forecast(fit, h = as.integer(h), level = as.numeric(level))

  # Gera labels dos períodos previstos
  if (has_month) {
    last_year  <- agg$year[nrow(agg)]
    last_month <- agg$month[nrow(agg)]
    periods <- character(h)
    for (i in seq_len(h)) {
      last_month <- last_month + 1L
      if (last_month > 12L) {
        last_month <- 1L
        last_year  <- last_year + 1L
      }
      periods[i] <- sprintf("%04d-%02d", last_year, last_month)
    }
  } else {
    last_year <- agg$year[nrow(agg)]
    periods <- as.character(seq(last_year + 1L, length.out = h))
  }

  # Monta resultado
  forecast_data <- data.frame(
    period = periods,
    point  = round(as.numeric(fc$mean), 2),
    lower  = round(as.numeric(fc$lower), 2),
    upper  = round(as.numeric(fc$upper), 2),
    stringsAsFactors = FALSE
  )

  # Descrição do modelo
  model_desc <- tryCatch(
    as.character(fit),
    error = function(e) "ARIMA"
  )

  list(
    model = list(
      method = "auto.arima",
      order  = model_desc
    ),
    forecast = forecast_data
  )
}
