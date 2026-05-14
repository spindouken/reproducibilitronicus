#' Load project configuration
#'
#' Reads and merges the base config with an environment-specific overlay.
#' The base config (`config/base.yaml`) always loads. If an environment
#' config exists (`config/{env}.yaml`), its values override matching keys.
#'
#' @param env Character. Environment name: "local" or "ci". Defaults to
#'   the `R_CONFIG_ACTIVE` environment variable, falling back to "local".
#' @return A named list of configuration values.
#' @export
#'
#' @examples
#' config <- load_config()
#' config$paths$data_raw
load_config <- function(env = Sys.getenv("R_CONFIG_ACTIVE", "local")) {
  base_path <- here::here("config", "base.yaml")

  if (!fs::file_exists(base_path)) {
    cli::cli_abort("Base config not found at {.path {base_path}}")
  }

  config <- yaml::read_yaml(base_path)

  # Merge environment-specific overrides if they exist

  env_path <- here::here("config", paste0(env, ".yaml"))
  if (fs::file_exists(env_path)) {
    env_config <- yaml::read_yaml(env_path)
    # Shallow merge: env values override base values at the top level
    config <- utils::modifyList(config, env_config)
    cli::cli_alert_info("Loaded config overlay: {.val {env}}")
  }

  config
}
