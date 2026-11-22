# Cost and value model v3. Pure functions: data + graph + config values +
# maturity targets in, yearly profiles out. All money in $M.
#
# Logic: each process has a target digital maturity (M1 manual .. M5
# adaptive). Milestones up to that level are in scope; the enablers they
# require (and their foundations) are the investment. As milestones become
# ready, the metrics they move climb their impact curve, and that impact is
# the value.

overlap <- function(a, b, y) pmax(0, pmin(b, y + 1) - pmax(a, y))

#' Join concepts onto enablers and derive their FTE
#'
#' Enablers are classified group > subgroup > concept > enabler. FTEs are
#' entered on the concept as an average over its build window (first start
#' to last go-live of its enablers) and spread over its enablers in
#' proportion to their build duration, so total effort is kept:
#' enabler FTE = concept FTE x window / sum of enabler durations.
#' Also marks metrics that carry a measure and types the maturity levels.
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
  z <- function(x) ifelse(is.na(x), 0, x)
  e$fte_internal <- unname(z(cpt$fte_internal[i]) * k)
  e$fte_sme <- unname(z(if (is.null(cpt$fte_sme)) rep(0, nrow(cpt)) else cpt$fte_sme)[i] * k)
  e$fte_partner <- unname(z(cpt$fte_partner[i]) * k)
  grp_order <- c("people", "digital", "data", "infra")
  e <- e[order(match(e$enabler_group, grp_order), e$concept, e$start_q, e$id), ]
  rownames(e) <- NULL
  tables$enabler <- e
  if (is.null(tables$curve) || !nrow(tables$curve)) tables$curve <- DEFAULT_CURVES
  mt <- tables$metric
  mt$measured <- !is.na(mt$baseline) & !is.na(mt$target)
  tables$metric <- mt
  for (k in c("current_level", "target_level")) tables$process[[k]] <- as.integer(tables$process[[k]])
  tables$milestone$level <- as.integer(tables$milestone$level)
  tables$enabler$level <- as.integer(tables$enabler$level)
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
#' * people: concept FTE spread on the enabler x resource multiplier, during
#'   the build, in three parts: the internal dedicated team at the loaded FTE
#'   cost; part-time subject-matter experts (SMEs) at the loaded FTE cost x
#'   `sme_cost_factor` (1 = fully charged, 0 = absorbed by the business);
#'   partners at the FTE cost plus the partner premium
#' * opex: from the scenario go-live to the horizon
#' Everything is multiplied by the cost multiplier lever.
#' @return list of matrices (enabler x year): capex, people (= people_internal
#'   + people_sme + people_partner), opex, and the three people parts.
cost_parts <- function(enabler, cfg, years, sched = schedule(enabler, cfg)) {
  s <- sched$start
  f <- sched$end
  m <- cfg$cost_multiplier %||% 1
  horizon <- max(years) + 1
  rate <- function(fte, k) fte * cfg$fte_cost * k / 1000 * sched$people_factor * m
  sme <- if (is.null(enabler$fte_sme)) rep(0, nrow(enabler)) else enabler$fte_sme
  p_int <- rate(enabler$fte_internal, 1)
  p_sme <- rate(sme, cfg$sme_cost_factor %||% 1)
  p_par <- rate(enabler$fte_partner, 1 + cfg$partner_premium)
  capex <- enabler$capex_musd * m * sched$cost_factor / sched$duration
  mk <- function(f_year) {
    matrix(vapply(years, f_year, numeric(nrow(enabler))), nrow = nrow(enabler),
           dimnames = list(enabler$id, years))
  }
  out <- list(
    capex = mk(function(y) capex * overlap(s, f, y)),
    people_internal = mk(function(y) p_int * overlap(s, f, y)),
    people_sme = mk(function(y) p_sme * overlap(s, f, y)),
    people_partner = mk(function(y) p_par * overlap(s, f, y)),
    opex = mk(function(y) enabler$opex_musd_yr * m * overlap(f, horizon, y))
  )
  out$people <- out$people_internal + out$people_sme + out$people_partner
  out[c("capex", "people", "opex", "people_internal", "people_sme", "people_partner")]
}

