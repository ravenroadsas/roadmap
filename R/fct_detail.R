# Detail panel (right of the canvas): results in scope by default, or the
# selected result, enabler or process.

#' Parse "result:R1" style selection strings
parse_selection <- function(x) {
  if (is.null(x) || !nzchar(x)) return(NULL)
  p <- strsplit(x, ":", fixed = TRUE)[[1]]
  if (length(p) != 2 || !p[1] %in% c("result", "enabler", "process")) return(NULL)
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

#' Panel for the selection, or the results in scope
detail_ui <- function(data, model, sel) {
  if (is.null(sel)) return(detail_scope(data, model))
  switch(sel$type,
    result = detail_result(data, model, sel$id),
    enabler = detail_enabler(data, model, sel$id),
    process = detail_process(data, model, sel$id))
}

detail_scope <- function(data, model) {
  w <- model$scope_w
  r <- data$result[data$result$id %in% names(w)[w > 0], ]
  v <- model$run_rate[r$id] * w[r$id]
  r <- r[order(-v, r$due), ]
  late <- r$id %in% model$late$result_id
  tagList(
    tags$p(class = "d-kicker", sprintf("%d results in scope", nrow(r))),
    tags$p(class = "d-hint", "Select a result or an enabler to see what it depends on."),
    tags$ol(class = "rlist", lapply(seq_len(nrow(r)), function(i) {
      rv <- model$run_rate[[r$id[i]]] * w[[r$id[i]]]
      tags$li(class = if (late[i]) "late",
        tags$button(class = "rrow", `data-sel` = paste0("result:", r$id[i]),
          tags$span(class = "rname", r$name[i]),
          tags$span(class = "rval", if (rv > 0) fmt_musd(rv) else "\u2013"),
          tags$span(class = "rmeta", pname(data, r$process_id[i]),
                    if (sum(model$graph$share[r$id[i], ] > 0) > 1) " \u00b7 shared",
                    " \u00b7 due ", r$due[i], if (late[i]) tags$span(class = "neg", " \u00b7 late"))))
    })))
}

detail_result <- function(data, model, id) {
  r <- data$result[data$result$id == id, ]
  g <- model$graph
  ch <- g$chains[[id]]
  a <- attributed(model, id)
  sh <- g$share[id, ]
  sh <- sh[sh > 0]
  late <- model$late[model$late$result_id == id, ]
  en <- data$enabler[match(c(ch$direct, ch$foundation), data$enabler$id), ]
  dir <- en$id %in% ch$direct
  tagList(
    tags$p(class = "d-kicker", "Result"),
    tags$h3(class = "d-title", r$name),
    facts(
      Process = if (length(sh) > 1) paste(sprintf("%s %s", pname(data, names(sh)), fmt_pct(sh)), collapse = " \u00b7 ")
                else pname(data, r$process_id),
      Measure = if (r$measured) paste(fmt_num(r$baseline, r$unit), "\u2192", fmt_num(r$target, r$unit)),
      Due = r$due,
      Ready = if (nrow(late)) neg(paste(q_of(model$ready[[id]]), "\u00b7 late")) else q_of(model$ready[[id]]),
      Value = if (a$run_rate > 0) paste0(fmt_musd(a$run_rate), " / yr") else "none of its own",
      `Attributed cost` = fmt_musd(a$cost)),
    if (nrow(late)) tags$p(class = "d-note neg", late$message),
    tags$p(class = "d-section", sprintf("Requires %d enabler%s", sum(dir), if (sum(dir) != 1) "s" else "")),
    tags$ul(class = "elist", lapply(which(dir), function(i) tags$li(
      sel_link("enabler", en$id[i], en$name[i], en$enabler_group[i]),
      tags$span(class = "emeta", fmt_pct(g$weight[en$id[i], id]))))),
    if (any(!dir)) tagList(
      tags$p(class = "d-section", sprintf("On %d foundation%s", sum(!dir), if (sum(!dir) != 1) "s" else "")),
      tags$ul(class = "elist quiet", lapply(which(!dir), function(i) tags$li(
        sel_link("enabler", en$id[i], en$name[i], en$enabler_group[i])))))
  )
}

detail_enabler <- function(data, model, id) {
  e <- data$enabler[data$enabler$id == id, ]
  g <- model$graph
  sch <- model$schedule[model$schedule$id == id, ]
  cp <- vapply(model$cost_parts, function(m) sum(m[id, ]), 0)
  f <- model$scope_factor[[id]]
  rs <- names(Filter(function(ch) id %in% c(ch$direct, ch$foundation), g$chains))
  direct_rs <- rs[g$weight[id, rs] > 0]
  ename <- function(x) data$enabler$name[match(x, data$enabler$id)]
  egrp <- function(x) data$enabler$enabler_group[match(x, data$enabler$id)]
  tagList(
    tags$p(class = "d-kicker", tags$i(class = paste("gdot", e$enabler_group)), " ",
           GROUPS$name[GROUPS$id == e$enabler_group], " \u203a ", e$subgroup),
    tags$h3(class = "d-title", e$name),
    facts(
      Concept = e$concept,
      Build = paste0(e$start_q, " \u2013 ", e$end_q,
                     if (sch$compression > 0.005) sprintf(" \u00b7 %s now (\u2212%.0f%%)", q_of(sch$end), sch$compression * 100)),
      Cost = sprintf("%s capex \u00b7 %s people \u00b7 %s opex", fmt_musd(cp[["capex"]]), fmt_musd(cp[["people"]]), fmt_musd(cp[["opex"]])),
      `People` = sprintf("%.1f internal \u00b7 %.1f partner FTE", e$fte_internal, e$fte_partner),
      `Cost basis` = if (e$cost_basis == "per_process")
        sprintf("per process \u00b7 %d of %d in scope \u00b7 \u00d7%.2f", model$scope_n[[id]], model$scope_N[[id]], f) else "fixed",
      Scalability = scalability_label(sch$scalability),
      `In scope` = fmt_musd(sum(model$cost[id, ]))),
    if (any(model$issues$enabler_id == id)) tags$p(class = "d-note neg",
      paste(model$issues$message[model$issues$enabler_id == id], collapse = "; ")),
    if (length(direct_rs)) tagList(
      tags$p(class = "d-section", "Makes possible"),
      tags$ul(class = "elist", lapply(direct_rs, function(k) tags$li(
        sel_link("result", k, data$result$name[data$result$id == k]))))),
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
  g <- model$graph
  ks <- results_of_process(g, id)
  w <- g$share[ks, id]
  a <- attributed(model, ks, w)
  tagList(
    tags$p(class = "d-kicker", "Process"),
    tags$h3(class = "d-title", pr$name),
    facts(Owner = pr$owner, Value = paste0(fmt_musd(a$run_rate), " / yr"),
          `Attributed cost` = fmt_musd(a$cost),
          NPV = if (a$npv >= 0) pos(fmt_musd(a$npv)) else neg(fmt_musd(a$npv))),
    tags$p(class = "d-section", sprintf("%d results", length(ks))),
    tags$ul(class = "elist", lapply(ks, function(k) tags$li(
      sel_link("result", k, data$result$name[data$result$id == k]),
      tags$span(class = "emeta", if (w[[k]] < 1) fmt_pct(w[[k]]) else "")))))
}

scalability_label <- function(x) {
  paste(formatC(x, format = "f", digits = 1),
        if (x == 0) "rigid" else if (x < 0.95) "diminishing" else if (x <= 1.05) "linear" else "super-linear")
}
