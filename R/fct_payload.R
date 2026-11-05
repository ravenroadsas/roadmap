# Data sent to the browser. The roadmap canvas (timeline, value chain,
# KPI list, highlighting) runs client-side in inst/app/www/roadmap.js, so
# clicks and hovers never round-trip to R. R only sends this payload when
# data, filters or assumptions change.

#' Processes passing the process and owner filters
filtered_processes <- function(data, filters) {
  p <- data$process
  sel_p <- filters$process %||% p$id
  sel_o <- filters$owner %||% unique(p$owner)
  p$id[p$id %in% sel_p & p$owner %in% sel_o]
}

#' KPIs passing the left-panel filters (process, owner, search)
#'
#' The enabler-group filter does not remove KPIs; it only hides enablers.
filtered_kpi_ids <- function(data, graph, filters) {
  k <- data$kpi
  e <- data$enabler
  keep <- k$process_id %in% filtered_processes(data, filters)
  q <- tolower(trimws(filters$query %||% ""))
  if (nzchar(q)) {
    hit <- vapply(k$id, function(i) {
      en <- names(which(graph$weight[, i] > 0))
      grepl(q, tolower(k$name[k$id == i]), fixed = TRUE) ||
        any(grepl(q, tolower(e$name[e$id %in% en]), fixed = TRUE))
    }, logical(1))
    keep <- keep & hit
  }
  k$id[keep]
}

#' Is any left-panel filter narrowing the portfolio?
filters_active <- function(data, filters) {
  length(filtered_processes(data, filters)) < nrow(data$process) ||
    nzchar(trimws(filters$query %||% "")) ||
    length(filters$group %||% GROUPS$id) < nrow(GROUPS)
}

#' Build the client payload
#' @param filters list(process, owner, group, query).
viz_payload <- function(data, model, filters, ns_prefix = "") {
  g <- model$graph
  k <- data$kpi
  e <- data$enabler
  q <- tolower(trimws(filters$query %||% ""))
  procs <- filtered_processes(data, filters)
  shown <- filtered_kpi_ids(data, g, filters)
  k_show <- k$id %in% shown

  # enablers: those behind the shown KPIs (plus foundations), in selected groups
  if (length(procs) < nrow(data$process) || nzchar(q)) {
    direct <- rownames(g$weight)[rowSums(g$weight[, shown, drop = FALSE]) > 0]
    e_ids <- union(direct, ancestors(direct, g$prereq))
    if (nzchar(q)) e_ids <- union(e_ids, e$id[grepl(q, tolower(paste(e$name, e$subcategory)), fixed = TRUE)])
  } else {
    e_ids <- e$id
  }
  e_show <- e$id %in% e_ids & e$enabler_group %in% (filters$group %||% GROUPS$id)
  ms <- data$milestone

  list(
    ns = ns_prefix,
    today = as.numeric(format(Sys.Date(), "%Y")) + (as.numeric(format(Sys.Date(), "%j")) - 1) / 365,
    groups = GROUPS,
    enablers = data.frame(
      id = e$id, grp = e$enabler_group, sub = e$subcategory, name = e$name,
      start = e$start_q, end = e$end_q,
      t0 = q_to_time(e$start_q), t1 = model$schedule$end, t1_plan = q_to_time(e$end_q, TRUE),
      compression = round(model$schedule$compression, 3),
      issue = vapply(e$id, function(i) paste(model$issues$message[model$issues$enabler_id == i], collapse = "; "), ""),
      capex = round(e$capex_musd * (1 + model$cfg$capex_overrun) * model$schedule$cost_factor, 2),
      opex = e$opex_musd_yr, fte_int = e$fte_internal, fte_ext = e$fte_partner,
      show = e_show, stringsAsFactors = FALSE
    ),
    prereq = g$prereq,
    issues = model$issues,
    processes = data.frame(id = data$process$id, name = data$process$name,
                           show = data$process$id %in% k$process_id[k_show]),
    kpis = data.frame(
      id = k$id, process = k$process_id, name = k$name, unit = k$unit,
      baseline = k$baseline, target = k$target,
      run = round(unname(model$run_rate[k$id]), 2),
      process_name = data$process$name[match(k$process_id, data$process$id)],
      show = k_show, stringsAsFactors = FALSE
    ),
    links = data.frame(enabler = data$enabler_link$enabler_id,
                       kpi = data$enabler_link$kpi_id,
                       weight = data$enabler_link$weight),
    milestones = data.frame(id = ms$id, date = ms$milestone_date, name = ms$name,
                            enabler = ms$enabler_id, t = model$milestones$t, t_plan = model$milestones$t_plan,
                            stringsAsFactors = FALSE)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
