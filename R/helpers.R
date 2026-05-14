#' Helper functions for project operations
#'
#' These helpers wrap common multi-step operations into single calls.
#' They're designed for interactive use — running the pipeline, deploying
#' the site, checking project status — from the R console or terminal.
#'
#' @name helpers
NULL


#' Run the full pipeline
#'
#' Wrapper around `targets::tar_make()` that loads config, runs the pipeline,
#' and reports status. This is the "one command" equivalent of running the
#' full data pipeline.
#'
#' @param reporter Character. targets reporter to use. Default "verbose".
#' @export
run_pipeline <- function(reporter = "verbose") {
  cli::cli_h1("Running targets pipeline")
  cli::cli_alert_info("Config: {.val {Sys.getenv('R_CONFIG_ACTIVE', 'local')}}")

  targets::tar_make(reporter = reporter)

  cli::cli_alert_success("Pipeline complete")
  cli::cli_alert_info("Run {.code targets::tar_visnetwork()} to see the dependency graph")
}


#' Deploy the Quarto site locally (preview)
#'
#' Renders the site with the specified profile and optionally opens a
#' preview server. Wraps the `quarto` CLI via `processx`.
#'
#' @param profile Character. Quarto profile: "drafts" or "public".
#' @param preview Logical. If TRUE, starts a live preview server.
#' @export
deploy_local <- function(profile = "drafts", preview = TRUE) {
  cmd <- if (preview) "preview" else "render"

  cli::cli_h1("{ifelse(preview, 'Previewing', 'Rendering')} site")
  cli::cli_alert_info("Profile: {.val {profile}}")

  args <- if (profile != "default") c(cmd, "--profile", profile) else cmd

  if (preview) {
    # Preview is interactive — run in foreground
    processx::run("quarto", args, echo = TRUE, wd = here::here())
  } else {
    result <- processx::run("quarto", args, echo = TRUE, wd = here::here())
    if (result$status == 0) {
      cli::cli_alert_success("Site rendered to {.path _site/}")
    } else {
      cli::cli_abort("Render failed with exit code {result$status}")
    }
  }
}


#' Check project status
#'
#' Reports the current state of the pipeline (which targets are outdated),
#' the config environment, and whether key files exist.
#'
#' @export
check_status <- function() {
  cli::cli_h1("Project Status")

  # Config
  env <- Sys.getenv("R_CONFIG_ACTIVE", "local")
  cli::cli_alert_info("Environment: {.val {env}}")

  # Data files
  raw_exists <- fs::file_exists(here::here("data", "raw", "evictions_granted_tulsa_2021_to_2025.csv"))
  parquet_exists <- fs::file_exists(here::here("data", "parquet", "evictions.parquet"))
  cli::cli_alert("{ifelse(raw_exists, 'v', 'x')} Raw CSV: {.path data/raw/}")

  cli::cli_alert("{ifelse(parquet_exists, 'v', 'x')} Parquet: {.path data/parquet/}")

  # Pipeline status
  if (fs::dir_exists(here::here("_targets"))) {
    outdated <- targets::tar_outdated(reporter = "silent")
    if (length(outdated) == 0) {
      cli::cli_alert_success("Pipeline: all targets up to date")
    } else {
      cli::cli_alert_warning("Pipeline: {length(outdated)} outdated target(s)")
      cli::cli_ul(outdated)
    }
  } else {
    cli::cli_alert_info("Pipeline: not yet initialized (run {.code run_pipeline()})")
  }
}


#' Generate and save the targets dependency graph
#'
#' Creates a static visualization of the targets DAG and saves it
#' to `docs/graphs/`.
#'
#' @param output_path Character. Where to save the graph image.
#' @export
save_dependency_graph <- function(output_path = here::here("docs", "graphs", "targets-dag.html")) {
  fs::dir_create(fs::path_dir(output_path))

  graph <- targets::tar_visnetwork()
  htmlwidgets::saveWidget(graph, output_path, selfcontained = TRUE)

  cli::cli_alert_success("Dependency graph saved to {.path {output_path}}")
}