#' FTE working on enabler builds per year, by kind (enabler x year matrices)
#'
#' Average FTE over each year: concept FTE spread on the enabler x the
#' scenario resource multiplier, during the scenario build.
#' @param factor optional per-enabler scope factor (0 = not needed).
fte_parts <- function(enabler, years, sched, factor = NULL) {
  b <- matrix(vapply(years, function(y) overlap(sched$start, sched$end, y), numeric(nrow(enabler))),
              nrow = nrow(enabler), dimnames = list(enabler$id, years))
  f <- sched$people_factor * (if (is.null(factor)) 1 else factor[enabler$id])
  sme <- if (is.null(enabler$fte_sme)) rep(0, nrow(enabler)) else enabler$fte_sme
  list(internal = b * enabler$fte_internal * f, sme = b * sme * f, partner = b * enabler$fte_partner * f)
}

#' Milestone ready date: latest go-live across its required enablers and their prerequisites
milestone_ready <- function(graph, sched) {
  end_t <- stats::setNames(sched$end, sched$id)
  vapply(graph$chains, function(ch) max(end_t[c(ch$direct, ch$foundation)]), numeric(1))
}

#' Factor applied to a metric's value from its driver parameter
driver_factor <- function(driver, cfg, base) {
  vapply(driver, function(d) {
    if (is.na(d) || d == "none" || is.null(cfg[[d]])) 1 else cfg[[d]] / base[[d]]
  }, numeric(1), USE.NAMES = FALSE)
}

#' Effective maturity targets
#'
#' Starts from the base targets in the process sheet, applies the scenario
#' targets, and keeps each between the current level and M5. Processes left
#' out of the scope stay at their current level (not transformed).
#' @param targets optional named vector of levels (1..5) by process id.
#' @param scope optional process ids in scope.
effective_targets <- function(data, targets = NULL, scope = NULL) {
  p <- data$process
  t <- stats::setNames(p$target_level, p$id)
  if (!is.null(targets)) {
    k <- intersect(names(targets), p$id)
    t[k] <- as.integer(targets[k])
  }
  cur <- stats::setNames(p$current_level, p$id)
  t <- pmin(pmax(t, cur), 5L)
  if (!is.null(scope)) t[!names(t) %in% scope] <- cur[!names(t) %in% scope]
  t
}

#' Milestones in scope: level at or below their process's target
milestones_in_scope <- function(data, targets) {
  ms <- data$milestone
  stats::setNames(ms$level <= targets[ms$process_id], ms$id)
}

#' When each process reaches each level of its path
#'
#' A process reaches level L when all its milestones above its current
#' level and up to L are ready. A level with no milestone of its own is
#' reached with the next level up that has one (or the one below, at the top).
#' @return data frame process_id, level, t (NA = reached from the start).
process_path <- function(data, ready, targets) {
  p <- data$process
  ms <- data$milestone
  do.call(rbind, lapply(seq_len(nrow(p)), function(i) {
    cur <- p$current_level[i]
    tgt <- targets[[p$id[i]]]
    if (tgt <= cur) return(NULL)
    lv <- (cur + 1):tgt
    own <- vapply(lv, function(l) any(ms$process_id == p$id[i] & ms$level == l), TRUE)
    raw <- vapply(lv, function(l) {
      k <- ms$id[ms$process_id == p$id[i] & ms$level > cur & ms$level <= l]
      if (length(k)) max(ready[k]) else NA_real_
    }, numeric(1))
    # a level with no milestone of its own is reached with the next level that has one
    t <- vapply(seq_along(lv), function(j) {
      nxt <- which(own & seq_along(lv) >= j)
      if (length(nxt)) raw[nxt[1]] else raw[j]
    }, numeric(1))
    data.frame(process_id = p$id[i], level = lv, t = t, stringsAsFactors = FALSE)
  }))
}

#' Steps of each metric up its impact curve
#'
#' A metric climbs through the levels of the milestones linked to it (in
#' scope, i.e. within their own process's target). It reaches level L when
#' every linked milestone up to L is ready. Each step adds
#' (curve(L) - curve(previous)) / (curve(M5) - curve(current)) of the
#' metric's value, so a process at M5 gets 100% and staying at the current
#' level gets 0%.
#' @return list by metric of data frames (level, t, delta).
metric_steps <- function(data, graph, ready, in_scope) {
  mt <- data$metric
  ms <- data$milestone
  cur_of <- stats::setNames(data$process$current_level, data$process$id)
  out <- lapply(seq_len(nrow(mt)), function(i) {
    cur <- cur_of[[mt$process_id[i]]]
    cv <- graph$curves[mt$curve_id[i], ]
    span <- cv[5] - cv[cur]
    k <- graph$metric_ms[[mt$id[i]]]
    k <- k[in_scope[k]]
    lv <- ms$level[match(k, ms$id)]
    steps <- sort(unique(lv[lv > cur]))
    if (!length(steps) || span <= 1e-9) return(data.frame(level = integer(0), t = numeric(0), delta = numeric(0)))
    t <- vapply(steps, function(l) max(ready[k[lv <= l]]), numeric(1))
    prev <- c(cur, utils::head(steps, -1))
    data.frame(level = steps, t = t, delta = unname((cv[steps] - cv[prev]) / span))
  })
  stats::setNames(out, mt$id)
}

