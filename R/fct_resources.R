# Resources per year (cash, internal team, SMEs, partners) and the audit
# workbook of the cash flow. Pure functions of a run_model() result.

#' Cash and people per year, for the enablers the scenario needs
#' @return data frame: year, capex, people_internal, people_sme, people_partner,
#'   opex, cash (all $M), fte_internal, fte_sme, fte_partner (average FTE).
resources_table <- function(model) {
  f <- model$scope_factor
  cs <- function(m) unname(colSums(m * f[rownames(m)]))
  cp <- model$cost_parts
  out <- data.frame(year = model$years,
                    capex = cs(cp$capex), people_internal = cs(cp$people_internal),
                    people_sme = cs(cp$people_sme), people_partner = cs(cp$people_partner),
                    opex = cs(cp$opex))
  out$cash <- out$capex + out$people_internal + out$people_sme + out$people_partner + out$opex
  out$fte_internal <- unname(colSums(model$fte$internal))
  out$fte_sme <- unname(colSums(model$fte$sme))
  out$fte_partner <- unname(colSums(model$fte$partner))
  out
}

#' People and cash by concept (FTE-years over the horizon)
resources_by_concept <- function(data, model) {
  e <- data$enabler
  k <- e$concept_id
  sm <- function(m) tapply(rowSums(m)[e$id], k, sum)
  cash <- tapply(rowSums(model$cost)[e$id], k, sum)
  cpt <- data$concept[data$concept$id %in% unique(k), ]
  x <- data.frame(id = cpt$id, name = cpt$name, group = cpt$enabler_group,
                  internal = as.vector(sm(model$fte$internal)[cpt$id]), sme = as.vector(sm(model$fte$sme)[cpt$id]),
                  partner = as.vector(sm(model$fte$partner)[cpt$id]), cash = as.vector(cash[cpt$id]),
                  stringsAsFactors = FALSE)
  x <- x[x$cash > 1e-9 | x$internal + x$sme + x$partner > 1e-9, ]
  x[order(match(x$group, GROUPS$id), -x$cash), ]
}

#' Stacked yearly bars (SVG)
#' @param series named list of numeric vectors (same length as years), bottom first.
#' @param cls CSS classes, one per series.
stack_chart <- function(years, series, cls, fmt = function(v) formatC(v, format = "f", digits = 0),
                        unit = "", W = 760, H = 240) {
  L <- 52; R <- 16; T <- 14; B <- 28
  tot <- Reduce(`+`, series)
  hi <- max(tot, 1e-9) * 1.08
  sx <- function(i) L + (i - 0.5) / length(years) * (W - L - R)
  sy <- function(v) T + (hi - v) / hi * (H - T - B)
  bw <- (W - L - R) / length(years) * 0.56
  o <- character(0)
  for (t in nice_ticks(0, hi, 4)) o <- c(o, sprintf('<line class="ch-grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="ch-ax" x="%d" y="%.1f" text-anchor="end">%s</text>',
    L, W - R, sy(t), sy(t), L - 8, sy(t) + 3.5, fmt(t)))
  for (i in seq_along(years)) {
    base <- 0
    tip <- paste0("<b>", years[i], "</b>", paste(sprintf("<br>%s %s", names(series), vapply(series, function(s) fmt(s[i]), "")), collapse = ""),
                  sprintf("<br><b>total %s</b>", fmt(tot[i])))
    for (j in seq_along(series)) {
      v <- series[[j]][i]
      if (v > 1e-9) o <- c(o, sprintf('<rect class="%s" x="%.1f" y="%.1f" width="%.1f" height="%.1f"/>',
                                     cls[j], sx(i) - bw / 2, sy(base + v), bw, sy(base) - sy(base + v)))
      base <- base + v
    }
    o <- c(o, sprintf('<rect class="rs-hit" x="%.1f" y="%d" width="%.1f" height="%d" data-tip="%s"/>',
                      sx(i) - bw / 2, T, bw, H - T - B, htmltools::htmlEscape(tip, attribute = TRUE)),
           sprintf('<text class="ch-ax" x="%.1f" y="%d" text-anchor="middle">%s</text>', sx(i), H - 8, years[i]))
    if (tot[i] > 1e-9) o <- c(o, sprintf('<text class="rs-tot" x="%.1f" y="%.1f" text-anchor="middle">%s</text>', sx(i), sy(tot[i]) - 5, fmt(tot[i])))
  }
  htmltools::HTML(sprintf('<svg class="chart rs-chart" viewBox="0 0 %d %d" role="img" aria-label="%s">%s</svg>',
                          W, H, paste(names(series), collapse = ", "), paste(o, collapse = "")))
}

