# Scenario comparison: what the levers and acceleration change against the
# base case (same scope, base assumptions, plan resources).

#' Figures that move between base and scenario
#' @param model scenario run_model(); base_model the base case.
scenario_summary <- function(data, model, base_model) {
  p <- portfolio(model)
  b <- portfolio(base_model)
  sch <- model$schedule
  extra <- rowSums(model$cost) - rowSums(base_model$cost)
  acc <- sch[sch$resources > 1 + 1e-9, ]
  list(
    p = p, b = b,
    late = nrow(model$late), late_base = nrow(base_model$late),
    late_dep = sum(model$issues$type == "prereq_ends_later"),
    accelerated = data.frame(
      id = acc$id, name = data$enabler$name[match(acc$id, data$enabler$id)],
      scalability = acc$scalability, resources = acc$resources,
      end_plan = acc$end_plan, end = acc$end, extra_cost = unname(extra[acc$id]),
      stringsAsFactors = FALSE)
  )
}

#' Maturity targets: figures by process, scenario vs base, and enablers in / out
maturity_summary <- function(data, model, base_model) {
  p <- data$process
  fig <- function(m) lapply(p$id, function(i) process_figures(data, m, i))
  a <- fig(model); b <- fig(base_model)
  g <- function(x, k) vapply(x, `[[`, 0, k)
  msn <- function(m) vapply(p$id, function(i) sum(m$in_scope[milestones_of_process(data, i)]), 0L)
  need <- function(m) names(m$scope_factor)[m$scope_factor > 0]
  list(
    by_process = data.frame(id = p$id, name = p$name, cur = p$current_level,
                            tgt = unname(model$targets[p$id]), base_tgt = unname(base_model$targets[p$id]),
                            ms = msn(model), ms_base = msn(base_model),
                            run = g(a, "run_rate"), run_base = g(b, "run_rate"),
                            cost = g(a, "cost"), cost_base = g(b, "cost"),
                            npv = g(a, "npv"), npv_base = g(b, "npv"), stringsAsFactors = FALSE),
    added = setdiff(need(model), need(base_model)),
    dropped = setdiff(need(base_model), need(model)))
}
