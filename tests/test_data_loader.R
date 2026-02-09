# ============================================================
# Testes — Data Loader (filter_data, paginate)
# ============================================================

library(testthat)

# Source sem iniciar API
source("R/config.R")
source("R/logger.R")
source("R/data_loader.R")

# ---- Dados de teste ----

sample_df <- data.frame(
  state    = c("SP", "SP", "RJ", "RJ", "MG", "MG"),
  city     = c("Sao Paulo", "Campinas", "Rio de Janeiro", "Niteroi", "Belo Horizonte", "Uberlandia"),
  year     = c(2020L, 2020L, 2021L, 2021L, 2022L, 2022L),
  month    = c(1L, 2L, 3L, 4L, 5L, 6L),
  category = c("Homicidio", "Roubo", "Homicidio", "Roubo", "Homicidio", "Roubo"),
  typology = c("Doloso", "Furto de veiculo", "Doloso", "Furto de veiculo", "Doloso", "Furto de veiculo"),
  count    = c(100, 200, 150, 250, 80, 180),
  stringsAsFactors = FALSE
)

# ---- Testes filter_data ----

test_that("filter_data retorna tudo quando filtros sao 'all'", {
  result <- filter_data(sample_df)
  expect_equal(nrow(result), nrow(sample_df))
})

test_that("filter_data filtra por UF corretamente", {
  result <- filter_data(sample_df, state = "SP")
  expect_equal(nrow(result), 2)
  expect_true(all(result$state == "SP"))
})

test_that("filter_data filtra por multiplas UFs (virgula)", {
  result <- filter_data(sample_df, state = "SP,RJ")
  expect_equal(nrow(result), 4)
  expect_true(all(result$state %in% c("SP", "RJ")))
})

test_that("filter_data filtra por ano", {
  result <- filter_data(sample_df, year = "2021")
  expect_equal(nrow(result), 2)
  expect_true(all(result$year == 2021L))
})

test_that("filter_data filtra por categoria", {
  result <- filter_data(sample_df, category = "Homicidio")
  expect_equal(nrow(result), 3)
})

test_that("filter_data case insensitive para UF", {
  result <- filter_data(sample_df, state = "sp")
  expect_equal(nrow(result), 2)
})

test_that("filter_data com granularity year agrega valores", {
  result <- filter_data(sample_df, state = "SP", granularity = "year")
  expect_equal(nrow(result), 1)
  expect_equal(result$count, 300)
})

test_that("filter_data retorna 0 linhas para filtro sem match", {
  result <- filter_data(sample_df, state = "BA")
  expect_equal(nrow(result), 0)
})

# ---- Testes paginate ----

test_that("paginate retorna pagina correta", {
  result <- paginate(sample_df, page = 1, per_page = 2)
  expect_equal(nrow(result$data), 2)
  expect_equal(result$pagination$page, 1)
  expect_equal(result$pagination$per_page, 2)
  expect_equal(result$pagination$total_records, 6)
  expect_equal(result$pagination$total_pages, 3)
})

test_that("paginate segunda pagina", {
  result <- paginate(sample_df, page = 2, per_page = 2)
  expect_equal(nrow(result$data), 2)
})

test_that("paginate ultima pagina parcial", {
  result <- paginate(sample_df, page = 3, per_page = 2)
  expect_equal(nrow(result$data), 2)
})

test_that("paginate pagina alem do total retorna vazio", {
  result <- paginate(sample_df, page = 100, per_page = 2)
  expect_equal(nrow(result$data), 0)
})

test_that("paginate respeita max_per_page", {
  result <- paginate(sample_df, page = 1, per_page = 99999)
  expect_true(result$pagination$per_page <= CONFIG$max_per_page)
})

cat("\n=== Todos os testes de data_loader passaram! ===\n")