#' Audit workbook of the scenario's cash flow
#'
#' Sheets: About (headline, formulas), Cashflow (year by year, with the
#' discounting), Assumptions, Targets, Value_by_metric and Value_steps (how
#' each metric's value is built), Value_by_year (metric x year), Cost_by_enabler
#' (inputs and scenario factors), Cost_by_year (enabler x year x type),
#' Milestones, Resources. Every total in Cashflow can be rebuilt from the
#' detail sheets.
#' @param base optional base-case values (for driver factors and comparison).
#' @param label scenario description written in About.
cashflow_workbook <- function(path, data, model, base = model$cfg, label = "Scenario") {
  p <- portfolio(model)
  cfg <- model$cfg
  yrs <- model$years
  r <- resources_table(model)
  cash <- data.frame(year = yrs, value = p$value, capex = r$capex, people_internal = r$people_internal,
                     people_sme = r$people_sme, people_partner = r$people_partner, opex = r$opex,
                     total_cost = p$cost, net = p$net, cumulative_net = p$cum_net,
                     discount_factor = model$discount, discounted_net = p$net * model$discount)
  cash$cumulative_discounted_net <- cumsum(cash$discounted_net)
  tot <- as.data.frame(lapply(cash, function(x) sum(x)))
  tot$year <- NA; tot$cumulative_net <- NA; tot$discount_factor <- NA; tot$cumulative_discounted_net <- NA
  cash_out <- rbind(cash, tot)
  cash_out$row <- c(rep("year", length(yrs)), "TOTAL")
  cash_out <- cash_out[, c("row", setdiff(names(cash_out), "row"))]

  about <- data.frame(item = c(
      "Scenario", "Exported", "Currency", "Investment (cost to horizon)", "Value to horizon", "Net present value",
      "ROI", "Payback year", "Discount rate", "Discounting", "Horizon",
      "Value formula", "Value step", "Cost formula", "People cost", "Scope"),
    value = c(
      label, format(Sys.time(), "%Y-%m-%d %H:%M"), "$M, nominal",
      sprintf("%.3f", p$total_cost), sprintf("%.3f", p$total_value), sprintf("%.3f", p$npv),
      if (is.na(p$roi)) "" else sprintf("%.4f", p$roi), if (is.na(p$payback)) "not within horizon" else as.character(p$payback),
      sprintf("%.4f", cfg$discount_rate), sprintf("factor = 1 / (1 + rate)^(year - %d), year-end convention on yearly totals", model$start),
      as.character(cfg$horizon_end),
      "metric value per year = value_musd x realization x driver factor x sum over steps (step share x adoption ramp); see Value_by_metric, Value_steps",
      "step share = (curve(level) - curve(previous level)) / (curve(M5) - curve(current level)); ramp = linear from the step date over adoption_years, averaged over the four quarters of the year",
      "enabler cost per year = (capex over the build + people during the build + opex from go-live) x cost_multiplier x scope factor; see Cost_by_enabler, Cost_by_year",
      "internal FTE x fte_cost + SME FTE x fte_cost x sme_cost_factor + partner FTE x fte_cost x (1 + partner_premium), $k/yr / 1000, x resource multiplier",
      "milestones at or below each process's target level are in scope; enablers needed by them (with foundations) are costed; per-process enablers scaled by (processes needing / served) ^ scalability"),
    stringsAsFactors = FALSE)

  ct <- data.frame(key = names(cfg), scenario = vapply(cfg, function(x) as.numeric(x)[1], 0),
                   base = vapply(names(cfg), function(k) as.numeric(base[[k]] %||% NA)[1], 0), stringsAsFactors = FALSE)
  ct$changed <- abs(ct$scenario - ct$base) > 1e-12

  pr <- data$process
  targets <- data.frame(process_id = pr$id, name = pr$name, owner = pr$owner, current_level = lvl(pr$current_level),
                        base_target = lvl(pr$target_level), scenario_target = lvl(model$targets[pr$id]),
                        milestones_in_scope = vapply(pr$id, function(i) sum(model$in_scope[milestones_of_process(data, i)]), 0L),
                        stringsAsFactors = FALSE)

  mt <- data$metric
  cur <- pr$current_level[match(mt$process_id, pr$id)]
  dfac <- driver_factor(mt$value_driver, cfg, base)
  cv <- model$graph$curves
  vm <- data.frame(metric_id = mt$id, name = mt$name, process_id = mt$process_id, unit = mt$unit,
                   baseline = mt$baseline, target_at_M5 = mt$target, value_musd_to_M5 = mt$value_musd,
                   value_driver = mt$value_driver, driver_factor = dfac, realization = cfg$realization,
                   full_value = mt$value_musd * cfg$realization * dfac, curve_id = mt$curve_id,
                   curve_at_current = cv[cbind(match(mt$curve_id, rownames(cv)), cur)], current_level = lvl(cur),
                   level_reached = lvl(model$metric_level[mt$id]), impact_share = unname(model$impact[mt$id]),
                   run_rate = unname(model$run_rate[mt$id]), value_to_horizon = unname(rowSums(model$value)[mt$id]),
                   stringsAsFactors = FALSE)
  steps <- do.call(rbind, lapply(mt$id, function(k) {
    st <- model$steps[[k]]
    if (!nrow(st)) return(NULL)
    data.frame(metric_id = k, level = lvl(st$level), reached = round(st$t, 4), reached_quarter = q_of(st$t),
               step_share = st$delta, step_value_at_full_adoption = vm$full_value[vm$metric_id == k] * st$delta,
               adoption_years = cfg$adoption_years, stringsAsFactors = FALSE)
  }))
  if (is.null(steps)) steps <- data.frame(metric_id = character(0))
  vy <- data.frame(metric_id = rep(mt$id, each = length(yrs)), year = rep(yrs, nrow(mt)),
                   value = as.vector(t(model$value[mt$id, , drop = FALSE])))

  e <- data$enabler
  sch <- model$schedule[match(e$id, model$schedule$id), ]
  f <- model$scope_factor[e$id]
  ce <- data.frame(enabler_id = e$id, name = e$name, group = e$enabler_group, concept = e$concept, level = lvl(e$level),
                   needed = f > 0, cost_basis = e$cost_basis, processes_needing = unname(model$scope_n[e$id]),
                   processes_served = unname(model$scope_N[e$id]), scope_factor = unname(f), scalability = e$scalability,
                   start = e$start_q, go_live_plan = e$end_q, go_live_scenario = q_of(sch$end),
                   resource_multiplier = sch$resources, effort_factor = sch$cost_factor,
                   capex_input = e$capex_musd, opex_input_per_year = e$opex_musd_yr,
                   fte_internal = e$fte_internal, fte_sme = e$fte_sme, fte_partner = e$fte_partner,
                   cost_to_horizon_in_scope = unname(rowSums(model$cost)[e$id]), stringsAsFactors = FALSE)
  cp <- model$cost_parts
  cy <- do.call(rbind, lapply(seq_along(yrs), function(j) {
    g <- function(m) unname(m[e$id, j] * f)
    data.frame(enabler_id = e$id, year = yrs[j], capex = g(cp$capex), people_internal = g(cp$people_internal),
               people_sme = g(cp$people_sme), people_partner = g(cp$people_partner), opex = g(cp$opex),
               fte_internal = unname(model$fte$internal[e$id, j]), fte_sme = unname(model$fte$sme[e$id, j]),
               fte_partner = unname(model$fte$partner[e$id, j]))
  }))
  cy$total_cost <- cy$capex + cy$people_internal + cy$people_sme + cy$people_partner + cy$opex
  cy <- cy[cy$total_cost > 1e-12 | cy$fte_internal + cy$fte_sme + cy$fte_partner > 1e-12, ]

  ms <- data$milestone
  late <- ms$id %in% model$late$milestone_id
  mso <- data.frame(milestone_id = ms$id, name = ms$name, process_id = ms$process_id, level = lvl(ms$level),
                    in_scope = unname(model$in_scope[ms$id]), due = ms$due, ready_quarter = q_of(model$ready[ms$id]),
                    late = late, moves_metrics = vapply(ms$id, function(i) paste(model$graph$ms_metrics[[i]], collapse = ", "), ""),
                    stringsAsFactors = FALSE)

  writexl::write_xlsx(list(About = about, Cashflow = cash_out, Assumptions = ct, Targets = targets,
                           Value_by_metric = vm, Value_steps = steps, Value_by_year = vy,
                           Cost_by_enabler = ce, Cost_by_year = cy, Milestones = mso, Resources = r), path)
  invisible(path)
}
