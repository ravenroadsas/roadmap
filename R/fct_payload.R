# Data sent to the browser canvas (inst/app/www/roadmap.js). Clicks, hover
# and highlighting run client-side; R sends a payload when the scope, the
# search or the scenario changes.

#' Results matching the search (by name, or by the name of an enabler they require)
search_results <- function(data, graph, query) {
  q <- tolower(trimws(query %||% ""))
  r <- data$result
  if (!nzchar(q)) return(r$id)
  e <- data$enabler
  hit <- vapply(r$id, function(i) {
    ch <- graph$chains[[i]]
    grepl(q, tolower(r$name[r$id == i]), fixed = TRUE) ||
      any(grepl(q, tolower(paste(e$name, e$concept)[e$id %in% c(ch$direct, ch$foundation)]), fixed = TRUE))
  }, logical(1))
  r$id[hit]
}

#' Build the client payload
#' @param model run_model() for the current scenario and scope.
#' @param query search text.
viz_payload <- function(data, model, query = "", ns_prefix = "") {
  g <- model$graph
  r <- data$result
  e <- data$enabler
  scope <- model$scope %||% data$process$id
  shown_r <- intersect(r$id[model$scope_w[r$id] > 0], search_results(data, g, query))
  need <- unique(unlist(lapply(g$chains[shown_r], function(ch) c(ch$direct, ch$foundation))))
  measure <- ifelse(r$measured, paste(fmt_num(r$baseline, r$unit), "\u2192", fmt_num(r$target, r$unit)), "")
  pval <- vapply(data$process$id, function(p) sum(model$run_rate[r$id] * g$share[r$id, p]), 0)
  list(
    ns = ns_prefix,
    today = as.numeric(format(Sys.Date(), "%Y")) + (as.numeric(format(Sys.Date(), "%j")) - 1) / 365,
    groups = GROUPS,
    enablers = data.frame(
      id = e$id, grp = e$enabler_group, sub = e$subgroup, concept = e$concept, name = e$name,
      start = e$start_q, end = e$end_q,
      t0 = q_to_time(e$start_q), t1 = model$schedule$end, t1_plan = q_to_time(e$end_q, TRUE),
      compression = round(model$schedule$compression, 3),
      cost = round(rowSums(model$cost)[e$id], 2), basis = e$cost_basis,
      n = unname(model$scope_n[e$id]), N = unname(model$scope_N[e$id]),
      issue = vapply(e$id, function(i) paste(model$issues$message[model$issues$enabler_id == i], collapse = "; "), ""),
      show = e$id %in% need, stringsAsFactors = FALSE),
    prereq = g$prereq,
    issues = model$issues,
    processes = data.frame(id = data$process$id, name = data$process$name, owner = data$process$owner,
                           value = round(pval, 2), show = data$process$id %in% scope),
    results = data.frame(
      id = r$id, process = r$process_id, name = r$name, due = r$due,
      procs = I(lapply(r$id, function(i) processes_of_result(g, i))),
      shares = I(lapply(r$id, function(i) unname(round(g$share[i, processes_of_result(g, i)], 3)))),
      t_due = due_to_time(r$due), t_ready = unname(model$ready[r$id]),
      late = r$id %in% model$late$result_id, measured = r$measured, measure = measure,
      run = round(unname(model$run_rate[r$id]), 2),
      run_scope = round(unname(model$run_rate[r$id] * model$scope_w[r$id]), 2),
      show = r$id %in% shown_r, stringsAsFactors = FALSE),
    links = data.frame(enabler = data$result_enabler$enabler_id,
                       result = data$result_enabler$result_id,
                       weight = data$result_enabler$weight)
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
