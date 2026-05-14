#' Summarize evictions by year
#'
#' Counts granted evictions per filing year and computes year-over-year change.
#' This is a targets pipeline step that produces summarized data consumed
#' by the Eviction Trends report.
#'
#' @param data A tibble with at least a `filing_year` column.
#' @return A tibble with columns: `filing_year`, `n`, `change`, `pct_change`.
#' @export
summarize_annual <- function(data) {
  data |>
    dplyr::count(filing_year, name = "n") |>
    dplyr::arrange(filing_year) |>
    dplyr::mutate(
      change = n - dplyr::lag(n),
      pct_change = change / dplyr::lag(n)
    )
}


#' Summarize geocoding quality
#'
#' Breaks geocoding accuracy into bands and counts cases in each.
#' Used by the Geographic Patterns report to assess data quality.
#'
#' @param data A tibble with a `geo_accuracy` column.
#' @return A tibble with columns: `accuracy_band`, `n_cases`, `pct`.
#' @export
summarize_geocoding <- function(data) {
  data |>
    dplyr::mutate(
      accuracy_band = dplyr::case_when(
        geo_accuracy == 1 ~ "Exact (1.0)",
        geo_accuracy >= 0.95 ~ "High (0.95-0.99)",
        geo_accuracy >= 0.90 ~ "Good (0.90-0.94)",
        geo_accuracy >= 0.85 ~ "Acceptable (0.85-0.89)",
        TRUE ~ "Below threshold"
      )
    ) |>
    dplyr::count(accuracy_band, name = "n_cases") |>
    dplyr::arrange(dplyr::desc(n_cases)) |>
    dplyr::mutate(pct = n_cases / sum(n_cases))
}
