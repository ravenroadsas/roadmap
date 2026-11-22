# Detail panel (right of the canvas): metrics by default, or the selected
# milestone, metric, enabler or process.

#' Parse "milestone:R1" style selection strings
parse_selection <- function(x) {
  if (is.null(x) || !nzchar(x)) return(NULL)
  p <- strsplit(x, ":", fixed = TRUE)[[1]]
  if (length(p) != 2 || !p[1] %in% c("milestone", "metric", "enabler", "process")) return(NULL)
  list(type = p[1], id = p[2])
}

sel_link <- function(type, id, label, group = NULL) {
  btn <- tags$button(class = "lk", `data-sel` = paste0(type, ":", id), label)
  if (is.null(group)) return(btn)
  tags$span(class = "en", tags$i(class = paste("gdot", group)), btn)
}

#' Label / value pairs
facts <- function(...) {
  x <- list(...)
  x <- x[!vapply(x, is.null, TRUE)]
  tags$dl(class = "facts", lapply(names(x), function(n) tagList(tags$dt(n), tags$dd(x[[n]]))))
}
neg <- function(x) tags$span(class = "neg", x)
pos <- function(x) tags$span(class = "pos", x)
pname <- function(data, ids) data$process$name[match(ids, data$process$id)]

#' Panel for the selection, or the metrics by default
detail_ui <- function(data, model, sel) {
  if (is.null(sel)) return(detail_scope(data, model))
  switch(sel$type,
    milestone = detail_milestone(data, model, sel$id),
    metric = detail_metric(data, model, sel$id),
    enabler = detail_enabler(data, model, sel$id),
    process = detail_process(data, model, sel$id))
}

impact_bar <- function(x) tags$span(class = "ibar", tags$i(style = sprintf("width:%.0f%%", 100 * max(0, min(1, x)))))

detail_scope <- function(data, model) {
  mt <- data$metric
  v <- model$run_rate[mt$id]
  mt <- mt[order(-v), ]
  n_in <- sum(model$in_scope)
  n_late <- nrow(model$late)
  tagList(
    tags$p(class = "d-kicker", sprintf("%d metrics \u00b7 %d of %d milestones in scope%s", nrow(mt), n_in,
                                       length(model$in_scope), if (n_late) sprintf(" \u00b7 %d late", n_late) else "")),
    tags$p(class = "d-hint", "Value per year at full adoption, and the share of each metric's impact the maturity targets reach. Select anything to see what it depends on."),
    tags$ol(class = "rlist", lapply(seq_len(nrow(mt)), function(i) {
      k <- mt$id[i]
      tags$li(
        tags$button(class = "rrow", `data-sel` = paste0("metric:", k),
          tags$span(class = "rname", mt$name[i]),
          tags$span(class = "rval", if (model$run_rate[[k]] > 0) fmt_musd(model$run_rate[[k]]) else "\u2013"),
          tags$span(class = "rmeta", pname(data, mt$process_id[i]), " \u00b7 ", lvl(model$metric_level[[k]]), " \u00b7 ",
                    impact_bar(model$impact[[k]]), " ", fmt_pct(model$impact[[k]]))))
    })))
}

detail_milestone <- function(data, model, id) {
  m <- data$milestone[data$milestone$id == id, ]
  g <- model$graph
  ch <- g$chains[[id]]
  a <- attributed_cost(model, id)
  late <- model$late[model$late$milestone_id == id, ]
  ins <- model$in_scope[[id]]
  en <- data$enabler[match(c(ch$direct, ch$foundation), data$enabler$id), ]
  dir <- en$id %in% ch$direct
  ks <- g$ms_metrics[[id]]
  li <- g$level_issues[g$level_issues$milestone_id == id, ]
  tagList(
    tags$p(class = "d-kicker", "Milestone \u00b7 ", lvl(m$level), " ", LEVELS$name[m$level]),
    tags$h3(class = "d-title", m$name),
    facts(
      Process = pname(data, m$process_id),
      Scope = if (ins) sprintf("in scope (target %s)", lvl(model$targets[[m$process_id]]))
              else neg(sprintf("out of scope: target %s is below %s", lvl(model$targets[[m$process_id]]), lvl(m$level))),
      Due = m$due,
      Ready = if (nrow(late)) neg(paste(q_of(model$ready[[id]]), "\u00b7 late")) else q_of(model$ready[[id]]),
      `Attributed cost` = if (ins) fmt_musd(a$cost) else "\u2013"),
    if (nrow(late)) tags$p(class = "d-note neg", late$message),
    if (nrow(li)) tags$p(class = "d-note neg", paste(li$message, collapse = "; ")),
    tags$p(class = "d-section", if (length(ks)) "Moves" else "Moves no metric"),
    if (length(ks)) tags$ul(class = "elist", lapply(ks, function(k) tags$li(
      sel_link("metric", k, data$metric$name[data$metric$id == k])))),
    tags$p(class = "d-section", sprintf("Requires %d enabler%s", sum(dir), if (sum(dir) != 1) "s" else "")),
    tags$ul(class = "elist", lapply(which(dir), function(i) tags$li(
      sel_link("enabler", en$id[i], en$name[i], en$enabler_group[i]),
      tags$span(class = "emeta", lvl(en$level[i]), " \u00b7 ", fmt_pct(g$weight[en$id[i], id]))))),
    if (any(!dir)) tagList(
      tags$p(class = "d-section", sprintf("On %d foundation%s", sum(!dir), if (sum(!dir) != 1) "s" else "")),
      tags$ul(class = "elist quiet", lapply(which(!dir), function(i) tags$li(
        sel_link("enabler", en$id[i], en$name[i], en$enabler_group[i]),
        tags$span(class = "emeta", lvl(en$level[i]))))))
  )
}

