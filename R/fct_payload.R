# Data sent to the browser canvas (inst/app/www/roadmap.js). Clicks, hover
# and highlighting run client-side; R sends a payload when the scope, the
# search or the scenario (levers, maturity targets) changes.

#' Milestones matching the search (by name, by a metric they move, or by an enabler they require)
search_milestones <- function(data, graph, query) {
  q <- tolower(trimws(query %||% ""))
  ms <- data$milestone
  if (!nzchar(q)) return(ms$id)
  e <- data$enabler
  hit <- vapply(ms$id, function(i) {
    ch <- graph$chains[[i]]
    grepl(q, tolower(ms$name[ms$id == i]), fixed = TRUE) ||
      any(grepl(q, tolower(data$metric$name[data$metric$id %in% graph$ms_metrics[[i]]]), fixed = TRUE)) ||
      any(grepl(q, tolower(paste(e$name, e$concept)[e$id %in% c(ch$direct, ch$foundation)]), fixed = TRUE))
  }, logical(1))
  ms$id[hit]
}

#' Build the client payload
#' @param model run_model() for the current scenario.
#' @param query search text.
viz_payload <- function(data, model, query = "", ns_prefix = "") {
  g <- model$graph
  ms <- data$milestone
  mt <- data$metric
  e <- data$enabler
  p <- data$process
  ins <- model$in_scope
  shown_ms <- intersect(ms$id[ins[ms$id]], search_milestones(data, g, query))
  need <- unique(unlist(lapply(g$chains[shown_ms], function(ch) c(ch$direct, ch$foundation))))
  shown_mt <- mt$id[vapply(mt$id, function(k) any(g$metric_ms[[k]] %in% shown_ms), TRUE)]
  measure <- ifelse(mt$measured, paste(fmt_num(mt$baseline, mt$unit), "\u2192", fmt_num(mt$target, mt$unit)), "")
  now <- ifelse(mt$measured, fmt_num(signif(mt$baseline + (mt$target - mt$baseline) * model$impact[mt$id], 3), mt$unit), "")
  pval <- vapply(p$id, function(i) sum(model$run_rate[mt$id[mt$process_id == i]]), 0)
  path <- model$path
  list(
    ns = ns_prefix,
    today = as.numeric(format(Sys.Date(), "%Y")) + (as.numeric(format(Sys.Date(), "%j")) - 1) / 365,
    groups = GROUPS,
    levels = LEVELS[, c("level", "code", "name")],
    enablers = data.frame(
      id = e$id, grp = e$enabler_group, sub = e$subgroup, concept = e$concept, name = e$name, level = e$level,
      start = e$start_q, end = e$end_q,
      t0 = q_to_time(e$start_q), t1 = model$schedule$end, t1_plan = q_to_time(e$end_q, TRUE),
      compression = round(model$schedule$compression, 3),
      cost = round(rowSums(model$cost)[e$id], 2), basis = e$cost_basis,
      n = unname(model$scope_n[e$id]), N = unname(model$scope_N[e$id]),
      issue = vapply(e$id, function(i) paste(c(model$issues$message[model$issues$enabler_id == i],
                                              g$level_issues$message[g$level_issues$enabler_id == i]), collapse = "; "), ""),
      show = e$id %in% need, stringsAsFactors = FALSE),
    prereq = g$prereq,
    issues = model$issues,
    processes = data.frame(
      id = p$id, name = p$name, owner = p$owner, cur = p$current_level,
      tgt = unname(model$targets[p$id]), base = p$target_level,
      path = I(lapply(p$id, function(i) {
        x <- path[path$process_id == i, , drop = FALSE]
        if (is.null(x) || !nrow(x)) return(list())
        lapply(seq_len(nrow(x)), function(j) list(level = x$level[j], t = if (is.na(x$t[j])) NULL else x$t[j]))
      })),
      value = round(pval, 2),
      show = if (is.null(model$scope)) TRUE else p$id %in% model$scope, stringsAsFactors = FALSE),
    milestones = data.frame(
      id = ms$id, process = ms$process_id, name = ms$name, due = ms$due, level = ms$level,
      t_due = due_to_time(ms$due), t_ready = unname(model$ready[ms$id]),
      late = ms$id %in% model$late$milestone_id, inscope = unname(ins[ms$id]),
      metrics = I(lapply(ms$id, function(i) g$ms_metrics[[i]])),
      show = ms$id %in% shown_ms, stringsAsFactors = FALSE),
    metrics = data.frame(
      id = mt$id, process = mt$process_id, name = mt$name, curve = mt$curve_id,
      measure = measure, now = now, reached = unname(model$metric_level[mt$id]),
      impact = round(unname(model$impact[mt$id]), 3), run = round(unname(model$run_rate[mt$id]), 2),
      show = mt$id %in% shown_mt, stringsAsFactors = FALSE),
    links = data.frame(enabler = data$milestone_enabler$enabler_id,
                       milestone = data$milestone_enabler$milestone_id,
                       weight = data$milestone_enabler$weight),
    mlinks = data.frame(metric = data$metric_milestone$metric_id,
                        milestone = data$metric_milestone$milestone_id)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
