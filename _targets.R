# _targets.R — Pipeline orchestration
#
# This file defines the targets pipeline: a sequence of steps where each
# step's output is cached and only re-run when its inputs change.
#
# The pipeline flow:
#   raw CSV → parquet conversion → DuckDB/Arrow queries → summaries → reports
#
# Run with: targets::tar_make()
# Visualize with: targets::tar_visnetwork()
#
# Key concept: targets uses HASHING to detect changes. When you run tar_make(),
# it hashes each function's code + its inputs. If the hash matches the cache,
# the step is skipped. This is why targets is faster than re-running scripts:
# it only does work that actually needs doing.
#
# Reference: the tcj project's _targets.R uses the same pattern but with
# GCS-backed storage (repository = "gcp"). This project stores locally first;
# GCS is added in Phase 4.

library(targets)
library(tarchetypes)

# --- Package loading ---
# tar_option_set declares packages available to all targets.
# This is equivalent to library() calls but scoped to the pipeline.
tar_option_set(
  packages = c(
    "dplyr",
    "readr",
    "arrow",
    "duckdb",
    "DBI",
    "ggplot2",
    "gt",
    "here",
    "fs",
    "cli",
    "scales",
    "tibble"
  )
)

# --- Load functions from R/ ---
# tar_source() sources all .R files in R/, making project functions
# available to targets. This is the connection between the R package
# structure (Phase 2) and the pipeline (Phase 3).
tar_source()

# --- Pipeline definition ---
# Each tar_target() defines one step. The DAG (directed acyclic graph)
# is inferred automatically from which targets reference which others.
list(
  # ===== Stage 1: Data Ingestion =====
  # Read the raw CSV from data/raw/. This is the entry point.
  # In the reference targets project, this would be a database call
  # (ojodb::ojo_eviction_cases). Here we use the exported CSV.
  tar_target(
    name = raw_data,
    command = load_eviction_data()
  ),

  # ===== Stage 2: Parquet Conversion =====
  # Convert CSV data to Parquet format. This step demonstrates why
  # parquet matters: typed columns, compression, and queryability.
  # The parquet file becomes the canonical data format for downstream steps.
  tar_target(
    name = parquet_path,
    command = convert_csv_to_parquet(
      data = raw_data,
      output_path = here::here("data", "parquet", "evictions.parquet")
    ),
    format = "file"
    # format = "file" tells targets to track the FILE, not the R object.
    # If the file changes on disk, downstream targets re-run.
  ),

  # ===== Stage 3: Arrow + DuckDB Queries =====
  # Read the parquet back via Arrow (memory-efficient, typed access)
  tar_target(
    name = eviction_data,
    command = read_parquet_evictions(parquet_path)
  ),

  # DuckDB analytical query — demonstrates SQL on parquet.
  # This query computes monthly trends, which is more naturally expressed
  # in SQL (window functions) than in dplyr.
  tar_target(
    name = duckdb_annual_summary,
    command = query_evictions_duckdb(
      sql = "
        SELECT
          filing_year,
          COUNT(*) as n,
          AVG(geo_accuracy) as avg_accuracy,
          COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY filing_year) as yoy_change
        FROM evictions
        GROUP BY filing_year
        ORDER BY filing_year
      ",
      parquet_path = parquet_path
    )
  ),

  # ===== Stage 4: Summaries for Reports =====
  # These use dplyr (via the R functions in R/analysis.R) rather than SQL.
  # Both approaches work — dplyr is often clearer for simple operations,
  # DuckDB/SQL is better for complex analytics (window functions, CTEs).
  tar_target(
    name = annual_summary,
    command = summarize_annual(eviction_data)
  ),

  tar_target(
    name = geocoding_summary,
    command = summarize_geocoding(eviction_data)
  ),

  # ===== Stage 5: Write report-ready outputs =====
  # Save summaries as parquet files that reports will consume directly.
  tar_target(
    name = annual_parquet,
    command = convert_csv_to_parquet(
      data = annual_summary,
      output_path = here::here("data", "parquet", "eviction_summary.parquet")
    ),
    format = "file"
  ),

  tar_target(
    name = geocoding_parquet,
    command = convert_csv_to_parquet(
      data = geocoding_summary,
      output_path = here::here("data", "parquet", "geocoding_summary.parquet")
    ),
    format = "file"
  )
)
