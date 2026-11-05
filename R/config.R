# Scenario assumptions. Read from the 'config' sheet of the input workbook.
# On Posit Connect a pin can override it (ROADMAP_PINS_BOARD), so a new base
# case can be published without redeploying the workbook.

CONFIG_PIN_NAME <- "roadmap_config"
CONFIG_COLUMNS <- c("key", "label", "unit", "value", "min", "max", "step",
                    "low", "high", "is_pct", "in_sensitivity", "description")
CONFIG_REQUIRED <- c("oil_price", "realization", "adoption_delay", "ramp_years",
                     "capex_overrun", "fte_cost", "partner_premium",
                     "discount_rate", "horizon_end")

#' Read the configuration table
#'
#' @param board_type "" (workbook only), "connect" or "folder". Defaults to
#'   the `ROADMAP_PINS_BOARD` environment variable.
#' @param path folder for a folder board.
#' @param input input workbook with a 'config' sheet.
#' @return data frame with one row per parameter.
config_read <- function(board_type = Sys.getenv("ROADMAP_PINS_BOARD", ""),
                        path = Sys.getenv("ROADMAP_PINS_PATH", ""),
                        input = input_path()) {
  if (nzchar(board_type) && requireNamespace("pins", quietly = TRUE)) {
    board <- switch(board_type,
      connect = pins::board_connect(),
      folder = pins::board_folder(path),
      stop("Unsupported pins board: ", board_type)
    )
    if (pins::pin_exists(board, CONFIG_PIN_NAME)) {
      return(config_clean(pins::pin_read(board, CONFIG_PIN_NAME), "pin roadmap_config"))
    }
  }
  config_clean(read_config_excel(input), paste0(basename(input), ", sheet 'config'"))
}

#' Write the configuration table to a pin (used to publish a new base case)
config_write <- function(cfg, board) {
  pins::pin_write(board, cfg, CONFIG_PIN_NAME, type = "csv",
                  description = "Roadmap scenario assumptions")
}

parse_bool <- function(x) {
  x <- tolower(trimws(as.character(x)))
  ifelse(x %in% c("true", "t", "yes", "y", "1"), TRUE,
         ifelse(x %in% c("false", "f", "no", "n", "0", "", NA), FALSE, NA))
}

#' Check and type the configuration table
#'
#' Stops with every problem listed: missing columns or keys, values that
#' are not numbers or TRUE/FALSE, duplicate keys, value outside min-max,
#' low/high outside min-max.
config_clean <- function(cfg, source = "config") {
  cfg <- as.data.frame(cfg, stringsAsFactors = FALSE)
  names(cfg) <- tolower(trimws(names(cfg)))
  probs <- character(0)
  miss_col <- setdiff(c("key", "label", "value", "min", "max", "step"), names(cfg))
  if (length(miss_col)) {
    stop("Problems in ", source, ":\n- missing column(s): ", paste(miss_col, collapse = ", "), call. = FALSE)
  }
  defaults <- list(unit = "", low = NA, high = NA, is_pct = FALSE, in_sensitivity = FALSE, description = "")
  for (n in names(defaults)) if (!n %in% names(cfg)) cfg[[n]] <- rep(defaults[[n]], nrow(cfg))
  cfg$key <- trimws(as.character(cfg$key))
  cfg <- cfg[!is.na(cfg$key) & cfg$key != "", CONFIG_COLUMNS]
  for (n in c("label", "unit", "description")) cfg[[n]] <- ifelse(is.na(cfg[[n]]), "", as.character(cfg[[n]]))
  for (n in c("value", "min", "max", "step", "low", "high")) {
    raw <- cfg[[n]]
    v <- if (is.numeric(raw)) raw else suppressWarnings(as.numeric(gsub(",", ".", trimws(raw), fixed = TRUE)))
    bad <- which(!is.na(raw) & trimws(as.character(raw)) != "" & is.na(v))
    if (length(bad)) probs <- c(probs, sprintf("key '%s', column '%s': '%s' is not a number", cfg$key[bad], n, raw[bad]))
    if (n %in% c("value", "min", "max", "step")) {
      miss <- setdiff(which(is.na(v)), bad)
      if (length(miss)) probs <- c(probs, sprintf("key '%s', column '%s' is empty", cfg$key[miss], n))
    }
    cfg[[n]] <- v
  }
  for (n in c("is_pct", "in_sensitivity")) {
    b <- parse_bool(cfg[[n]])
    bad <- which(is.na(b))
    if (length(bad)) probs <- c(probs, sprintf("key '%s', column '%s': '%s' is not TRUE/FALSE", cfg$key[bad], n, cfg[[n]][bad]))
    cfg[[n]] <- b
  }
  dup <- unique(cfg$key[duplicated(cfg$key)])
  if (length(dup)) probs <- c(probs, paste("duplicate key:", paste(dup, collapse = ", ")))
  miss_key <- setdiff(CONFIG_REQUIRED, cfg$key)
  if (length(miss_key)) probs <- c(probs, paste("missing key(s):", paste(miss_key, collapse = ", ")))
  if (!length(probs)) {
    out_rng <- which(cfg$value < cfg$min | cfg$value > cfg$max)
    probs <- c(probs, sprintf("key '%s': value %s is outside min-max (%s-%s)",
                              cfg$key[out_rng], cfg$value[out_rng], cfg$min[out_rng], cfg$max[out_rng]))
    sens <- which(cfg$in_sensitivity & (is.na(cfg$low) | is.na(cfg$high) |
                                          cfg$low < cfg$min | cfg$high > cfg$max | cfg$low >= cfg$high))
    probs <- c(probs, sprintf("key '%s': low/high must be inside min-max and low < high to be used in the tornado",
                              cfg$key[sens]))
  }
  if (length(probs)) stop("Problems in ", source, ":\n- ", paste(probs, collapse = "\n- "), call. = FALSE)
  rownames(cfg) <- NULL
  cfg
}

#' Named list of parameter values
#' @param cfg config data frame.
#' @param which "value" (base case), "low" or "high".
config_values <- function(cfg, which = "value") {
  stats::setNames(as.list(cfg[[which]]), cfg$key)
}
