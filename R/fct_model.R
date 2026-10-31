# Cost and value model. Pure functions: data + graph + config values in,
# yearly profiles out. All money in $M.

overlap <- function(a, b, y) pmax(0, pmin(b, y + 1) - pmax(a, y))

#' Scenario schedule for each enabler
#'
#' Each enabler has a `compressibility` (0-0.9): the largest share of its
#' duration that extra resources can remove. The scenario lever
#' `acceleration` (0-1) sets how much of that room is used, so the
#' compression is c = acceleration x compressibility and the duration
#' becomes d x (1 - c). Start dates do not move.
#'
#' Compression is not free and not linear: doing the same work in
#' (1 - c) of the time needs (1 - c)^-k times the people, with
#' k = `crash_exponent` (1 = linear). Total build effort and capex
#' therefore scale by cost_factor = (1 - c)^(1 - k).
#'
#' An enabler that ends before it starts is treated as one quarter long.
schedule <- function(enabler, cfg) {
  s <- q_to_time(enabler$start_q)
  f_plan <- q_to_time(enabler$end_q, end = TRUE)
  d_plan <- pmax(f_plan - s, 0.25)
  comp <- enabler$compressibility
  if (is.null(comp)) comp <- rep(0, nrow(enabler))
  comp <- pmin(pmax(ifelse(is.na(comp), 0, comp), 0), 0.9)
  c <- (cfg$acceleration %||% 0) * comp
  k <- cfg$crash_exponent %||% 1
  d <- d_plan * (1 - c)
  data.frame(id = enabler$id, start = s, end_plan = f_plan, end = s + d,
             duration_plan = d_plan, duration = d, compressibility = comp,
             compression = c, people_factor = (1 - c)^(-k),
             cost_factor = (1 - c)^(1 - k), stringsAsFactors = FALSE)
}

#' Yearly cost of each enabler
#'
#' capex x (1 + overrun) x crash cost factor, spread over the (scenario)
#' build; people cost during the build, scaled up when compressed (partner
#' FTE at a premium); opex from go-live to the horizon.
#' @param sched output of schedule(); computed from cfg when missing.
#' @return matrix enabler x year.
cost_profile <- function(enabler, cfg, years, sched = schedule(enabler, cfg)) {
  s <- sched$start
  f <- sched$end
  horizon <- max(years) + 1
  people <- (enabler$fte_internal * cfg$fte_cost +
             enabler$fte_partner * cfg$fte_cost * (1 + cfg$partner_premium)) / 1000 *
    sched$people_factor
  out <- vapply(years, function(y) {
    build <- overlap(s, f, y)
    enabler$capex_musd * (1 + cfg$capex_overrun) * sched$cost_factor * build / sched$duration +
      people * build +
      enabler$opex_musd_yr * overlap(f, horizon, y)
  }, numeric(nrow(enabler)))
  matrix(out, nrow = nrow(enabler), dimnames = list(enabler$id, years))
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
  cost <- cost_profile(data$enabler, cfg, years, sched)
  value <- value_profile(data$kpi, ready, cfg, base, years)
  list(
    cfg = cfg, years = years, start = start,
    schedule = sched, ready = ready,
    cost = cost, value = value,
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
