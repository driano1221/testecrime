# ============================================================
# Testes — Quality Checks (run_quality_checks)
# ============================================================

library(testthat)

source("../R/config.R")
source("../R/logger.R")
source("../R/refresh.R")

# ---- Dados de teste ----

good_df <- data.frame(
  state    = c("SP", "RJ"),
  city     = c("Sao Paulo", "Rio de Janeiro"),
  year     = c(2020L, 2021L),
  month    = c(1L, 6L),
  category = c("Homicidio", "Roubo"),
  typology = c("Doloso", "Furto"),
  count    = c(100, 200),
  stringsAsFactors = FALSE
)

# ---- Testes run_quality_checks ----

test_that("quality checks passam com dados bons", {
  result <- run_quality_checks(good_df)
  expect_true(result$all_pass)
})

test_that("quality checks detectam colunas ausentes", {
  bad_df <- good_df[, c("state", "year")]
  result <- run_quality_checks(bad_df)
  # "count" e "category" estão ausentes
  expect_false(result$tests$schema$pass)
})

test_that("quality checks detectam valores negativos", {
  neg_df <- good_df
  neg_df$count[1] <- -50
  result <- run_quality_checks(neg_df)
  expect_false(result$tests$non_negative$pass)
})

test_that("quality checks detectam anos invalidos", {
  bad_year_df <- good_df
  bad_year_df$year[1] <- 1999L
  result <- run_quality_checks(bad_year_df)
  expect_false(result$tests$valid_years$pass)
})

test_that("quality checks detectam meses invalidos", {
  bad_month_df <- good_df
  bad_month_df$month[1] <- 13L
  result <- run_quality_checks(bad_month_df)
  expect_false(result$tests$valid_months$pass)
})

test_that("quality checks detectam dataframe vazio", {
  empty_df <- good_df[0, ]
  result <- run_quality_checks(empty_df)
  expect_false(result$tests$not_empty$pass)
})

cat("\n=== Todos os testes de quality passaram! ===\n")
