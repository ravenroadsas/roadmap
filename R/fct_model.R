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
#' @param resources optional named vector of per-enabler resource
#'   multipliers (from solve_target()); overrides `resource_multiplier`.
schedule <- function(enabler, cfg, resources = NULL) {
  s <- q_to_time(enabler$start_q)
  f_plan <- q_to_time(enabler$end_q, end = TRUE)
  d_plan <- pmax(f_plan - s, 0.25)
  sc <- enabler$scalability
  if (is.null(sc)) sc <- rep(0, nrow(enabler))
  sc <- pmin(pmax(ifelse(is.na(sc), 0, sc), 0), 2)
  if (is.null(resources)) {
    r <- rep(max(1, cfg$resource_multiplier %||% 1), nrow(enabler))
  } else {
    r <- pmax(1, ifelse(is.na(resources[enabler$id]), 1, resources[enabler$id]))
  }
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

#' Result ready date: latest scenario end across its required enablers and
#' their prerequisites
result_ready <- function(graph, sched) {
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
#' `adoption_delay` years after the result's whole enabler chain is ready
#' and ramp linearly over `ramp_years`. Evaluated quarterly, averaged per year.
#' @return matrix KPI x year.
value_profile <- function(result, ready, cfg, base, years) {
  vm <- ifelse(is.na(result$value_musd), 0, result$value_musd)
  full <- vm * cfg$realization * driver_factor(result$value_driver, cfg, base)
  r <- ready[result$id]
  out <- vapply(years, function(y) {
    q <- y + (0:3 + 0.5) / 4
    ramp <- vapply(r, function(ri) {
      mean(pmin(1, pmax(0, (q - ri - cfg$adoption_delay) / cfg$ramp_years)))
    }, numeric(1))
    full * ramp
  }, numeric(nrow(result)))
  out <- matrix(out, nrow = nrow(result), dimnames = list(result$id, years))
  attr(out, "run_rate") <- stats::setNames(full, result$id)
  out
}

#' Run the full model for one scenario
#' @param data roadmap data list.
#' @param graph output of build_graph().
#' @param cfg named list of parameter values (scenario).
#' @param base named list of base-case values (for driver factors).
run_model <- function(data, graph, cfg, base = cfg, resources = NULL) {
  start <- floor(min(q_to_time(data$enabler$start_q)))
  years <- seq(start, cfg$horizon_end)
  sched <- schedule(data$enabler, cfg, resources)
  ready <- result_ready(graph, sched)
  parts <- cost_parts(data$enabler, cfg, years, sched)
  cost <- parts$capex + parts$people + parts$opex
  plan_cfg <- cfg
  plan_cfg$resource_multiplier <- 1
  plan_cost <- cost_profile(data$enabler, plan_cfg, years)
  value <- value_profile(data$result, ready, cfg, base, years)
  list(
    cfg = cfg, years = years, start = start, resources = resources,
    schedule = sched, ready = ready,
    issues = date_issues(data, stats::setNames(sched$end, sched$id)),
    late = result_issues(data, graph, ready, stats::setNames(sched$end, sched$id)),
    cost = cost, cost_parts = parts, plan_cost = plan_cost, value = value,
    run_rate = attr(value, "run_rate"),
    discount = 1 / (1 + cfg$discount_rate)^(years - start),
    graph = graph
  )
}

#' Portfolio figures for a set of results
#'
#' @param w optional weight per result, e.g. a process's share of shared results.
#'
#' Enabler costs are allocated to the KPIs through the graph's allocation
#' shares, so the full KPI set carries the full cost.
portfolio <- function(model, result_ids = colnames(model$graph$alloc), w = NULL) {
  if (is.null(w)) w <- rep(1, length(result_ids))
  w <- as.numeric(w)
  share <- as.vector(model$graph$alloc[, result_ids, drop = FALSE] %*% w)
  cost <- colSums(model$cost * share)
  value <- colSums(model$value[result_ids, , drop = FALSE] * w)
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
    run_rate = sum(model$run_rate[result_ids] * w)
  )
}

#' Per-enabler cost to horizon, and cost allocated to one KPI
enabler_costs <- function(model, result_id = NULL) {
  tot <- rowSums(model$cost)
  if (is.null(result_id)) return(tot)
  tot * model$graph$alloc[, result_id]
}

#' Direct value attributed to each enabler (by normalised link weight)
enabler_direct_value <- function(model, result_ids = colnames(model$graph$weight)) {
  as.vector(model$graph$weight[, result_ids, drop = FALSE] %*% rowSums(model$value[result_ids, , drop = FALSE])) |>
    stats::setNames(rownames(model$graph$weight))
}

#' One-at-a-time sensitivity of NPV
#'
#' Each lever is set to its low and high value while the others keep the
#' scenario value.
#' @param cfg_table config data frame (low / high / in_sensitivity).
#' @return data frame sorted by NPV spread, largest first.
tornado <- function(data, graph, cfg, base, cfg_table, result_ids = graph$results, resources = NULL) {
  levers <- cfg_table[cfg_table$in_sensitivity, ]
  if (!is.null(resources)) levers <- levers[levers$key != "resource_multiplier", ]
  npv_at <- function(key, v) {
    s <- cfg
    s[[key]] <- v
    portfolio(run_model(data, graph, s, base, resources), result_ids)$npv
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

#' Back-calculate the resources needed to meet dates
#'
#' Start dates are fixed and an enabler's duration depends only on its own
#' resources (duration = plan x r^-s), so the multiplier each enabler needs
#' has a closed form: r = k^(-1/s), where k is the share of the plan
#' duration it may take.
#'
#' Deadlines per scope:
#' * "due": every result by its own due date (end of its due month).
#' * "milestones" / "results": every milestone / every result by `target`.
#' * "enablers": every enabler goes live by `target`.
#' For a result, the deadline applies to its required enablers and all
#' their prerequisites (the result is ready only when all are live).
#' pull_prereqs: an accelerated enabler's prerequisites are accelerated
#' too, so none goes live after it (no new late dependencies).
#'
#' Enablers that cannot make it (rigid, starting after the deadline, below
#' one quarter, or needing more than `r_max`) are listed as blockers; they
#' get the most they can usefully take.
#' @return list(resources, blockers, feasible, target, scope).
solve_target <- function(data, graph, cfg, target = NA_real_,
                         scope = c("due", "milestones", "results", "enablers"),
                         pull_prereqs = TRUE, r_max = 5) {
  scope <- match.arg(scope)
  e <- data$enabler
  plan <- schedule(e, utils::modifyList(cfg, list(resource_multiplier = 1)))
  ids <- e$id
  k_req <- stats::setNames(rep(1, length(ids)), ids)
  need <- function(i, deadline) {
    k <- (deadline - plan$start[i]) / plan$duration_plan[i]
    k_req[[ids[i]]] <<- min(k_req[[ids[i]]], k)
  }
  if (scope == "enablers") {
    for (i in which(plan$end > target + 1e-9)) need(i, target)
  } else {
    r <- data$result
    if (scope == "milestones") r <- r[r$kind == "milestone", ]
    deadline <- if (scope == "due") due_to_time(r$due) else rep(target, nrow(r))
    for (j in seq_len(nrow(r))) {
      ch <- graph$chains[[r$id[j]]]
      for (en in c(ch$direct, ch$foundation)) {
        i <- match(en, ids)
        if (plan$end[i] > deadline[j] + 1e-9) need(i, deadline[j])
      }
    }
  }
  r_for <- function(i) {
    k <- k_req[[ids[i]]]
    sc <- plan$scalability[i]
    floor_k <- min(plan$duration_plan[i], 0.25) / plan$duration_plan[i]
    if (k >= 1 - 1e-9) return(list(r = 1, why = NA_character_))
    if (k <= 0) return(list(r = 1, why = "starts after the deadline"))
    if (sc == 0) return(list(r = 1, why = "rigid (scalability 0)"))
    if (k < floor_k - 1e-9) return(list(r = min(r_max, floor_k^(-1 / sc)), why = "would need less than one quarter"))
    rr <- k^(-1 / sc)
    if (rr > r_max + 1e-9) return(list(r = r_max, why = sprintf("needs x%.1f resources (limit x%.0f)", rr, r_max)))
    list(r = rr, why = NA_character_)
  }
  dep <- data$enabler_dependency
  for (iter in seq_len(length(ids) + 1)) {
    sol <- lapply(seq_along(ids), r_for)
    res <- stats::setNames(vapply(sol, `[[`, 1, "r"), ids)
    if (!pull_prereqs) break
    sch <- schedule(e, cfg, res)
    end <- stats::setNames(sch$end, ids)
    changed <- FALSE
    for (d in seq_len(nrow(dep))) {
      a <- dep$enabler_id[d]
      p <- dep$requires_id[d]
      ip <- match(p, ids)
      if (res[[a]] > 1 + 1e-9 && end[[p]] > end[[a]] + 1e-6) {
        k <- (end[[a]] - plan$start[ip]) / plan$duration_plan[ip]
        if (k < k_req[[p]] - 1e-9) {
          k_req[[p]] <- k
          changed <- TRUE
        }
      }
    }
    if (!changed) break
  }
  why <- vapply(sol, `[[`, "", "why")
  blockers <- data.frame(enabler_id = ids[!is.na(why)], reason = why[!is.na(why)], stringsAsFactors = FALSE)
  list(resources = res, blockers = blockers, feasible = !nrow(blockers), target = target, scope = scope)
}
