# Dependency Audit

This note separates dependencies that are actively used by project code from
dependencies that are present for teaching, future work, or package installation.

## Actively Used

- `arrow`: writes and reads parquet files.
- `cli`: prints status messages from helper functions.
- `dplyr`: summarizes data in R functions and reports.
- `duckdb`: used by `query_evictions_duckdb()` and the `duckdb_annual_summary`
  target in `_targets.R`.
- `DBI`: connects R to DuckDB.
- `fs`: checks and creates files/directories.
- `ggplot2`: builds report charts.
- `gt`: builds report tables.
- `here`: constructs project-relative paths.
- `readr`: reads CSV data.
- `scales`: formats report labels and percentages.
- `targets`: runs the pipeline.
- `testthat` and `withr`: used by tests.
- `yaml`: reads `config/base.yaml` and environment overlays.

## Partly Implemented

- `config/base.yaml`, `config/local.yaml`, and `config/ci.yaml`: the loader is
  implemented, and `load_eviction_data()` uses `pipeline$source_file`. Many
  paths are still hardcoded in `_targets.R`, reports, and helpers.
- `duckdb`: implemented as a demonstration pipeline branch, but
  `duckdb_annual_summary` is not currently used by downstream report outputs.
- `processx`: used by `deploy_local()`, but that helper is not part of the
  GitHub Actions deployment path.

## Present But Not Really Used Yet

- `ojothemes` and `ojoutils`: listed as GitHub remotes, but no project code calls
  them yet.
- `pointblank`: listed as a suggested package, but no validation checks use it.
- `lintr`: configured, but not currently run by a workflow.
- `rlang`: listed in `DESCRIPTION`, but project code does not directly call it.
- `tarchetypes`: loaded in `_targets.R`, but no tarchetypes helpers are used.

## Docker System Packages

Many Ubuntu packages in `docker/Dockerfile` are not called by this project's R
code directly. They exist so locked R packages can compile and install in a clean
Linux image.

- `xz-utils`: needed by `duckdb` source installation.
- `cmake`: needed by packages such as `arrow`.
- `libglpk-dev`: needed by `igraph`, a dependency in the locked environment.
- `libnode-dev`: needed by `V8`.
- `pandoc`: conservative support for R Markdown/Quarto-adjacent packages, even
  though Quarto also bundles Pandoc.
- graphics/font/image libraries such as `libpng-dev`, `libjpeg-dev`,
  `libcairo2-dev`, `libharfbuzz-dev`, and `libfribidi-dev`: needed by plotting,
  table, and rendering packages.

## Cleanup Direction

The next cleanup would be to choose between two paths:

1. Keep the teaching scaffold, but document which pieces are intentionally
   aspirational.
2. Tighten the repo to only what is exercised today by removing unused packages
   and wiring config values into the remaining hardcoded paths.
