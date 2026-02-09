# ============================================================
# Testes — Analytics (calculate_trend, generate_forecast)
# ============================================================

library(testthat)

source("R/config.R")
source("R/logger.R")
source("R/analytics.R")

# ---- Dados de teste — série mensal 3 anos ----

set.seed(42)
months_seq <- expand.grid(month = 1:12, year = 2020:2022)
months_seq <- months_seq[order(months_seq$year, months_seq$month), ]

trend_df <- data.frame(
  state    = "SP",
  city     = "Sao Paulo",
  year     = months_seq$year,
  month    = months_seq$month,
  category = "Homicidio",
  typology = "Doloso",
  count    = round(100 + seq_len(nrow(months_seq)) * 2 + rnorm(nrow(months_seq), 0, 5)),
  stringsAsFactors = FALSE
)

# ---- Testes calculate_trend ----

test_that("calculate_trend retorna estrutura correta", {
  result <- calculate_trend(trend_df)
  expect_true(is.list(result))
  expect_true("direction" %in% names(result))
  expect_true("change_12m_pct" %in% names(result))
  expect_true("change_24m_pct" %in% names(result))
  expect_true("latest_period" %in% names(result))
  expect_true("latest_value" %in% names(result))
})

test_that("calculate_trend retorna direcao valida", {
  result <- calculate_trend(trend_df)
  expect_true(result$direction %in% c("rising", "falling", "stable"))
})

test_that("calculate_trend detecta tendencia de alta", {
  # Dados com tendência clara de alta
  rising_df <- data.frame(
    year  = rep(2020:2022, each = 12),
    month = rep(1:12, 3),
    count = c(rep(100, 12), rep(200, 12), rep(400, 12))
  )
  result <- calculate_trend(rising_df)
  expect_equal(result$direction, "rising")
})

test_that("calculate_trend detecta tendencia de queda", {
  falling_df <- data.frame(
    year  = rep(2020:2022, each = 12),
    month = rep(1:12, 3),
    count = c(rep(400, 12), rep(200, 12), rep(100, 12))
  )
  result <- calculate_trend(falling_df)
  expect_equal(result$direction, "falling")
})

test_that("calculate_trend erro com dados insuficientes", {
  tiny_df <- data.frame(year = 2020, month = 1, count = 100)
  expect_error(calculate_trend(tiny_df), "insuficientes")
})

# ---- Testes generate_forecast ----

test_that("generate_forecast retorna estrutura correta", {
  skip_if_not_installed("forecast")
  result <- generate_forecast(trend_df, h = 6, level = 95)
  expect_true(is.list(result))
  expect_true("model" %in% names(result))
  expect_true("forecast" %in% names(result))
  expect_equal(nrow(result$forecast), 6)
})

test_that("generate_forecast respeita horizonte h", {
  skip_if_not_installed("forecast")
  result <- generate_forecast(trend_df, h = 3, level = 95)
  expect_equal(nrow(result$forecast), 3)
})

test_that("generate_forecast colunas do forecast corretas", {
  skip_if_not_installed("forecast")
  result <- generate_forecast(trend_df, h = 6, level = 95)
  expect_true(all(c("period", "point", "lower", "upper") %in% names(result$forecast)))
})

test_that("generate_forecast erro com serie curta", {
  skip_if_not_installed("forecast")
  tiny <- data.frame(year = 2020:2021, count = c(100, 200))
  expect_error(generate_forecast(tiny, h = 3), "curta demais")
})

cat("\n=== Todos os testes de analytics passaram! ===\n")