detail_metric <- function(data, model, id) {
  k <- data$metric[data$metric$id == id, ]
  g <- model$graph
  cur <- data$process$current_level[data$process$id == k$process_id]
  cv <- g$curves[k$curve_id, ]
  st <- model$steps[[id]]
  ms <- data$milestone[data$milestone$id %in% g$metric_ms[[id]], ]
  ms <- ms[order(ms$level, ms$due), ]
  now <- if (k$measured) k$baseline + (k$target - k$baseline) * model$impact[[id]] else NA
  tagList(
    tags$p(class = "d-kicker", "Metric \u00b7 ", data$curve$name[data$curve$id == k$curve_id], " curve"),
    tags$h3(class = "d-title", k$name),
    facts(
      Process = pname(data, k$process_id),
      Measure = if (k$measured) paste0(fmt_num(k$baseline, k$unit), " today \u2192 ", fmt_num(k$target, k$unit), " at M5"),
      Reached = tagList(lvl(model$metric_level[[id]]), " \u00b7 ", fmt_pct(model$impact[[id]]), " of the impact",
                        if (!is.na(now)) paste0(" \u00b7 ", fmt_num(signif(now, 3), k$unit))),
      Value = if (model$run_rate[[id]] > 0) paste0(fmt_musd(model$run_rate[[id]]), " / yr of ", fmt_musd(k$value_musd), " at M5")
              else paste0("none at this maturity (", fmt_musd(k$value_musd), " at M5)"),
      Driver = c(oil_price = "oil price", fte_cost = "FTE cost", none = "none")[[k$value_driver]]),
    curve_mini(cv, cur, model$metric_level[[id]]),
    tags$p(class = "d-section", "Moved by"),
    tags$ul(class = "elist", lapply(seq_len(nrow(ms)), function(i) tags$li(
      sel_link("milestone", ms$id[i], ms$name[i]),
      tags$span(class = "emeta", lvl(ms$level[i]), if (!model$in_scope[[ms$id[i]]]) " \u00b7 out")))),
    if (nrow(st)) tags$p(class = "d-hint", paste(sprintf("%s from %s (+%s)", lvl(st$level), q_of(st$t), fmt_pct(st$delta)), collapse = " \u00b7 "))
  )
}

#' Small impact curve: % of impact by level, current and reached marked
curve_mini <- function(cv, cur, reached, W = 260, H = 96) {
  L <- 30; R <- 10; T <- 10; B <- 20
  x <- function(l) L + (l - 1) / 4 * (W - L - R)
  y <- function(v) T + (1 - v) * (H - T - B)
  pts <- paste(sprintf("%.1f,%.1f", x(1:5), y(cv)), collapse = " ")
  dots <- paste(vapply(1:5, function(l) sprintf('<circle class="cm-dot%s" cx="%.1f" cy="%.1f" r="%s"/><text class="cm-ax" x="%.1f" y="%d" text-anchor="middle">M%d</text>',
    if (l == reached && reached > cur) " on" else if (l == cur) " cur" else "", x(l), y(cv[l]), if (l %in% c(cur, reached)) "4.5" else "3",
    x(l), H - 5, l), ""), collapse = "")
  band <- if (reached > cur) sprintf('<rect class="cm-band" x="%.1f" y="%d" width="%.1f" height="%d"/>', x(cur), T, x(reached) - x(cur), H - T - B) else ""
  htmltools::HTML(sprintf('<svg class="curve-mini" viewBox="0 0 %d %d" role="img" aria-label="Impact curve">%s<text class="cm-ax" x="%d" y="%.1f" text-anchor="end">100%%</text><text class="cm-ax" x="%d" y="%.1f" text-anchor="end">0</text><polyline class="cm-line" points="%s"/>%s</svg>',
    W, H, band, L - 6, y(1) + 3, L - 6, y(0) + 3, pts, dots))
}

