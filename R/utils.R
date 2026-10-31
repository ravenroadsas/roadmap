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

#' Which audiences may this user see?
#'
#' On Posit Connect, `session$user` and `session$groups` are set. Members of
#' the groups in `ROADMAP_MGMT_GROUPS` (comma separated) may switch to the
#' management view. Locally (no user), management is allowed for development
#' unless `ROADMAP_LOCAL_PUBLIC_ONLY=true`.
#' @return list(user, can_manage).
user_access <- function(user = NULL, groups = NULL,
                        mgmt_groups = Sys.getenv("ROADMAP_MGMT_GROUPS", "")) {
  allowed <- trimws(strsplit(mgmt_groups, ",", fixed = TRUE)[[1]])
  allowed <- allowed[nzchar(allowed)]
  if (is.null(user) || !nzchar(user)) {
    return(list(user = "local", can_manage =
      !identical(tolower(Sys.getenv("ROADMAP_LOCAL_PUBLIC_ONLY")), "true")))
  }
  list(user = user, can_manage = length(intersect(groups, allowed)) > 0)
}

#' KPI ids visible to an audience
visible_kpis <- function(data, audience = c("mgmt", "public")) {
  audience <- match.arg(audience)
  k <- data$kpi
  if (audience == "public") k <- k[k$visibility == "public", ]
  k$id
}

GROUPS <- data.frame(
  id = c("people", "digital", "data", "infra"),
  name = c("People, change & adoption", "Digital solutions", "Data", "Infrastructure"),
  stringsAsFactors = FALSE
)
