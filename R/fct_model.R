# Cost and value model. Pure functions: data + graph + config values in,
# yearly profiles out. All money in $M.

overlap <- function(a, b, y) pmax(0, pmin(b, y + 1) - pmax(a, y))

#' Scenario schedule for each enabler
#'
#' The scenario lever `resource_multiplier` (r, 1 = plan) adds resources
#' to every enabler. Each enabler's `scalability` (s) says how its
#' duration responds:
#'
#'   duration = plan duration x r^(-s)        (start date fixed)
#'
#' * s = 1: linear. Double the resources, half the time, same total cost.
#' * s > 1: scales better than linear (e.g. many independent work
#'   packages). The time saved is more than proportional and total cost falls.
#' * 0 < s < 1: diminishing returns. Each extra resource buys less time
#'   and total cost rises.
#' * s = 0: rigid. Extra resources would not shorten it, so none are
#'   added and the enabler keeps its plan dates and cost.
#'
#' Total build effort (people and capex) scales by r x duration / plan duration
#' = r^(1 - s). The same spend is squeezed into fewer quarters, so yearly
#' expenditure rises (see cost_profile()). Durations never go below one
#' quarter, and an enabler that ends before it starts counts as one quarter long.
schedule <- function(enabler, cfg) {
  s <- q_to_time(enabler$start_q)
  f_plan <- q_to_time(enabler$end_q, end = TRUE)
  d_plan <- pmax(f_plan - s, 0.25)
  sc <- enabler$scalability
  if (is.null(sc)) sc <- rep(0, nrow(enabler))
  sc <- pmin(pmax(ifelse(is.na(sc), 0, sc), 0), 2)
  r <- max(1, cfg$resource_multiplier %||% 1)
  r_e <- ifelse(sc > 0, r, 1)                         # no resources wasted on rigid enablers
  d <- pmax(d_plan * r_e^(-sc), pmin(d_plan, 0.25))
  data.frame(id = enabler$id, start = s, end_plan = f_plan, end = s + d,
             duration_plan = d_plan, duration = d, scalability = sc,
             resources = r_e, compression = 1 - d / d_plan,
             people_factor = r_e, cost_factor = r_e * d / d_plan,
             stringsAsFactors = FALSE)
}

#' Yearly cost of each enabler, split by type
#'
#' * capex: capex x (1 + overrun) x effort factor, spread evenly over the
#'   scenario build (start fixed, end per schedule())
#' * people: internal and partner FTE (partner at a premium) x resource
#'   multiplier, during the build
#' * opex: from the scenario go-live to the horizon
#' @param sched output of schedule(); computed from cfg when missing.
#' @return list of three matrices (enabler x year): capex, people, opex.
cost_parts <- function(enabler, cfg, years, sched = schedule(enabler, cfg)) {
  s <- sched$start
  f <- sched$end
  horizon <- max(years) + 1
  people <- (enabler$fte_internal * cfg$fte_cost +
             enabler$fte_partner * cfg$fte_cost * (1 + cfg$partner_premium)) / 1000 *
    sched$people_factor
  capex <- enabler$capex_musd * (1 + cfg$capex_overrun) * sched$cost_factor / sched$duration
  mk <- function(f_year) {
    matrix(vapply(years, f_year, numeric(nrow(enabler))), nrow = nrow(enabler),
           dimnames = list(enabler$id, years))
  }
  list(
    capex = mk(function(y) capex * overlap(s, f, y)),
    people = mk(function(y) people * overlap(s, f, y)),
    opex = mk(function(y) enabler$opex_musd_yr * overlap(f, horizon, y))
  )
}

#' Yearly cost of each enabler (sum of cost_parts())
#' @return matrix enabler x year.
cost_profile <- function(enabler, cfg, years, sched = schedule(enabler, cfg)) {
  p <- cost_parts(enabler, cfg, years, sched)
  p$capex + p$people + p$opex
}

#' Average FTE working on enabler builds per year (scenario resources)
#' @return data frame year, internal, partner.
fte_profile <- function(enabler, years, sched) {
  b <- vapply(years, function(y) overlap(sched$start, sched$end, y), numeric(nrow(enabler)))
  b <- matrix(b, nrow = nrow(enabler))
  data.frame(year = years,
             internal = colSums(b * enabler$fte_internal * sched$people_factor),
             partner = colSums(b * enabler$fte_partner * sched$people_factor))
}

#' KPI ready date: latest scenario end across its enabler chain
kpi_ready <- function(graph, sched) {
  end_t <- stats::setNames(sched$end, sched$id)
  vapply(graph$chains, function(ch) max(end_t[c(ch$direct, ch$foundation)]), numeric(1))
}

#' Factor applied to a KPI's value from its driver parameter
driver_factor <- function(driver, cfg, base) {
  vapply(driver, function(d) {
    if (is.na(d) || d == "none" || is.null(cfg[[d]])) 1 else cfg[[d]] / base[[d]]
  }, numeric(1), USE.NAMES = FALSE)
}

