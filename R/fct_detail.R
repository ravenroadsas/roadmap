# Detail panel content for the current selection (rendered server-side).

#' Parse "result:K1" style selection strings
parse_selection <- function(x) {
  if (is.null(x) || !nzchar(x)) return(NULL)
  p <- strsplit(x, ":", fixed = TRUE)[[1]]
  if (length(p) != 2 || !p[1] %in% c("result", "enabler", "process")) return(NULL)
  list(type = p[1], id = p[2])
}

#' Enablers, results and processes reached by a selection
selection_sets <- function(data, graph, sel, result_ids) {
  w <- graph$weight[, result_ids, drop = FALSE]
  res_of <- function(en) colnames(w)[colSums(w[en, , drop = FALSE]) > 0]
  proc_of <- function(rs) colnames(graph$share)[colSums(graph$share[rs, , drop = FALSE]) > 0]
  if (sel$type == "result") {
    ch <- graph$chains[[sel$id]]
    list(direct = ch$direct, en = c(ch$direct, ch$foundation), result = sel$id,
         proc = proc_of(sel$id))
  } else if (sel$type == "enabler") {
    down <- descendants(sel$id, graph$dependents)
    rs <- res_of(c(sel$id, down))
    list(direct = sel$id, en = unique(c(sel$id, ancestors(sel$id, graph$prereq), down)),
         result = rs, proc = proc_of(rs), down = down)
  } else {
    rs <- intersect(results_of_process(graph, sel$id), result_ids)
    direct <- rownames(w)[rowSums(w[, rs, drop = FALSE]) > 0]
    list(direct = direct, en = union(direct, ancestors(direct, graph$prereq)),
         result = rs, proc = sel$id)
  }
}

#' "KPI" / "Milestone" tag
kind_tag <- function(kind) tags$span(class = paste("ktag", kind), if (kind == "kpi") "KPI" else "MILESTONE")

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

#' Detail panel for the selection (or the portfolio when nothing is selected)
detail_ui <- function(data, model, sel, result_ids) {
  if (is.null(sel)) return(detail_portfolio(data, model, result_ids))
  all_r <- data$result$id                 # a selected item is always shown in full
  switch(sel$type,
    result = detail_result(data, model, sel$id),
    enabler = detail_enabler(data, model, sel$id, all_r),
    process = detail_process(data, model, sel$id, all_r)
  )
}

