# Cost and value model. Pure functions: data + graph + config values in,
# yearly profiles out. All money in $M.

overlap <- function(a, b, y) pmax(0, pmin(b, y + 1) - pmax(a, y))

#' Yearly cost of each enabler
#'
#' capex x (1 + overrun) spread over the build, people cost during the
#' build (partner FTE at a premium), opex from go-live to the horizon.
#' @return matrix enabler x year.
cost_profile <- function(enabler, cfg, years) {
  s <- q_to_time(enabler$start_q)
  f <- q_to_time(enabler$end_q, end = TRUE)
  horizon <- max(years) + 1
  people <- (enabler$fte_internal * cfg$fte_cost +
             enabler$fte_partner * cfg$fte_cost * (1 + cfg$partner_premium)) / 1000
  out <- vapply(years, function(y) {
    build <- overlap(s, f, y)
    enabler$capex_musd * (1 + cfg$capex_overrun) * build / (f - s) +
      people * build +
      enabler$opex_musd_yr * overlap(f, horizon, y)
  }, numeric(nrow(enabler)))
  out <- matrix(out, nrow = nrow(enabler), dimnames = list(enabler$id, years))
  out
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
  cost <- cost_profile(data$enabler, cfg, years)
  value <- value_profile(data$kpi, graph$ready, cfg, base, years)
  list(
    cfg = cfg, years = years, start = start,
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
