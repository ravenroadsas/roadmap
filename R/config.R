# Scenario assumptions. Stored on a pin (Posit Connect board) when
# ROADMAP_PINS_BOARD is set, otherwise read from the packaged CSV.

CONFIG_PIN_NAME <- "roadmap_config"

#' Read the configuration table
#'
#' @param board_type "" (CSV), "connect" or "folder". Defaults to the
#'   `ROADMAP_PINS_BOARD` environment variable.
#' @param path folder for a folder board.
#' @return data frame with one row per parameter.
config_read <- function(board_type = Sys.getenv("ROADMAP_PINS_BOARD", ""),
                        path = Sys.getenv("ROADMAP_PINS_PATH", "")) {
  if (nzchar(board_type) && requireNamespace("pins", quietly = TRUE)) {
    board <- switch(board_type,
      connect = pins::board_connect(),
      folder = pins::board_folder(path),
      stop("Unsupported pins board: ", board_type)
    )
    if (pins::pin_exists(board, CONFIG_PIN_NAME)) {
      return(config_clean(pins::pin_read(board, CONFIG_PIN_NAME)))
    }
  }
  config_clean(utils::read.csv(app_sys("extdata", "config.csv"),
                               stringsAsFactors = FALSE))
}

#' Write the configuration table to a pin (used to publish a new base case)
config_write <- function(cfg, board) {
  pins::pin_write(board, cfg, CONFIG_PIN_NAME, type = "csv",
                  description = "Roadmap scenario assumptions")
}

config_clean <- function(cfg) {
  num <- c("value", "min", "max", "step", "low", "high")
  cfg[num] <- lapply(cfg[num], as.numeric)
  cfg$is_pct <- as.logical(cfg$is_pct)
  cfg$in_sensitivity <- as.logical(cfg$in_sensitivity)
  required <- c("oil_price", "realization", "adoption_delay", "ramp_years",
                "capex_overrun", "fte_cost", "partner_premium",
                "discount_rate", "horizon_end")
  missing <- setdiff(required, cfg$key)
  if (length(missing)) stop("Config is missing: ", paste(missing, collapse = ", "))
  cfg
}

#' Named list of parameter values
#' @param cfg config data frame.
#' @param which "value" (base case), "low" or "high".
config_values <- function(cfg, which = "value") {
  stats::setNames(as.list(cfg[[which]]), cfg$key)
}