detail_enabler <- function(data, model, id) {
  e <- data$enabler[data$enabler$id == id, ]
  g <- model$graph
  sch <- model$schedule[model$schedule$id == id, ]
  cp <- vapply(model$cost_parts, function(m) sum(m[id, ]), 0)
  f <- model$scope_factor[[id]]
  ms <- names(Filter(function(ch) id %in% c(ch$direct, ch$foundation), g$chains))
  direct_ms <- ms[g$weight[id, ms] > 0]
  ename <- function(x) data$enabler$name[match(x, data$enabler$id)]
  egrp <- function(x) data$enabler$enabler_group[match(x, data$enabler$id)]
  li <- g$level_issues[g$level_issues$enabler_id == id, ]
  tagList(
    tags$p(class = "d-kicker", tags$i(class = paste("gdot", e$enabler_group)), " ",
           GROUPS$name[GROUPS$id == e$enabler_group], " \u203a ", e$subgroup),
    tags$h3(class = "d-title", e$name),
    facts(
      Level = paste(lvl(e$level), LEVELS$name[e$level]),
      Concept = e$concept,
      Build = paste0(e$start_q, " \u2013 ", e$end_q,
                     if (sch$compression > 0.005) sprintf(" \u00b7 %s now (\u2212%.0f%%)", q_of(sch$end), sch$compression * 100)),
      Cost = sprintf("%s capex \u00b7 %s people \u00b7 %s opex", fmt_musd(cp[["capex"]]), fmt_musd(cp[["people"]]), fmt_musd(cp[["opex"]])),
      `People` = sprintf("%.1f internal \u00b7 %.1f partner FTE", e$fte_internal, e$fte_partner),
      `Cost basis` = if (e$cost_basis == "per_process")
        sprintf("per process \u00b7 %d of %d need it \u00b7 \u00d7%.2f", model$scope_n[[id]], model$scope_N[[id]], f) else "fixed",
      Scalability = scalability_label(sch$scalability),
      `In scope` = if (f > 0) fmt_musd(sum(model$cost[id, ])) else neg("not needed at these targets")),
    if (any(model$issues$enabler_id == id)) tags$p(class = "d-note neg",
      paste(model$issues$message[model$issues$enabler_id == id], collapse = "; ")),
    if (nrow(li)) tags$p(class = "d-note neg", paste(li$message, collapse = "; ")),
    if (length(direct_ms)) tagList(
      tags$p(class = "d-section", "Makes possible"),
      tags$ul(class = "elist", lapply(direct_ms, function(k) tags$li(
        sel_link("milestone", k, data$milestone$name[data$milestone$id == k]),
        tags$span(class = "emeta", lvl(data$milestone$level[data$milestone$id == k]),
                  if (!model$in_scope[[k]]) " \u00b7 out"))))),
    if (length(g$prereq[[id]])) tagList(
      tags$p(class = "d-section", "Requires"),
      tags$ul(class = "elist quiet", lapply(g$prereq[[id]], function(p) tags$li(sel_link("enabler", p, ename(p), egrp(p)))))),
    if (length(g$dependents[[id]])) tagList(
      tags$p(class = "d-section", "Needed by"),
      tags$ul(class = "elist quiet", lapply(g$dependents[[id]], function(p) tags$li(sel_link("enabler", p, ename(p), egrp(p))))))
  )
}

detail_process <- function(data, model, id) {
  pr <- data$process[data$process$id == id, ]
  f <- process_figures(data, model, id)
  ms <- data$milestone[data$milestone$process_id == id, ]
  ms <- ms[order(ms$level, ms$due), ]
  ks <- metrics_of_process(data, id)
  path <- model$path[model$path$process_id == id, , drop = FALSE]
  tg <- model$targets[[id]]
  tagList(
    tags$p(class = "d-kicker", "Process"),
    tags$h3(class = "d-title", pr$name),
    facts(Owner = pr$owner,
          Maturity = paste0(lvl(pr$current_level), " today \u2192 ", lvl(tg), if (tg != pr$target_level) paste0(" (base ", lvl(pr$target_level), ")")),
          Reached = if (!is.null(path) && nrow(path)) paste(sprintf("%s %s", lvl(path$level), ifelse(is.na(path$t), "from today", q_of(path$t))), collapse = " \u00b7 ") else "stays at its current level",
          Value = paste0(fmt_musd(f$run_rate), " / yr"),
          `Attributed cost` = fmt_musd(f$cost),
          NPV = if (f$npv >= 0) pos(fmt_musd(f$npv)) else neg(fmt_musd(f$npv))),
    tags$p(class = "d-section", sprintf("%d metrics", length(ks))),
    tags$ul(class = "elist", lapply(ks, function(k) tags$li(
      sel_link("metric", k, data$metric$name[data$metric$id == k]),
      tags$span(class = "emeta", fmt_pct(model$impact[[k]]))))),
    tags$p(class = "d-section", sprintf("%d milestones", nrow(ms))),
    tags$ul(class = "elist", lapply(seq_len(nrow(ms)), function(i) tags$li(
      sel_link("milestone", ms$id[i], ms$name[i]),
      tags$span(class = "emeta", lvl(ms$level[i]), if (!model$in_scope[[ms$id[i]]]) " \u00b7 out")))))
}

scalability_label <- function(x) {
  paste(formatC(x, format = "f", digits = 1),
        if (x == 0) "rigid" else if (x < 0.95) "diminishing" else if (x <= 1.05) "linear" else "super-linear")
}
