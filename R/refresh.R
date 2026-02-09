# ============================================================
# SINESP-as-a-Service — Worker de Atualização (Data Pipeline)
# ============================================================
#
# Responsabilidades:
#   1. Baixar/atualizar dados via BrazilCrime::get_sinesp_vde_data()
#   2. Normalizar (encoding, nomes de colunas, tipos)
#   3. Salvar snapshot (CSV comprimido) + meta.json
#   4. Rodar testes de qualidade
#
# Idempotente: rodar 2x gera o mesmo resultado (snapshot baseado em hash).
# ============================================================

source("R/config.R")
source("R/logger.R")

# ---- 1) Coleta de dados ----

#' Baixa dados completos do SINESP VDE via pacote BrazilCrime
#' @return data.frame com dados brutos
fetch_sinesp_data <- function() {
  log_info("Iniciando coleta de dados do SINESP VDE...")

  if (!requireNamespace("BrazilCrime", quietly = TRUE)) {
    stop("Pacote BrazilCrime nao esta instalado. Instale com: install.packages('BrazilCrime')")
  }

  dados <- BrazilCrime::get_sinesp_vde_data(
    state       = "all",
    city        = "all",
    year        = "all",
    category    = "all",
    typology    = "all",
    granularity = "month"
  )

  log_info("Coleta finalizada: ", nrow(dados), " registros, ", ncol(dados), " colunas.")
  dados
}

# ---- 2) Normalização ----

#' Normaliza o dataframe: nomes padronizados, encoding, tipos corretos
#' @param df data.frame bruto do BrazilCrime
#' @return data.frame normalizado
normalize_data <- function(df) {
  log_info("Normalizando dados...")

  # Padroniza nomes de colunas para snake_case em inglês
  col_map <- c(
    "evento"            = "category",
    "tipo_crime"        = "typology",
    "uf"                = "state",
    "municipio"         = "city",
    "ano"               = "year",
    "mes"               = "month",
    "total_vitima"      = "count",
    "regiao"            = "region"
  )

  original_names <- tolower(trimws(names(df)))
  names(df) <- original_names

  # Aplica mapeamento para colunas conhecidas
  for (orig in names(col_map)) {
    if (orig %in% names(df)) {
      names(df)[names(df) == orig] <- col_map[[orig]]
    }
  }

  # Garante tipos corretos
  if ("year" %in% names(df))  df$year  <- as.integer(df$year)
  if ("month" %in% names(df)) df$month <- as.integer(df$month)
  if ("count" %in% names(df)) df$count <- as.numeric(df$count)

  # Trim whitespace em colunas texto
  char_cols <- names(df)[vapply(df, is.character, logical(1))]
  for (col in char_cols) {
    df[[col]] <- trimws(df[[col]])
    # Normaliza encoding para UTF-8
    Encoding(df[[col]]) <- "UTF-8"
  }

  # Remove linhas totalmente NA
  df <- df[rowSums(!is.na(df)) > 0, ]

  log_info("Normalizacao concluida: ", nrow(df), " registros, ", ncol(df), " colunas.")
  df
}

# ---- 3) Snapshot ----

#' Gera ID do snapshot baseado em data + hash do conteúdo
#' @param df data.frame normalizado
#' @return string com snapshot_id
generate_snapshot_id <- function(df) {
  date_part <- format(Sys.Date(), "%Y%m%d")
  # Hash baseado em dimensões + amostra determinística
  hash_input <- paste(
    nrow(df), ncol(df),
    paste(names(df), collapse = ","),
    paste(head(df[[1]], 10), collapse = ","),
    paste(tail(df[[1]], 10), collapse = ","),
    sep = "|"
  )
  hash_val <- substr(digest::digest(hash_input, algo = "md5"), 1, 8)
  paste0(date_part, "_", hash_val)
}

#' Salva snapshot (CSV.gz + meta.json)
#' @param df data.frame normalizado
#' @param base_dir diretório base de snapshots
#' @return lista com snapshot_id e path
save_snapshot <- function(df, base_dir = CONFIG$snapshot_dir) {
  snapshot_id <- generate_snapshot_id(df)
  snap_dir <- file.path(base_dir, snapshot_id)

  # Idempotência: se já existe com mesmo ID, não reescreve
  if (dir.exists(snap_dir)) {
    log_info("Snapshot ", snapshot_id, " ja existe. Pulando escrita (idempotente).")
    return(list(snapshot_id = snapshot_id, path = snap_dir, skipped = TRUE))
  }

  dir.create(snap_dir, recursive = TRUE, showWarnings = FALSE)

  # Salva dados como CSV comprimido
  data_path <- file.path(snap_dir, "facts.csv.gz")
  con <- gzfile(data_path, "wt")
  utils::write.csv(df, con, row.names = FALSE)
  close(con)

  # Gera metadados
  meta <- list(
    snapshot_id  = snapshot_id,
    last_refresh = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    row_count    = nrow(df),
    col_count    = ncol(df),
    columns      = names(df),
    coverage     = list(
      states     = sort(unique(df$state)),
      years      = sort(unique(df$year)),
      categories = sort(unique(df$category))
    ),
    source       = CONFIG$source_label,
    source_url   = CONFIG$source_url,
    notes        = paste(
      "Dados extraidos automaticamente via pacote BrazilCrime.",
      "Limitacoes conhecidas: subnotificacao, mudancas metodologicas."
    ),
    checksum     = digest::digest(df, algo = "md5")
  )

  meta_path <- file.path(snap_dir, "meta.json")
  jsonlite::write_json(meta, meta_path, pretty = TRUE, auto_unbox = TRUE)

  log_info("Snapshot salvo: ", snapshot_id, " (", nrow(df), " registros)")
  list(snapshot_id = snapshot_id, path = snap_dir, skipped = FALSE)
}

