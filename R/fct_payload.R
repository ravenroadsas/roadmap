# Data sent to the browser. The roadmap canvas (timeline, value chain,
# KPI list, highlighting) runs client-side in inst/app/www/roadmap.js, so
# clicks and hovers never round-trip to R. R only sends this payload when
# data, filters, audience or assumptions change.

#' Build the client payload
#' @param filters list(process = ids, group = ids, query = text).
viz_payload <- function(data, model, audience, filters, ns_prefix = "") {
  g <- model$graph
  kpi_ids <- visible_kpis(data, audience)
  k <- data$kpi[data$kpi$id %in% kpi_ids, ]
  q <- tolower(trimws(filters$query %||% ""))
  e <- data$enabler
  k_name_hit <- function(ids) {
    vapply(ids, function(i) {
      en <- names(which(g$weight[, i] > 0))
      grepl(q, tolower(k$name[k$id == i]), fixed = TRUE) ||
        any(grepl(q, tolower(e$name[e$id %in% en]), fixed = TRUE))
    }, logical(1))
  }

  # KPIs passing the process filter and search
  k_show <- k$process_id %in% filters$process
  if (nzchar(q)) k_show <- k_show & k_name_hit(k$id)

  # enablers: those behind the shown KPIs (plus foundations), in selected groups
  if (length(filters$process) < nrow(data$process) || nzchar(q)) {
    direct <- rownames(g$weight)[rowSums(g$weight[, k$id[k_show], drop = FALSE]) > 0]
    e_ids <- union(direct, ancestors(direct, g$prereq))
    if (nzchar(q)) e_ids <- union(e_ids, e$id[grepl(q, tolower(paste(e$name, e$subcategory)), fixed = TRUE)])
  } else {
    e_ids <- e$id
  }
  e_show <- e$id %in% e_ids & e$enabler_group %in% filters$group

  ms <- data$milestone
  if (audience == "public") ms <- ms[ms$visibility == "public", ]

  list(
    ns = ns_prefix,
    today = as.numeric(format(Sys.Date(), "%Y")) + (as.numeric(format(Sys.Date(), "%j")) - 1) / 365,
    groups = GROUPS,
    enablers = data.frame(
      id = e$id, grp = e$enabler_group, sub = e$subcategory, name = e$name,
      start = e$start_q, end = e$end_q,
      t0 = q_to_time(e$start_q), t1 = model$schedule$end, t1_plan = q_to_time(e$end_q, TRUE),
      compression = round(model$schedule$compression, 3),
      issue = vapply(e$id, function(i) paste(g$issues$message[g$issues$enabler_id == i], collapse = "; "), ""),
      capex = round(e$capex_musd * (1 + model$cfg$capex_overrun) * model$schedule$cost_factor, 2),
      opex = e$opex_musd_yr, fte_int = e$fte_internal, fte_ext = e$fte_partner,
      show = e_show, stringsAsFactors = FALSE
    ),
    prereq = g$prereq,
    issues = g$issues,
    processes = data.frame(id = data$process$id, name = data$process$name,
                           show = data$process$id %in% filters$process &
                             data$process$id %in% k$process_id[k_show]),
    kpis = data.frame(
      id = k$id, process = k$process_id, name = k$name, unit = k$unit,
      baseline = k$baseline, target = k$target, visibility = k$visibility,
      run = round(unname(model$run_rate[k$id]), 2),
      process_name = data$process$name[match(k$process_id, data$process$id)],
      show = k_show, stringsAsFactors = FALSE
    ),
    links = data.frame(enabler = data$enabler_link$enabler_id,
                       kpi = data$enabler_link$kpi_id,
                       weight = data$enabler_link$weight)[data$enabler_link$kpi_id %in% kpi_ids, ],
    milestones = data.frame(id = ms$id, date = ms$milestone_date, name = ms$name,
                            enabler = ms$enabler_id, t = month_to_time(ms$milestone_date),
                            visibility = ms$visibility, stringsAsFactors = FALSE)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