#' Yearly value of each metric
#'
#' Full value = value_musd x realisation x driver factor (from current
#' level to M5). Each step up the curve ramps linearly to its share of the
#' full value over the adoption time, from the date the step is reached.
#' Evaluated quarterly, averaged per year.
#' @return matrix metric x year, with attributes run_rate and impact.
value_profile <- function(metric, steps, cfg, base, years) {
  vm <- ifelse(is.na(metric$value_musd), 0, metric$value_musd)
  full <- vm * cfg$realization * driver_factor(metric$value_driver, cfg, base)
  a <- max(cfg$adoption_years, 1e-6)
  q <- as.vector(outer((0:3 + 0.5) / 4, years, "+"))
  out <- t(vapply(seq_len(nrow(metric)), function(i) {
    st <- steps[[metric$id[i]]]
    if (!nrow(st)) return(numeric(length(years)))
    ramp <- Reduce(`+`, lapply(seq_len(nrow(st)), function(j) st$delta[j] * pmin(1, pmax(0, (q - st$t[j]) / a))))
    full[i] * colMeans(matrix(ramp, nrow = 4))
  }, numeric(length(years))))
  out <- matrix(out, nrow = nrow(metric), dimnames = list(metric$id, years))
  impact <- vapply(metric$id, function(k) sum(steps[[k]]$delta), 0)
  attr(out, "run_rate") <- stats::setNames(full * impact, metric$id)
  attr(out, "impact") <- impact
  out
}

#' Which enablers the in-scope milestones need, at what cost factor
#'
#' An enabler is needed if an in-scope milestone requires it (directly or
#' as a prerequisite). Its cost counts in full when cost_basis is "fixed";
#' when "per_process" it scales with the processes it serves that need it:
#' (n / N)^scalability, where N counts every process with a milestone that
#' needs it (at any level).
#' @return list(factor, n, N) named by enabler.
scope_factors <- function(data, graph, in_scope) {
  ids <- graph$ids
  ms <- data$milestone
  chain_of <- lapply(graph$chains, function(ch) c(ch$direct, ch$foundation))
  serves <- lapply(stats::setNames(ids, ids), function(e) {
    k <- names(Filter(function(ch) e %in% ch, chain_of))
    list(all = unique(ms$process_id[ms$id %in% k]), on = unique(ms$process_id[ms$id %in% k & in_scope[ms$id]]))
  })
  N <- vapply(serves, function(x) length(x$all), 1L)
  n <- vapply(serves, function(x) length(x$on), 1L)
  e <- data$enabler[match(ids, data$enabler$id), ]
  sc <- pmin(pmax(ifelse(is.na(e$scalability), 0, e$scalability), 0), 2)
  per <- e$cost_basis == "per_process"
  f <- ifelse(n == 0, 0, ifelse(per & N > 0, (n / pmax(N, 1))^sc, 1))
  list(factor = stats::setNames(f, ids), n = stats::setNames(n, ids), N = stats::setNames(N, ids))
}

