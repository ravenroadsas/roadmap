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