#' Yearly value of each KPI
#'
#' Full value = value_musd x realisation x driver factor. Benefits start
#' `adoption_delay` years after the KPI's whole enabler chain is ready
#' and ramp linearly over `ramp_years`. Evaluated quarterly, averaged per year.
#' @return matrix KPI x year.
value_profile <- function(kpi, ready, cfg, base, years) {
  full <- kpi$value_musd * cfg$realization * driver_factor(kpi$value_driver, cfg, base)
  r <- ready[kpi$id]
  out <- vapply(years, function(y) {
    q <- y + (0:3 + 0.5) / 4
    ramp <- vapply(r, function(ri) {
      mean(pmin(1, pmax(0, (q - ri - cfg$adoption_delay) / cfg$ramp_years)))
    }, numeric(1))
    full * ramp
  }, numeric(nrow(kpi)))
  out <- matrix(out, nrow = nrow(kpi), dimnames = list(kpi$id, years))
  attr(out, "run_rate") <- stats::setNames(full, kpi$id)
  out
}

#' Run the full model for one scenario
#' @param data roadmap data list.
#' @param graph output of build_graph().
#' @param cfg named list of parameter values (scenario).
#' @param base named list of base-case values (for driver factors).
run_model <- function(data, graph, cfg, base = cfg) {
  start <- floor(min(q_to_time(data$enabler$start_q)))
  years <- seq(start, cfg$horizon_end)
  sched <- schedule(data$enabler, cfg)
  ready <- kpi_ready(graph, sched)
  parts <- cost_parts(data$enabler, cfg, years, sched)
  cost <- parts$capex + parts$people + parts$opex
  plan_cfg <- cfg
  plan_cfg$resource_multiplier <- 1
  plan_cost <- cost_profile(data$enabler, plan_cfg, years)
  value <- value_profile(data$kpi, ready, cfg, base, years)
  list(
    cfg = cfg, years = years, start = start,
    schedule = sched, ready = ready,
    cost = cost, cost_parts = parts, plan_cost = plan_cost, value = value,
    run_rate = attr(value, "run_rate"),
    discount = 1 / (1 + cfg$discount_rate)^(years - start),
    graph = graph
  )
}

#' Portfolio figures for a set of KPIs
#'
#' Enabler costs are allocated to the KPIs through the graph's allocation
#' shares, so the full KPI set carries the full cost.
portfolio <- function(model, kpi_ids = colnames(model$graph$alloc)) {
  share <- rowSums(model$graph$alloc[, kpi_ids, drop = FALSE])
  cost <- colSums(model$cost * share)
  value <- colSums(model$value[kpi_ids, , drop = FALSE])
  net <- value - cost
  cum <- cumsum(net)
  pay <- which(cum >= 0)
  total_cost <- sum(cost)
  list(
    years = model$years, value = unname(value), cost = unname(cost),
    net = unname(net), cum_net = unname(cum),
    npv = sum(net * model$discount),
    total_value = sum(value), total_cost = total_cost,
    roi = if (total_cost > 0) (sum(value) - total_cost) / total_cost else NA_real_,
    payback = if (length(pay)) model$years[pay[1]] else NA_integer_,
    run_rate = sum(model$run_rate[kpi_ids])
  )
}

#' Per-enabler cost to horizon, and cost allocated to one KPI
enabler_costs <- function(model, kpi_id = NULL) {
  tot <- rowSums(model$cost)
  if (is.null(kpi_id)) return(tot)
  tot * model$graph$alloc[, kpi_id]
}

#' Direct value attributed to each enabler (by normalised link weight)
enabler_direct_value <- function(model, kpi_ids = colnames(model$graph$weight)) {
  as.vector(model$graph$weight[, kpi_ids, drop = FALSE] %*% rowSums(model$value[kpi_ids, , drop = FALSE])) |>
    stats::setNames(rownames(model$graph$weight))
}

#' One-at-a-time sensitivity of NPV
#'
#' Each lever is set to its low and high value while the others keep the
#' scenario value.
#' @param cfg_table config data frame (low / high / in_sensitivity).
#' @return data frame sorted by NPV spread, largest first.
tornado <- function(data, graph, cfg, base, cfg_table, kpi_ids = graph$kpis) {
  levers <- cfg_table[cfg_table$in_sensitivity, ]
  npv_at <- function(key, v) {
    s <- cfg
    s[[key]] <- v
    portfolio(run_model(data, graph, s, base), kpi_ids)$npv
  }
  out <- data.frame(
    key = levers$key, label = levers$label,
    low = levers$low, high = levers$high,
    npv_low = mapply(npv_at, levers$key, levers$low),
    npv_high = mapply(npv_at, levers$key, levers$high),
    stringsAsFactors = FALSE
  )
  out$spread <- abs(out$npv_high - out$npv_low)
  out <- out[order(-out$spread), ]
  rownames(out) <- NULL
  out
}