#' Run the full model for one scenario
#' @param cfg named list of parameter values (scenario).
#' @param base named list of base-case values (for driver factors).
#' @param resources optional per-enabler resource multipliers (solve_target()).
#' @param targets optional maturity targets by process (base targets otherwise).
#' @param scope optional process ids in scope; the others stay at their current level.
run_model <- function(data, graph, cfg, base = cfg, resources = NULL, targets = NULL, scope = NULL) {
  start <- floor(min(q_to_time(data$enabler$start_q)))
  years <- seq(start, cfg$horizon_end)
  tg <- effective_targets(data, targets, scope)
  sched <- schedule(data$enabler, cfg, resources)
  ready <- milestone_ready(graph, sched)
  ins <- milestones_in_scope(data, tg)
  parts <- cost_parts(data$enabler, cfg, years, sched)
  full_cost <- parts$capex + parts$people + parts$opex
  sf <- scope_factors(data, graph, ins)
  steps <- metric_steps(data, graph, ready, ins)
  value <- value_profile(data$metric, steps, cfg, base, years)
  end <- stats::setNames(sched$end, sched$id)
  # cost shared among the in-scope milestones only
  fl <- graph$flow[, ins, drop = FALSE]
  alloc <- fl / ifelse(rowSums(fl) > 0, rowSums(fl), 1)
  list(
    cfg = cfg, years = years, start = start, resources = resources, scope = scope,
    targets = tg, in_scope = ins, schedule = sched, ready = ready,
    path = process_path(data, ready, tg), steps = steps,
    issues = date_issues(data, end),
    late = milestone_issues(data, graph, ready, end, names(ins)[ins]),
    cost_parts = parts, full_cost = full_cost,
    cost = full_cost * sf$factor[rownames(full_cost)],
    fte = fte_parts(data$enabler, years, sched, sf$factor),
    scope_factor = sf$factor, scope_n = sf$n, scope_N = sf$N, alloc = alloc,
    value = value, run_rate = attr(value, "run_rate"), impact = attr(value, "impact"),
    metric_level = vapply(data$metric$id, function(k) {
      st <- steps[[k]]
      if (nrow(st)) max(st$level) else data$process$current_level[match(data$metric$process_id[data$metric$id == k], data$process$id)]
    }, 0L),
    discount = 1 / (1 + cfg$discount_rate)^(years - start),
    graph = graph
  )
}

#' Headline figures
#'
#' Value: every metric at the impact its milestones reach. Cost: the
#' enablers the in-scope milestones need.
portfolio <- function(model) {
  value <- colSums(model$value)
  cost <- colSums(model$cost)
  net <- value - cost
  cum <- cumsum(net)
  pay <- which(cum >= 0)
  ids <- names(model$in_scope)[model$in_scope]
  list(
    years = model$years, value = unname(value), cost = unname(cost),
    net = unname(net), cum_net = unname(cum),
    npv = sum(net * model$discount),
    total_value = sum(value), total_cost = sum(cost),
    roi = if (sum(cost) > 0) (sum(value) - sum(cost)) / sum(cost) else NA_real_,
    payback = if (length(pay)) model$years[pay[1]] else NA_integer_,
    run_rate = sum(model$run_rate),
    milestones = ids, enablers = names(which(model$scope_factor > 0)),
    last_ready = if (length(ids)) max(model$ready[ids]) else NA_real_
  )
}

#' Cost attributed to milestones (in scope)
#'
#' Each needed enabler's cost is split across the in-scope milestones that
#' require it by weight; foundations pass theirs on through their dependents.
attributed_cost <- function(model, milestone_ids) {
  ids <- intersect(milestone_ids, colnames(model$alloc))
  tot <- rowSums(model$cost)
  share <- rowSums(model$alloc[, ids, drop = FALSE])
  by <- tot * share
  list(cost = sum(by), by_enabler = by,
       yearly = colSums(model$cost * share))
}

#' Value, cost and NPV of a process: its metrics and its in-scope milestones
process_figures <- function(data, model, pid) {
  k <- metrics_of_process(data, pid)
  m <- milestones_of_process(data, pid)
  a <- attributed_cost(model, m)
  v <- colSums(model$value[k, , drop = FALSE])
  list(value = sum(v), run_rate = sum(model$run_rate[k]), cost = a$cost,
       npv = sum((v - a$yearly) * model$discount))
}

#' Back-calculate the resources needed to meet dates
#'
#' Start dates are fixed and an enabler's duration depends only on its own
#' resources (duration = plan x r^-s), so the multiplier each enabler needs
#' has a closed form: r = k^(-1/s), where k is the share of the plan
#' duration it may take.
#'
#' Deadlines per scope:
#' * "due": every milestone in scope by its own due date (end of its due month).
#' * "date": every milestone in scope by a common `target` date.
#' For a milestone, the deadline applies to its required enablers and all
#' their prerequisites (the milestone is ready only when all are live).
#' Milestones in scope follow the maturity `targets` (base targets when NULL).
#' pull_prereqs: an accelerated enabler's prerequisites are accelerated
#' too, so none goes live after it (no new late dependencies).
#'
#' Enablers that cannot make it (rigid, starting after the deadline, below
#' one quarter, or needing more than `r_max`) are listed as blockers; they
#' get the most they can usefully take.
#' @return list(resources, blockers, feasible, target, scope).
solve_target <- function(data, graph, cfg, target = NA_real_,
                         scope = c("due", "date"),
                         pull_prereqs = TRUE, r_max = 5, targets = NULL) {
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
    ins <- milestones_in_scope(data, effective_targets(data, targets))
    r <- data$milestone[ins[data$milestone$id], ]
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
