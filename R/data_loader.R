# ============================================================
# SINESP-as-a-Service — Data Loader (leitura de snapshots)
# ============================================================
# Usado pela API para carregar dados do snapshot mais recente.
# ============================================================

if (!exists("CONFIG"))     try(source("R/config.R"), silent = TRUE)
if (!exists("LOG_LEVELS")) try(source("R/logger.R"), silent = TRUE)

# Cache em memória (evita reler disco a cada request)
.data_cache <- new.env(parent = emptyenv())

#' Carrega (ou retorna do cache) o snapshot mais recente
#' @param force_reload Força releitura do disco
#' @return lista com $data (data.frame) e $meta (lista)
load_snapshot <- function(force_reload = FALSE) {
  snap_dir <- latest_snapshot_dir()

  if (is.null(snap_dir)) {
    log_warn("Nenhum snapshot encontrado em ", CONFIG$snapshot_dir)
    return(NULL)
  }

  snap_id <- basename(snap_dir)

  # Retorna cache se já carregado e não mudou

  if (!force_reload &&
      exists("snapshot_id", envir = .data_cache) &&
      identical(.data_cache$snapshot_id, snap_id)) {
    return(list(data = .data_cache$data, meta = .data_cache$meta))
  }

  log_info("Carregando snapshot: ", snap_id)

  # Lê dados
  data_path <- file.path(snap_dir, "facts.csv.gz")
  if (!file.exists(data_path)) {
    log_error("Arquivo de dados nao encontrado: ", data_path)
    return(NULL)
  }

  df <- utils::read.csv(gzfile(data_path), stringsAsFactors = FALSE)

  # Lê metadados
  meta <- read_snapshot_meta()

  # Atualiza cache
  .data_cache$data        <- df
  .data_cache$meta        <- meta
  .data_cache$snapshot_id <- snap_id

  log_info("Snapshot carregado: ", nrow(df), " registros")
  list(data = df, meta = meta)
}

#' Filtra dados conforme parâmetros da API
#' @param df data.frame do snapshot
#' @param state UF(s) ou "all"
#' @param city Município(s) ou "all"
#' @param year Ano(s) ou "all"
#' @param category Categoria(s) ou "all"
#' @param typology Tipologia(s) ou "all"
#' @param granularity "month" ou "year"
#' @return data.frame filtrado
filter_data <- function(df, state = "all", city = "all", year = "all",
                        category = "all", typology = "all",
                        granularity = "month") {

  # Parse de parâmetros (podem vir como string separada por vírgula)
  parse_param <- function(val) {
    if (is.null(val) || length(val) == 0 || identical(tolower(val), "all")) {
      return(NULL)
    }
    trimws(unlist(strsplit(as.character(val), ",")))
  }

  states     <- parse_param(state)
  cities     <- parse_param(city)
  years      <- parse_param(year)
  categories <- parse_param(category)
  typologies <- parse_param(typology)

  # Aplica filtros
  if (!is.null(states) && "state" %in% names(df)) {
    df <- df[toupper(df$state) %in% toupper(states), ]
  }
  if (!is.null(cities) && "city" %in% names(df)) {
    df <- df[toupper(df$city) %in% toupper(cities), ]
  }
  if (!is.null(years) && "year" %in% names(df)) {
    df <- df[df$year %in% as.integer(years), ]
  }
  if (!is.null(categories) && "category" %in% names(df)) {
    df <- df[toupper(df$category) %in% toupper(categories), ]
  }
  if (!is.null(typologies) && "typology" %in% names(df)) {
    df <- df[toupper(df$typology) %in% toupper(typologies), ]
  }

  # Agregação por granularidade
  if (identical(granularity, "year") && "month" %in% names(df) && "count" %in% names(df)) {
    group_cols <- intersect(c("state", "city", "year", "category", "typology"), names(df))
    group_cols <- setdiff(group_cols, "month")
    df <- stats::aggregate(
      stats::as.formula(paste("count ~", paste(group_cols, collapse = " + "))),
      data = df, FUN = sum, na.rm = TRUE
    )
  }

  df
}

#' Pagina o data.frame
#' @param df data.frame
#' @param page número da página
#' @param per_page registros por página
#' @return lista com $data, $pagination
paginate <- function(df, page = 1L, per_page = 100L) {
  page     <- max(1L, as.integer(page))
  per_page <- min(CONFIG$max_per_page, max(1L, as.integer(per_page)))

  total <- nrow(df)
  total_pages <- ceiling(total / per_page)
  start <- (page - 1L) * per_page + 1L
  end   <- min(page * per_page, total)

  if (start > total) {
    page_data <- df[0, ]
  } else {
    page_data <- df[start:end, ]
  }

  list(
    data = page_data,
    pagination = list(
      page          = page,
      per_page      = per_page,
      total_records = total,
      total_pages   = total_pages
    )
  )
}
