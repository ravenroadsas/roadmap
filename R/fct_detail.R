# Detail panel content for the current selection (rendered server-side).

#' Parse "kpi:K1" style selection strings
parse_selection <- function(x) {
  if (is.null(x) || !nzchar(x)) return(NULL)
  p <- strsplit(x, ":", fixed = TRUE)[[1]]
  if (length(p) != 2 || !p[1] %in% c("kpi", "enabler", "process")) return(NULL)
  list(type = p[1], id = p[2])
}

#' Enablers, KPIs and processes reached by a selection
selection_sets <- function(data, graph, sel, kpi_ids) {
  w <- graph$weight[, kpi_ids, drop = FALSE]
  kpi_of <- function(en) colnames(w)[colSums(w[en, , drop = FALSE]) > 0]
  proc_of <- function(ks) unique(data$kpi$process_id[match(ks, data$kpi$id)])
  if (sel$type == "kpi") {
    ch <- graph$chains[[sel$id]]
    list(direct = ch$direct, en = c(ch$direct, ch$foundation), kpi = sel$id,
         proc = proc_of(sel$id))
  } else if (sel$type == "enabler") {
    down <- descendants(sel$id, graph$dependents)
    ks <- kpi_of(c(sel$id, down))
    list(direct = sel$id, en = unique(c(sel$id, ancestors(sel$id, graph$prereq), down)),
         kpi = ks, proc = proc_of(ks), down = down)
  } else {
    ks <- intersect(data$kpi$id[data$kpi$process_id == sel$id], kpi_ids)
    direct <- rownames(w)[rowSums(w[, ks, drop = FALSE]) > 0]
    list(direct = direct, en = union(direct, ancestors(direct, graph$prereq)),
         kpi = ks, proc = sel$id)
  }
}

sel_link <- function(type, id, label, group = NULL) {
  btn <- tags$button(class = "lk", `data-sel` = paste0(type, ":", id), label)
  if (is.null(group)) return(btn)
  tags$span(class = "en", tags$span(class = paste("dot", group)), btn)
}

kv <- function(labels, values) {
  tags$div(class = "kv", lapply(seq_along(labels), function(i) {
    v <- values[[i]]
    tags$div(tags$div(class = "l", labels[i]), tags$div(class = paste("v", attr(v, "cls")), v))
  }))
}
cls <- function(x, c) structure(x, cls = c)
sign_cls <- function(x) if (isTRUE(x >= 0)) "pos" else "neg"
vtag <- function(v) {
  if (v == "private") tags$span(class = "vtag private", "MGMT ONLY") else tags$span(class = "vtag", "PUBLIC")
}

#' Detail panel for the selection (or the portfolio when nothing is selected)
detail_ui <- function(data, model, sel, kpi_ids) {
  if (is.null(sel)) return(detail_portfolio(data, model, kpi_ids))
  if (sel$type == "kpi" && !sel$id %in% kpi_ids) return(detail_portfolio(data, model, kpi_ids))
  switch(sel$type,
    kpi = detail_kpi(data, model, sel$id, kpi_ids),
    enabler = detail_enabler(data, model, sel$id, kpi_ids),
    process = detail_process(data, model, sel$id, kpi_ids)
  )
}

detail_portfolio <- function(data, model, kpi_ids) {
  k <- data$kpi[data$kpi$id %in% kpi_ids, ]
  run <- model$run_rate[k$id]
  o <- order(-run)
  mx <- max(run)
  ec <- enabler_costs(model)
  dv <- enabler_direct_value(model, kpi_ids)
  e <- data$enabler[order(-ec[data$enabler$id]), ][1:6, ]
  tagList(
    tags$div(tags$div(class = "eyebrow", sprintf("Value to %s", model$cfg$horizon_end)),
             tags$h3("Select a KPI to trace what makes it possible")),
    issues_ui(model$graph$issues),
    tags$div(class = "callout",
      "Click a ", tags$b("KPI"), " to highlight its direct enablers and the foundations under them. ",
      "Click an ", tags$b("enabler"), " to see what it unlocks. Figures follow the Sensitivity tab."),
    tags$div(tags$div(class = "eyebrow", "Run-rate value by KPI ($M/yr)"),
      tags$table(class = "t", tags$tbody(lapply(o, function(i) tags$tr(
        tags$td(sel_link("kpi", k$id[i], k$name[i]),
                tags$div(class = "minibar", tags$i(style = sprintf("width:%.0f%%", run[i] / mx * 100)))),
        tags$td(class = "r", formatC(run[i], format = "f", digits = 1))))))),
    tags$div(tags$div(class = "eyebrow", sprintf("Largest investments ($M to %s)", model$cfg$horizon_end)),
      tags$table(class = "t",
        tags$thead(tags$tr(tags$th("Enabler"), tags$th(class = "r", "Cost"), tags$th(class = "r", "Direct value"))),
        tags$tbody(lapply(seq_len(nrow(e)), function(i) tags$tr(
          tags$td(sel_link("enabler", e$id[i], e$name[i], e$enabler_group[i])),
          tags$td(class = "r", formatC(ec[e$id[i]], format = "f", digits = 1)),
          tags$td(class = "r", if (dv[e$id[i]] > 0) formatC(dv[e$id[i]], format = "f", digits = 1)
                  else tags$span(class = "hint", "foundation")))))))
  )
}

