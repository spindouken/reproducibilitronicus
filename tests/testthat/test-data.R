# testthat tests for data functions

test_that("load_eviction_data reads CSV correctly", {
  # Create a temporary CSV matching the expected schema
  tmp <- withr::local_tempfile(fileext = ".csv")
  test_data <- tibble::tibble(
    filing_year = c(2021L, 2022L, 2023L),
    lat = c(36.1, 36.2, 36.3),
    lon = c(-95.9, -95.8, -95.7),
    geo_accuracy = c(1.0, 0.95, 0.90)
  )
  readr::write_csv(test_data, tmp)

  result <- readr::read_csv(tmp, show_col_types = FALSE, col_types = readr::cols(
    filing_year = readr::col_integer(),
    lat = readr::col_double(),
    lon = readr::col_double(),
    geo_accuracy = readr::col_double()
  ))

  expect_equal(nrow(result), 3)
  expect_named(result, c("filing_year", "lat", "lon", "geo_accuracy"))
  expect_type(result$filing_year, "integer")
  expect_type(result$lat, "double")
})


test_that("summarize_annual counts and computes change correctly", {
  test_data <- tibble::tibble(
    filing_year = c(rep(2021L, 100), rep(2022L, 120), rep(2023L, 110)),
    lat = runif(330),
    lon = runif(330),
    geo_accuracy = runif(330)
  )

  result <- summarize_annual(test_data)

  expect_equal(nrow(result), 3)
  expect_equal(result$n, c(100, 120, 110))
  expect_equal(result$change, c(NA, 20, -10))
  expect_true(is.na(result$pct_change[1]))
  expect_equal(result$pct_change[2], 0.2)
})


test_that("summarize_geocoding creates accuracy bands", {
  test_data <- tibble::tibble(
    geo_accuracy = c(1.0, 0.95, 0.90, 0.85, 0.80)
  )

  result <- summarize_geocoding(test_data)

  expect_true("accuracy_band" %in% names(result))
  expect_true("Exact (1.0)" %in% result$accuracy_band)
  expect_equal(sum(result$n_cases), 5)
  expect_equal(sum(result$pct), 1.0)
})


test_that("convert_csv_to_parquet writes valid parquet", {
  tmp_dir <- withr::local_tempdir()
  parquet_path <- file.path(tmp_dir, "test.parquet")

  test_data <- tibble::tibble(
    filing_year = 2021L:2023L,
    lat = c(36.1, 36.2, 36.3),
    lon = c(-95.9, -95.8, -95.7),
    geo_accuracy = c(1.0, 0.95, 0.90)
  )

  convert_csv_to_parquet(test_data, parquet_path)

  expect_true(file.exists(parquet_path))

  # Read it back and verify
  recovered <- arrow::read_parquet(parquet_path)
  expect_equal(nrow(recovered), 3)
  expect_named(recovered, c("filing_year", "lat", "lon", "geo_accuracy"))
})
