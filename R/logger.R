# ============================================================
# SINESP-as-a-Service — Logger simples
# ============================================================

LOG_LEVELS <- c(DEBUG = 1L, INFO = 2L, WARN = 3L, ERROR = 4L)

.current_log_level <- function() {
  lvl <- Sys.getenv("LOG_LEVEL", "INFO")
  if (lvl %in% names(LOG_LEVELS)) return(LOG_LEVELS[[lvl]])
  LOG_LEVELS[["INFO"]]
}

.log_msg <- function(level, ..., .envir = parent.frame()) {
  if (LOG_LEVELS[[level]] < .current_log_level()) return(invisible(NULL))
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  msg <- paste0(...)
  cat(sprintf("[%s] %s | %s\n", ts, level, msg), file = stderr())
}

log_debug <- function(...) .log_msg("DEBUG", ...)
log_info  <- function(...) .log_msg("INFO", ...)
log_warn  <- function(...) .log_msg("WARN", ...)
log_error <- function(...) .log_msg("ERROR", ...)