detail_kpi <- function(data, model, id, kpi_ids) {
  k <- data$kpi[data$kpi$id == id, ]
  g <- model$graph
  ch <- g$chains[[id]]
  p <- portfolio(model, id)
  tot <- enabler_costs(model)
  al <- enabler_costs(model, id)
  en <- c(ch$direct, ch$foundation)
  e <- data$enabler[match(en, data$enabler$id), ]
  is_dir <- e$id %in% ch$direct
  o <- order(!is_dir, -al[e$id])
  e <- e[o, ]
  is_dir <- is_dir[o]
  ms_vis <- if (all(data$kpi$id %in% kpi_ids)) c("public", "private") else "public"
  ms <- data$milestone[data$milestone$enabler_id %in% en & data$milestone$visibility %in% ms_vis, ]
  driver <- c(oil_price = "oil price", fte_cost = "labour cost", none = "fixed")[k$value_driver]
  tagList(
    tags$div(tags$div(class = "eyebrow",
                      data$process$name[data$process$id == k$process_id], " ", vtag(k$visibility)),
             tags$h3(k$name)),
    kv(c("Baseline", paste("Target", k$target_year), "Ready"),
       list(fmt_num(k$baseline, k$unit), fmt_num(k$target, k$unit), time_to_q(ceiling(model$ready[[id]] * 4 - 1e-9) / 4 - 0.25))),
    kv(c("Run-rate", paste("Value to", model$cfg$horizon_end), "NPV"),
       list(cls(paste0(fmt_musd(p$run_rate), "/yr"), "pos"), fmt_musd(p$total_value),
            cls(fmt_musd(p$npv), sign_cls(p$npv)))),
    issues_ui(model$graph$issues[model$graph$issues$enabler_id %in% en, ]),
    tags$div(class = "callout",
      tags$b(length(ch$direct), " direct enablers"), " rely on ", tags$b(length(ch$foundation), " foundations"),
      sprintf(". Allocated cost %s (ROI %s). Building the whole chain for this KPI alone would cost %s. Value driver: %s.",
              fmt_musd(p$total_cost), fmt_pct(p$roi), fmt_musd(sum(tot[en])), driver)),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("Enabler"), tags$th("Role"), tags$th(class = "r", "Alloc. $M"))),
      tags$tbody(lapply(seq_len(nrow(e)), function(i) tags$tr(
        tags$td(sel_link("enabler", e$id[i], e$name[i], e$enabler_group[i]),
                tags$div(class = "hint", paste0(e$start_q[i], "\u2013", e$end_q[i]))),
        tags$td(if (is_dir[i]) tags$span(class = "role d", sprintf("DIRECT %.0f%%", g$weight[e$id[i], id] * 100))
                else tags$span(class = "role f", "FOUNDATION")),
        tags$td(class = "r", formatC(al[e$id[i]], format = "f", digits = 1),
                tags$div(class = "hint", paste("of", formatC(tot[e$id[i]], format = "f", digits = 1))))))),
      tags$tfoot(tags$tr(tags$td(colspan = 2, "Allocated to this KPI"),
                         tags$td(class = "r", formatC(p$total_cost, format = "f", digits = 1))))),
    if (nrow(ms)) tags$div(tags$div(class = "eyebrow", "Milestones on the path"),
      tags$table(class = "t", tags$tbody(lapply(seq_len(nrow(ms)), function(i)
        tags$tr(tags$td(class = "mono", ms$milestone_date[i]), tags$td(ms$name[i]))))))
  )
}

