# Cost and value model v2. Pure functions: data + graph + config values in,
# yearly profiles out. All money in $M.
#
# Logic: enablers make results possible; results generate value for the
# processes that hold them. The process scope ("what if we transform only
# these processes") sets which results count and which enablers are needed.

overlap <- function(a, b, y) pmax(0, pmin(b, y + 1) - pmax(a, y))

#' Join concepts onto enablers and derive their FTE
#'
#' Enablers are classified group > subgroup > concept > enabler. FTEs are
#' entered on the concept as an average over its build window (first start
#' to last go-live of its enablers) and spread over its enablers in
#' proportion to their build duration, so total effort is kept:
#' enabler FTE = concept FTE x window / sum of enabler durations.
#' Also marks results that carry a measure (baseline -> target).
#' @param tables named list of tables (from the workbook or the database).
prepare_data <- function(tables) {
  e <- tables$enabler
  cpt <- tables$concept
  i <- match(e$concept_id, cpt$id)
  e$enabler_group <- cpt$enabler_group[i]
  e$subgroup <- ifelse(is.na(cpt$subgroup[i]), "", cpt$subgroup[i])
  e$concept <- cpt$name[i]
  s <- q_to_time(e$start_q)
  d <- pmax(q_to_time(e$end_q, end = TRUE) - s, 0.25)
  window <- tapply(s + d, e$concept_id, max) - tapply(s, e$concept_id, min)
  dsum <- tapply(d, e$concept_id, sum)
  k <- as.vector((window / dsum)[e$concept_id])
  e$fte_internal <- unname(cpt$fte_internal[i] * k)
  e$fte_partner <- unname(cpt$fte_partner[i] * k)
  grp_order <- c("people", "digital", "data", "infra")
  e <- e[order(match(e$enabler_group, grp_order), e$concept, e$start_q, e$id), ]
  rownames(e) <- NULL
  tables$enabler <- e
  r <- tables$result
  r$measured <- !is.na(r$baseline) & !is.na(r$target)
  tables$result <- r
  if (is.null(tables$result_process)) {
    tables$result_process <- data.frame(result_id = character(0), process_id = character(0), share = numeric(0))
  }
  tables
}

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

#' Yearly cost of each enabler, split by type (before scope)
#'
#' * capex: capex x effort factor, spread evenly over the scenario build
#' * people: concept FTE spread on the enabler (partner at a premium) x
#'   resource multiplier, during the build
#' * opex: from the scenario go-live to the horizon
#' All three are multiplied by the cost multiplier lever.
#' @return list of three matrices (enabler x year): capex, people, opex.
cost_parts <- function(enabler, cfg, years, sched = schedule(enabler, cfg)) {
  s <- sched$start
  f <- sched$end
  m <- cfg$cost_multiplier %||% 1
  horizon <- max(years) + 1
  people <- (enabler$fte_internal * cfg$fte_cost +
             enabler$fte_partner * cfg$fte_cost * (1 + cfg$partner_premium)) / 1000 *
    sched$people_factor * m
  capex <- enabler$capex_musd * m * sched$cost_factor / sched$duration
  mk <- function(f_year) {
    matrix(vapply(years, f_year, numeric(nrow(enabler))), nrow = nrow(enabler),
           dimnames = list(enabler$id, years))
  }
  list(
    capex = mk(function(y) capex * overlap(s, f, y)),
    people = mk(function(y) people * overlap(s, f, y)),
    opex = mk(function(y) enabler$opex_musd_yr * m * overlap(f, horizon, y))
  )
}

#' Average FTE working on enabler builds per year (scenario resources)
fte_profile <- function(enabler, years, sched) {
  b <- vapply(years, function(y) overlap(sched$start, sched$end, y), numeric(nrow(enabler)))
  b <- matrix(b, nrow = nrow(enabler))
  data.frame(year = years,
             internal = colSums(b * enabler$fte_internal * sched$people_factor),
             partner = colSums(b * enabler$fte_partner * sched$people_factor))
}

#' Result ready date: latest go-live across its required enablers and their prerequisites
result_ready <- function(graph, sched) {
  end_t <- stats::setNames(sched$end, sched$id)
  vapply(graph$chains, function(ch) max(end_t[c(ch$direct, ch$foundation)]), numeric(1))
}

#' Factor applied to a result's value from its driver parameter
driver_factor <- function(driver, cfg, base) {
  vapply(driver, function(d) {
    if (is.na(d) || d == "none" || is.null(cfg[[d]])) 1 else cfg[[d]] / base[[d]]
  }, numeric(1), USE.NAMES = FALSE)
}

#' Yearly value of each result
#'
#' Full value = value_musd x realisation x driver factor. Once the result is
#' ready, value ramps linearly to full over the adoption time (the
#' `adoption_years` lever). Evaluated quarterly, averaged per year.
#' @return matrix result x year, with attribute run_rate.
value_profile <- function(result, ready, cfg, base, years) {
  vm <- ifelse(is.na(result$value_musd), 0, result$value_musd)
  full <- vm * cfg$realization * driver_factor(result$value_driver, cfg, base)
  r <- ready[result$id]
  a <- max(cfg$adoption_years, 1e-6)
  out <- vapply(years, function(y) {
    q <- y + (0:3 + 0.5) / 4
    ramp <- vapply(r, function(ri) mean(pmin(1, pmax(0, (q - ri) / a))), numeric(1))
    full * ramp
  }, numeric(nrow(result)))
  out <- matrix(out, nrow = nrow(result), dimnames = list(result$id, years))
  attr(out, "run_rate") <- stats::setNames(full, result$id)
  out
}