detail_portfolio <- function(data, model, result_ids) {
  r <- data$result[data$result$id %in% result_ids, ]
  run <- model$run_rate[r$id]
  o <- order(-run, r$due)
  mx <- max(run, 1e-9)
  ec <- enabler_costs(model)
  dv <- enabler_direct_value(model, result_ids)
  e <- data$enabler[order(-ec[data$enabler$id]), ][seq_len(min(6, nrow(data$enabler))), ]
  tagList(
    tags$div(tags$div(class = "eyebrow", sprintf("Value to %s", model$cfg$horizon_end)),
             tags$h3("Select a result to trace what makes it possible")),
    late_ui(model$late),
    issues_ui(model$issues),
    tags$div(class = "callout",
      "Each process has ", tags$b("results"), ": KPIs and milestones. Click one to highlight the enablers it ",
      "requires and the foundations under them. Click an ", tags$b("enabler"), " to see what it unlocks."),
    tags$div(tags$div(class = "eyebrow", "Results by run-rate value ($M/yr)"),
      tags$table(class = "t", tags$tbody(lapply(o, function(i) tags$tr(
        tags$td(kind_tag(r$kind[i]), " ", sel_link("result", r$id[i], r$name[i]),
                tags$div(class = "minibar", tags$i(style = sprintf("width:%.0f%%", run[i] / mx * 100)))),
        tags$td(class = "r", if (run[i] > 0) formatC(run[i], format = "f", digits = 1) else tags$span(class = "hint", "\u2013"))))))),
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

detail_result <- function(data, model, id) {
  r <- data$result[data$result$id == id, ]
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
  driver <- c(oil_price = "oil price", fte_cost = "labour cost", none = "fixed")[r$value_driver]
  late <- model$late[model$late$result_id == id, ]
  ready_q <- q_of(model$ready[[id]])
  sh <- model$graph$share[id, ]
  sh <- sh[sh > 0]
  shared <- if (length(sh) > 1) tags$div(class = "callout",
    tags$b("Shared result: "), "lead ", data$process$name[data$process$id == r$process_id], ". Value and cost split ",
    paste(sprintf("%s %s", data$process$name[match(names(sh), data$process$id)], fmt_pct(sh)), collapse = " \u00b7 "), ".")
  tagList(
    tags$div(tags$div(class = "eyebrow", kind_tag(r$kind), " ",
                      data$process$name[data$process$id == r$process_id], " \u00b7 owner ",
                      data$process$owner[data$process$id == r$process_id]),
             tags$h3(r$name)),
    if (r$kind == "kpi") kv(c("Baseline", "Target", "Due"),
       list(fmt_num(r$baseline, r$unit), fmt_num(r$target, r$unit), r$due))
    else kv(c("Due", "Ready", "Status"),
       list(r$due, cls(ready_q, if (nrow(late)) "neg" else ""), cls(if (nrow(late)) "late" else "on time", if (nrow(late)) "neg" else "pos"))),
    if (p$run_rate > 0) {
      kv(c(if (r$kind == "kpi") "Ready" else "Run-rate", paste("Value to", model$cfg$horizon_end), "NPV"),
         list(if (r$kind == "kpi") cls(ready_q, if (nrow(late)) "neg" else "") else cls(paste0(fmt_musd(p$run_rate), "/yr"), "pos"),
              fmt_musd(p$total_value), cls(fmt_musd(p$npv), sign_cls(p$npv))))
    } else {
      kv(c(if (r$kind == "kpi") "Ready" else "Value", "Allocated cost", if (r$kind == "kpi") "Value" else ""),
         list(if (r$kind == "kpi") cls(ready_q, if (nrow(late)) "neg" else "") else "none",
              fmt_musd(p$total_cost), if (r$kind == "kpi") "none" else ""))
    },
    shared,
    if (nrow(late)) tags$div(class = "callout issue", tags$b("Late: "), late$message),
    issues_ui(model$issues[model$issues$enabler_id %in% en, ]),
    tags$div(class = "callout",
      "Requires ", tags$b(sprintf("%d enabler%s", length(ch$direct), if (length(ch$direct) != 1) "s" else "")),
      ", which rely on ", tags$b(sprintf("%d foundation%s", length(ch$foundation), if (length(ch$foundation) != 1) "s" else "")),
      if (p$run_rate > 0) sprintf(". %sAllocated cost %s (ROI %s). Building the whole chain for this result alone would cost %s. Value driver: %s.",
              if (r$kind == "kpi") paste0("Run-rate ", fmt_musd(p$run_rate), "/yr. ") else "",
              fmt_musd(p$total_cost), fmt_pct(p$roi), fmt_musd(sum(tot[en])), driver)
      else sprintf(". No value of its own (enabling result): it carries %s of allocated cost, which the portfolio figures include. Building its whole chain alone would cost %s.",
                   fmt_musd(p$total_cost), fmt_musd(sum(tot[en])))),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("Enabler"), tags$th("Role"), tags$th(class = "r", "Alloc. $M"))),
      tags$tbody(lapply(seq_len(nrow(e)), function(i) tags$tr(
        tags$td(sel_link("enabler", e$id[i], e$name[i], e$enabler_group[i]),
                tags$div(class = "hint", paste0(e$start_q[i], "\u2013", e$end_q[i]))),
        tags$td(if (is_dir[i]) tags$span(class = "role d", sprintf("REQUIRED %.0f%%", g$weight[e$id[i], id] * 100))
                else tags$span(class = "role f", "FOUNDATION")),
        tags$td(class = "r", formatC(al[e$id[i]], format = "f", digits = 1),
                tags$div(class = "hint", paste("of", formatC(tot[e$id[i]], format = "f", digits = 1))))))),
      tags$tfoot(tags$tr(tags$td(colspan = 2, "Allocated to this result"),
                         tags$td(class = "r", formatC(p$total_cost, format = "f", digits = 1)))))
  )
}