# ---- 4) Testes de qualidade ----

#' Executa testes de qualidade no dataframe
#' @param df data.frame normalizado
#' @return lista com resultados dos testes (pass/fail + detalhes)
run_quality_checks <- function(df) {
  log_info("Executando testes de qualidade...")
  results <- list()

  # Test 1: Schema — colunas esperadas
  expected_cols <- c("state", "year", "category", "count")
  missing_cols <- setdiff(expected_cols, names(df))
  results$schema <- list(
    test    = "schema_columns",
    pass    = length(missing_cols) == 0,
    details = if (length(missing_cols) > 0)
      paste("Colunas ausentes:", paste(missing_cols, collapse = ", "))
    else
      "Todas as colunas esperadas presentes."
  )

  # Test 2: Ranges — valores não negativos
  if ("count" %in% names(df)) {
    neg_count <- sum(df$count < 0, na.rm = TRUE)
    results$non_negative <- list(
      test    = "count_non_negative",
      pass    = neg_count == 0,
      details = paste("Valores negativos em 'count':", neg_count)
    )
  }

  # Test 3: Datas válidas
  if ("year" %in% names(df)) {
    invalid_years <- sum(df$year < 2015 | df$year > as.integer(format(Sys.Date(), "%Y")), na.rm = TRUE)
    results$valid_years <- list(
      test    = "year_range",
      pass    = invalid_years == 0,
      details = paste("Anos fora de 2015-atual:", invalid_years)
    )
  }

  if ("month" %in% names(df)) {
    invalid_months <- sum(df$month < 1 | df$month > 12, na.rm = TRUE)
    results$valid_months <- list(
      test    = "month_range",
      pass    = invalid_months == 0,
      details = paste("Meses invalidos:", invalid_months)
    )
  }

  # Test 4: Sem dataframe vazio
  results$not_empty <- list(
    test    = "data_not_empty",
    pass    = nrow(df) > 0,
    details = paste("Total de registros:", nrow(df))
  )

  # Test 5: Consistência — ao menos 1 UF presente
  if ("state" %in% names(df)) {
    n_states <- length(unique(df$state))
    results$state_coverage <- list(
      test    = "state_coverage",
      pass    = n_states >= 1,
      details = paste("UFs distintas:", n_states)
    )
  }

  all_pass <- all(vapply(results, function(r) r$pass, logical(1)))
  log_info("Testes de qualidade: ", if (all_pass) "TODOS PASSARAM" else "FALHAS DETECTADAS")

  list(all_pass = all_pass, tests = results)
}

# ---- 5) Orquestrador principal ----

#' Executa o pipeline completo de refresh
#' @param base_dir diretório base para snapshots
#' @return lista com resultado do refresh
run_refresh <- function(base_dir = CONFIG$snapshot_dir) {
  log_info("=== INICIO DO REFRESH ===")
  start_time <- Sys.time()

  tryCatch({
    # Passo 1: Coleta
    raw_data <- fetch_sinesp_data()

    # Passo 2: Normalização
    clean_data <- normalize_data(raw_data)

    # Passo 3: Qualidade
    quality <- run_quality_checks(clean_data)
    if (!quality$all_pass) {
      log_warn("Testes de qualidade com falhas. Verifique detalhes.")
      # Continua mesmo com warnings (não interrompe)
    }

    # Passo 4: Snapshot
    snap <- save_snapshot(clean_data, base_dir)

    # Salva resultado dos testes junto ao snapshot
    quality_path <- file.path(snap$path, "quality.json")
    if (!file.exists(quality_path)) {
      jsonlite::write_json(quality, quality_path, pretty = TRUE, auto_unbox = TRUE)
    }

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    log_info("=== REFRESH CONCLUIDO em ", round(elapsed, 1), "s ===")

    list(
      success     = TRUE,
      snapshot_id = snap$snapshot_id,
      path        = snap$path,
      skipped     = snap$skipped,
      quality     = quality,
      elapsed_sec = elapsed
    )

  }, error = function(e) {
    log_error("Falha no refresh: ", conditionMessage(e))
    list(success = FALSE, error = conditionMessage(e))
  })
}

# ---- Execução direta (via Rscript refresh.R) ----
if (sys.nframe() == 0) {
  result <- run_refresh()
  if (!result$success) {
    quit(status = 1)
  }
}
