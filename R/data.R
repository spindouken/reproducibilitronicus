#' Load raw eviction data from CSV
#'
#' Reads the eviction CSV from `data/raw/`. This is the entry point of the
#' pipeline — raw court records exported from the targets reference project.
#'
#' The data contains granted eviction cases in Tulsa County (2021–2025) with
#' four columns: `filing_year`, `lat`, `lon`, `geo_accuracy`.
#'
#' @param file_name Character. CSV filename in `data/raw/`. Defaults to the
#'   value in `config/base.yaml`.
#' @return A tibble of raw eviction records.
#' @export
load_eviction_data <- function(file_name = NULL) {
  if (is.null(file_name)) {
    config <- load_config()
    file_name <- config$pipeline$source_file
  }

  path <- here::here("data", "raw", file_name)

  if (!fs::file_exists(path)) {
    cli::cli_abort("Source data not found at {.path {path}}")
  }

  cli::cli_alert_info("Reading raw data from {.path {path}}")

  readr::read_csv(path, show_col_types = FALSE, col_types = readr::cols(
    filing_year = readr::col_integer(),
    lat = readr::col_double(),
    lon = readr::col_double(),
    geo_accuracy = readr::col_double()
  ))
}


#' Convert CSV data to Parquet format
#'
#' Takes a tibble (typically from [load_eviction_data()]) and writes it as a
#' Parquet file. Parquet is a columnar storage format that is:
#' - **Typed:** Column types are embedded in the file (no guessing like CSV)
#' - **Compressed:** Typically 5–10x smaller than CSV
#' - **Queryable:** Can be read by Arrow, DuckDB, Python, Spark without parsing
#' - **Self-describing:** Schema metadata travels with the file
#'
#' @param data A tibble to write.
#' @param output_path Character. Where to write the parquet file.
#' @return The output path (invisibly), for use in targets pipelines.
#' @export
convert_csv_to_parquet <- function(data, output_path) {
  fs::dir_create(fs::path_dir(output_path))

  arrow::write_parquet(data, output_path)

  cli::cli_alert_success("Wrote parquet: {.path {output_path}} ({nrow(data)} rows)")

  invisible(output_path)
}


#' Read eviction data from Parquet
#'
#' Opens a parquet file as an Arrow dataset. Arrow reads parquet lazily —
#' it doesn't load the entire file into memory until you explicitly collect.
#' This is Arrow's primary role: memory-efficient access to typed data.
#'
#' @param path Character. Path to parquet file.
#' @return An Arrow Table (can be converted to tibble with `dplyr::collect()`).
#' @export
read_parquet_evictions <- function(path = NULL) {
  if (is.null(path)) {
    path <- here::here("data", "parquet", "evictions.parquet")
  }

  if (!fs::file_exists(path)) {
    cli::cli_abort("Parquet file not found at {.path {path}}")
  }

  arrow::read_parquet(path)
}


#' Query eviction data with DuckDB
#'
#' DuckDB is an embedded analytical SQL engine. Unlike Arrow (which is a
#' data access layer), DuckDB is a query engine — it has its own optimizer
#' and can run complex SQL including window functions, joins, and aggregations.
#'
#' This function demonstrates DuckDB reading directly from a parquet file.
#' DuckDB and Arrow interoperate natively — you can pass Arrow objects to
#' DuckDB without copying data.
#'
#' **Why both Arrow and DuckDB?**
#' - Arrow: open and describe data, memory-efficient access, cross-language format
#' - DuckDB: run analytical queries, complex SQL, window functions
#' - They overlap for simple operations (filtering, grouping). For those,
#'   either tool works — use whichever is clearer for the task.
#'
#' @param sql Character. SQL query to execute. Use `read_parquet()` function
#'   in the SQL to reference parquet files directly.
#' @param parquet_path Character. Path to parquet file for the query context.
#' @return A tibble of query results.
#' @export
query_evictions_duckdb <- function(sql, parquet_path = NULL) {
  if (is.null(parquet_path)) {
    parquet_path <- here::here("data", "parquet", "evictions.parquet")
  }

  if (!fs::file_exists(parquet_path)) {
    cli::cli_abort("Parquet file not found at {.path {parquet_path}}")
  }

  # DuckDB can read parquet files directly in SQL via read_parquet()
  # No need to load into R first — DuckDB's engine handles it.
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Register the parquet file as a DuckDB view
  # This lets SQL reference it by name instead of using read_parquet() inline
  DBI::dbExecute(con, sprintf(
    "CREATE VIEW evictions AS SELECT * FROM read_parquet('%s')",
    parquet_path
  ))

  result <- DBI::dbGetQuery(con, sql)
  tibble::as_tibble(result)
}