detail_enabler <- function(data, model, id, kpi_ids) {
  e <- data$enabler[data$enabler$id == id, ]
  g <- model$graph
  cfg <- model$cfg
  s <- selection_sets(data, g, list(type = "enabler", id = id), kpi_ids)
  dv <- enabler_direct_value(model, kpi_ids)[[id]]
  sch <- model$schedule[model$schedule$id == id, ]
  people <- (e$fte_internal * cfg$fte_cost + e$fte_partner * cfg$fte_cost * (1 + cfg$partner_premium)) / 1000
  ks <- kpi_ids[g$alloc[id, kpi_ids] > 0]
  ks <- ks[order(-g$alloc[id, ks])]
  kname <- data$kpi$name[match(ks, data$kpi$id)]
  ename <- function(x) data$enabler$name[match(x, data$enabler$id)]
  egrp <- function(x) data$enabler$enabler_group[match(x, data$enabler$id)]
  tagList(
    tags$div(tags$div(class = "eyebrow", tags$span(class = paste("dot", e$enabler_group)), " ",
                      GROUPS$name[GROUPS$id == e$enabler_group], " \u203a ", e$subcategory),
             tags$h3(e$name)),
    kv(c("Period", "Capex", "Opex"),
       list(paste0(e$start_q, "\u2013", e$end_q), fmt_musd(e$capex_musd * (1 + cfg$capex_overrun)),
            paste0(fmt_musd(e$opex_musd_yr), "/yr"))),
    kv(c("Manpower", "People cost", paste("Cost to", cfg$horizon_end)),
       list(sprintf("%s int \u00b7 %s ext", e$fte_internal, e$fte_partner), paste0(fmt_musd(people), "/yr"),
            cls(fmt_musd(sum(model$cost[id, ])), "neg"))),
    enabler_issue_ui(g$issues, id),
    kv(c("Compressible", "Scenario end", "Crash cost"),
       list(fmt_pct(sch$compressibility), time_to_q(ceiling(sch$end * 4 - 1e-9) / 4 - 0.25),
            if (sch$compression > 0) cls(paste0("+", fmt_pct(sch$cost_factor - 1)), "neg") else "\u2013")),
    tags$div(class = "callout",
      if (dv > 0) tagList("Direct value attributed: ", tags$b(fmt_musd(dv)), sprintf(" to %s. ", cfg$horizon_end))
      else tagList(tags$b("Foundation enabler"), ": no direct KPI, its cost is shared by everything built on it. "),
      "Unlocks ", tags$b(length(s$down)), " downstream enablers and ", tags$b(length(s$kpi)), " KPIs. Sourcing: ",
      if (e$fte_partner > e$fte_internal) "mainly partners / contractors." else "mainly internal."),
    if (length(g$prereq[[id]])) tags$div(tags$div(class = "eyebrow", "Requires"),
      lapply(g$prereq[[id]], function(p) tags$div(sel_link("enabler", p, ename(p), egrp(p))))),
    if (length(g$dependents[[id]])) tags$div(tags$div(class = "eyebrow", "Enables"),
      lapply(g$dependents[[id]], function(p) tags$div(sel_link("enabler", p, ename(p), egrp(p))))),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("KPI served"), tags$th(class = "r", "Direct wt"), tags$th(class = "r", "Cost share"))),
      tags$tbody(lapply(seq_along(ks), function(i) tags$tr(
        tags$td(sel_link("kpi", ks[i], kname[i])),
        tags$td(class = "r", if (g$weight[id, ks[i]] > 0) fmt_pct(g$weight[id, ks[i]]) else "\u2013"),
        tags$td(class = "r", fmt_pct(g$alloc[id, ks[i]]))))))
  )
}

detail_process <- function(data, model, id, kpi_ids) {
  pr <- data$process[data$process$id == id, ]
  ks <- intersect(data$kpi$id[data$kpi$process_id == id], kpi_ids)
  s <- selection_sets(data, model$graph, list(type = "process", id = id), kpi_ids)
  p <- portfolio(model, ks)
  tagList(
    tags$div(tags$div(class = "eyebrow", "Process \u00b7 owner ", pr$owner), tags$h3(pr$name)),
    kv(c("Run-rate", "Alloc. cost", "NPV"),
       list(cls(paste0(fmt_musd(p$run_rate), "/yr"), "pos"), fmt_musd(p$total_cost),
            cls(fmt_musd(p$npv), sign_cls(p$npv)))),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("KPI"), tags$th(class = "r", "Run-rate"))),
      tags$tbody(lapply(ks, function(k) tags$tr(
        tags$td(sel_link("kpi", k, data$kpi$name[data$kpi$id == k])),
        tags$td(class = "r", formatC(model$run_rate[[k]], format = "f", digits = 1)))))),
    tags$div(class = "callout", sprintf("%d direct enablers and %d foundations sit behind this process.",
                                        length(s$direct), length(s$en) - length(s$direct)))
  )
}

#' Red callout listing all date issues (portfolio view)
issues_ui <- function(issues) {
  if (!nrow(issues)) return(NULL)
  tags$div(class = "callout issue",
    tags$b(sprintf("%d date issue%s in the plan", nrow(issues), if (nrow(issues) > 1) "s" else "")),
    tags$ul(lapply(seq_len(nrow(issues)), function(i)
      tags$li(sel_link("enabler", issues$enabler_id[i], issues$message[i])))))
}

#' Red callout for the issues of one enabler
enabler_issue_ui <- function(issues, id) {
  x <- issues[issues$enabler_id == id | (!is.na(issues$related_id) & issues$related_id == id), ]
  if (!nrow(x)) return(NULL)
  tags$div(class = "callout issue", tags$b("Date issue: "), paste(x$message, collapse = "; "))
}