detail_enabler <- function(data, model, id, result_ids) {
  e <- data$enabler[data$enabler$id == id, ]
  g <- model$graph
  cfg <- model$cfg
  s <- selection_sets(data, g, list(type = "enabler", id = id), result_ids)
  dv <- enabler_direct_value(model, result_ids)[[id]]
  sch <- model$schedule[model$schedule$id == id, ]
  people <- (e$fte_internal * cfg$fte_cost + e$fte_partner * cfg$fte_cost * (1 + cfg$partner_premium)) / 1000
  ks <- result_ids[g$alloc[id, result_ids] > 0]
  ks <- ks[order(-g$alloc[id, ks])]
  kname <- data$result$name[match(ks, data$result$id)]
  kkind <- data$result$kind[match(ks, data$result$id)]
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
    enabler_issue_ui(model$issues, id),
    kv(c("Scalability", "Scenario end", "Build cost vs plan"),
       list(scalability_label(sch$scalability),
            paste0(time_to_q(ceiling(sch$end * 4 - 1e-9) / 4 - 0.25),
                   if (sch$compression > 0.005) sprintf(" (\u2212%.0f%%)", sch$compression * 100) else ""),
            cls(sprintf("%+.0f%%", (sch$cost_factor - 1) * 100),
                if (sch$cost_factor > 1.005) "neg" else if (sch$cost_factor < 0.995) "pos" else ""))),
    spend_table(model, id),
    tags$div(class = "callout",
      if (dv > 0) tagList("Direct value attributed: ", tags$b(fmt_musd(dv)), sprintf(" to %s. ", cfg$horizon_end))
      else tagList(tags$b("Foundation enabler"), ": no result requires it directly; its cost is shared by everything built on it. "),
      "Unlocks ", tags$b(length(s$down)), " downstream enablers and ", tags$b(length(s$result)), " results. Sourcing: ",
      if (e$fte_partner > e$fte_internal) "mainly partners / contractors." else "mainly internal."),
    if (length(g$prereq[[id]])) tags$div(tags$div(class = "eyebrow", "Requires"),
      lapply(g$prereq[[id]], function(p) tags$div(sel_link("enabler", p, ename(p), egrp(p))))),
    if (length(g$dependents[[id]])) tags$div(tags$div(class = "eyebrow", "Enables"),
      lapply(g$dependents[[id]], function(p) tags$div(sel_link("enabler", p, ename(p), egrp(p))))),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("Results served"), tags$th(class = "r", "Weight"), tags$th(class = "r", "Cost share"))),
      tags$tbody(lapply(seq_along(ks), function(i) tags$tr(
        tags$td(kind_tag(kkind[i]), " ", sel_link("result", ks[i], kname[i])),
        tags$td(class = "r", if (g$weight[id, ks[i]] > 0) fmt_pct(g$weight[id, ks[i]]) else "\u2013"),
        tags$td(class = "r", fmt_pct(g$alloc[id, ks[i]]))))))
  )
}

