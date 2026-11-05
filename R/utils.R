# Formatting and user helpers.

fmt_musd <- function(x, digits = 1) {
  ifelse(is.na(x), "\u2013",
         paste0(ifelse(x < 0, "\u2212", ""), "$",
                formatC(abs(x), format = "f", digits = digits, big.mark = ","), "M"))
}

fmt_pct <- function(x, digits = 0) {
  ifelse(is.na(x), "\u2013", paste0(formatC(x * 100, format = "f", digits = digits), "%"))
}

fmt_num <- function(x, unit = "") {
  s <- ifelse(abs(x) >= 1000, formatC(x, format = "d", big.mark = ","),
              format(x, trim = TRUE, drop0trailing = TRUE))
  ifelse(unit == "$M", paste0("$", s, "M"),
         ifelse(unit == "%", paste0(s, "%"), paste(s, unit)))
}

fmt_cfg <- function(row, v = row$value) {
  if (isTRUE(row$is_pct)) fmt_pct(v)
  else if (row$key == "horizon_end") as.character(v)
  else paste(v, row$unit)
}

GROUPS <- data.frame(
  id = c("people", "digital", "data", "infra"),
  name = c("People, change & adoption", "Digital solutions", "Data", "Infrastructure"),
  stringsAsFactors = FALSE
)