#' Scope: which results count, which enablers are needed, at what cost
#'
#' A result counts with the share its in-scope processes hold. An enabler
#' is needed if an in-scope result requires it (directly or as a
#' prerequisite). Its cost then counts in full when cost_basis is "fixed";
#' when "per_process" it scales with the processes it serves that are in
#' scope: (n / N)^scalability (0 = fixed, 1 = proportional).
#' @param scope process ids in scope (all when NULL).
#' @return list(w = result weights, factor = enabler cost factors, n, N).
scope_factors <- function(data, graph, scope = NULL) {
  pids <- colnames(graph$share)
  if (is.null(scope)) scope <- pids
  w <- rowSums(graph$share[, intersect(scope, pids), drop = FALSE])
  ids <- graph$ids
  # processes each enabler serves: those holding any result whose chain contains it
  serves <- lapply(stats::setNames(ids, ids), function(e) {
    rs <- names(Filter(function(ch) e %in% c(ch$direct, ch$foundation), graph$chains))
    pids[colSums(graph$share[rs, , drop = FALSE]) > 0]
  })
  needed_rs <- names(w)[w > 0]
  needed <- unique(unlist(lapply(graph$chains[needed_rs], function(ch) c(ch$direct, ch$foundation))))
  N <- vapply(serves, length, 1L)
  n <- vapply(serves, function(p) sum(p %in% scope), 1L)
  e <- data$enabler[match(ids, data$enabler$id), ]
  sc <- pmin(pmax(ifelse(is.na(e$scalability), 0, e$scalability), 0), 2)
  per <- e$cost_basis == "per_process"
  f <- ifelse(!ids %in% needed, 0, ifelse(per & N > 0, (n / pmax(N, 1))^sc, 1))
  list(w = w, factor = stats::setNames(f, ids), n = stats::setNames(n, ids), N = stats::setNames(N, ids))
}

#' Run the full model for one scenario and one process scope
#' @param cfg named list of parameter values (scenario).
#' @param base named list of base-case values (for driver factors).
#' @param resources optional per-enabler resource multipliers (solve_target()).
#' @param scope process ids in scope (all when NULL).
run_model <- function(data, graph, cfg, base = cfg, resources = NULL, scope = NULL) {
  start <- floor(min(q_to_time(data$enabler$start_q)))
  years <- seq(start, cfg$horizon_end)
  sched <- schedule(data$enabler, cfg, resources)
  ready <- result_ready(graph, sched)
  parts <- cost_parts(data$enabler, cfg, years, sched)
  full_cost <- parts$capex + parts$people + parts$opex
  sf <- scope_factors(data, graph, scope)
  value <- value_profile(data$result, ready, cfg, base, years)
  list(
    cfg = cfg, years = years, start = start, resources = resources, scope = scope,
    schedule = sched, ready = ready,
    issues = date_issues(data, stats::setNames(sched$end, sched$id)),
    late = result_issues(data, graph, ready, stats::setNames(sched$end, sched$id)),
    cost_parts = parts, full_cost = full_cost,
    cost = full_cost * sf$factor[rownames(full_cost)],
    scope_w = sf$w, scope_factor = sf$factor, scope_n = sf$n, scope_N = sf$N,
    value = value, run_rate = attr(value, "run_rate"),
    discount = 1 / (1 + cfg$discount_rate)^(years - start),
    graph = graph
  )
}

#' Headline figures for the model's scope
#'
#' Value: in-scope results at their in-scope share. Cost: the enablers those
#' results need, per-process enablers scaled to the scope.
portfolio <- function(model) {
  w <- model$scope_w
  value <- colSums(model$value[names(w), , drop = FALSE] * w)
  cost <- colSums(model$cost)
  net <- value - cost
  cum <- cumsum(net)
  pay <- which(cum >= 0)
  ids <- names(w)[w > 0]
  list(
    years = model$years, value = unname(value), cost = unname(cost),
    net = unname(net), cum_net = unname(cum),
    npv = sum(net * model$discount),
    total_value = sum(value), total_cost = sum(cost),
    roi = if (sum(cost) > 0) (sum(value) - sum(cost)) / sum(cost) else NA_real_,
    payback = if (length(pay)) model$years[pay[1]] else NA_integer_,
    run_rate = sum(model$run_rate[names(w)] * w),
    results = ids, enablers = names(which(model$scope_factor > 0)),
    last_ready = if (length(ids)) max(model$ready[ids]) else NA_real_
  )
}

#' Cost attributed to results (share of the full roadmap cost)
#'
#' Each enabler's cost is split across the results that require it by
#' weight; foundations pass theirs on through their dependents.
#' @param w optional weights (e.g. a process's share of each result).
attributed <- function(model, result_ids, w = rep(1, length(result_ids))) {
  tot <- rowSums(model$full_cost)
  share <- as.vector(model$graph$alloc[, result_ids, drop = FALSE] %*% w)
  value <- sum(rowSums(model$value[result_ids, , drop = FALSE]) * w)
  cost <- sum(tot * share)
  net <- colSums(model$value[result_ids, , drop = FALSE] * w) - colSums(model$full_cost * share)
  list(value = value, cost = cost, npv = sum(net * model$discount),
       run_rate = sum(model$run_rate[result_ids] * w),
       by_enabler = stats::setNames(tot * share, names(tot)))
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
#' * "date": every result by a common `target` date.
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
                         scope = c("due", "date"),
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
  {
    r <- data$result
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