detail_process <- function(data, model, id, result_ids) {
  pr <- data$process[data$process$id == id, ]
  ks <- intersect(results_of_process(model$graph, id), result_ids)
  ks <- ks[order(data$result$kind[match(ks, data$result$id)], data$result$due[match(ks, data$result$id)])]
  w <- model$graph$share[ks, id]
  s <- selection_sets(data, model$graph, list(type = "process", id = id), result_ids)
  p <- portfolio(model, ks, w)
  tagList(
    tags$div(tags$div(class = "eyebrow", "Process \u00b7 owner ", pr$owner), tags$h3(pr$name)),
    kv(c("Run-rate", "Alloc. cost", "NPV"),
       list(cls(paste0(fmt_musd(p$run_rate), "/yr"), "pos"), fmt_musd(p$total_cost),
            cls(fmt_musd(p$npv), sign_cls(p$npv)))),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("Result"), tags$th(class = "r", "Due"), tags$th(class = "r", "Share"),
                         tags$th(class = "r", "Run-rate"))),
      tags$tbody(lapply(ks, function(k) {
        rr <- data$result[data$result$id == k, ]
        lt <- k %in% model$late$result_id
        tags$tr(tags$td(kind_tag(rr$kind), " ", sel_link("result", k, rr$name),
                        if (rr$process_id != id) tags$div(class = "hint", "shared \u00b7 lead ",
                          data$process$name[data$process$id == rr$process_id])),
                tags$td(class = paste("r", if (lt) "neg"), rr$due, if (lt) " \u26a0"),
                tags$td(class = "r", fmt_pct(w[[k]])),
                tags$td(class = "r", formatC(model$run_rate[[k]] * w[[k]], format = "f", digits = 1)))
      }))),
    late_ui(model$late[model$late$result_id %in% ks, ]),
    tags$div(class = "callout", sprintf("%d required enablers and %d foundations sit behind this process.",
                                        length(s$direct), length(s$en) - length(s$direct)))
  )
}

#' Red callout listing all date issues (portfolio view)
issues_ui <- function(issues) {
  if (!nrow(issues)) return(NULL)
  tags$div(class = "callout issue",
    tags$b(issue_count_label(issues)),
    tags$ul(lapply(seq_len(nrow(issues)), function(i)
      tags$li(sel_link("enabler", issues$enabler_id[i], issues$message[i])))))
}

#' Red callout for the issues of one enabler
enabler_issue_ui <- function(issues, id) {
  x <- issues[issues$enabler_id == id | (!is.na(issues$related_id) & issues$related_id == id), ]
  if (!nrow(x)) return(NULL)
  tags$div(class = "callout issue", tags$b("Date issue: "), paste(x$message, collapse = "; "))
}

scalability_label <- function(x) {
  paste(formatC(x, format = "f", digits = 1),
        if (x == 0) "rigid" else if (x < 0.95) "diminishing" else if (x <= 1.05) "linear" else "super-linear")
}

#' Yearly expenditure of one enabler: plan vs scenario
spend_table <- function(model, id) {
  plan <- model$plan_cost[id, ]
  scen <- model$cost[id, ]
  keep <- which(plan > 0.005 | scen > 0.005)
  if (!length(keep)) return(NULL)
  changed <- any(abs(plan - scen) > 0.005)
  tags$div(tags$div(class = "eyebrow", "Expenditure per year ($M)"),
    tags$table(class = "t",
      tags$thead(tags$tr(tags$th("Year"), tags$th(class = "r", "Plan"),
                         if (changed) tags$th(class = "r", "Scenario"))),
      tags$tbody(lapply(keep, function(i) tags$tr(
        tags$td(class = "mono", names(plan)[i]),
        tags$td(class = "r", formatC(plan[i], format = "f", digits = 2)),
        if (changed) tags$td(class = "r", formatC(scen[i], format = "f", digits = 2))))),
      tags$tfoot(tags$tr(tags$td("Total"), tags$td(class = "r", formatC(sum(plan), format = "f", digits = 1)),
                         if (changed) tags$td(class = "r", formatC(sum(scen), format = "f", digits = 1))))))
}

#' "3 late dependencies, 1 date error" style label
issue_count_label <- function(issues) {
  n_late <- sum(issues$type == "prereq_ends_later")
  n_bad <- sum(issues$type == "end_before_start")
  parts <- c(if (n_late) sprintf("%d late dependenc%s", n_late, if (n_late > 1) "ies" else "y"),
             if (n_bad) sprintf("%d date error%s", n_bad, if (n_bad > 1) "s" else ""))
  paste(parts, collapse = ", ")
}

#' Red callout listing late results
late_ui <- function(late) {
  if (!nrow(late)) return(NULL)
  tags$div(class = "callout issue",
    tags$b(sprintf("%d late result%s", nrow(late), if (nrow(late) > 1) "s" else "")),
    tags$ul(lapply(seq_len(nrow(late)), function(i)
      tags$li(sel_link("result", late$result_id[i], late$message[i])))))
}
