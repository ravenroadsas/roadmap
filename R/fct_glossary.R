# Glossary tab: definitions, and a foundation-to-value tree drawn as SVG.

GLOSSARY <- data.frame(
  term = c("Process", "Result", "KPI", "Milestone", "Value", "Enabler", "Foundation",
           "Process owner", "Shared result", "Requirement (weight)", "Dependency", "Due date vs ready date",
           "Late result", "Late dependency", "Run-rate vs realised value", "Allocated cost",
           "Scalability", "Config / scenario"),
  core = c(rep(TRUE, 7), rep(FALSE, 11)),
  definition = c(
    "The business process being transformed. It owns a set of results; achieving them is how the process generates value.",
    "A tangible outcome of a process, with a due date. Two kinds: KPI and milestone. Each result explicitly requires N enablers.",
    "A result that is measured: a baseline and a target in its own unit (days, %, bbl/employee). Says how much better the process gets.",
    "A result that is achieved or not: an observable step change (e.g. 250 wells per engineer). Same rules as a KPI: due date, required enablers, optional value.",
    "What a result is worth in money once achieved (value_musd per year). The only place money comes in. Scaled by realisation, the value driver (oil price or labour cost) and adoption over time. A process's value is the sum of its results.",
    "Something we invest in and build: a digital solution, data, infrastructure or a people / change initiative. The only element that consumes money, internal staff (fte_internal) and partner staff (fte_partner). Has a start and a go-live date.",
    "An enabler in a particular role: not required by the result directly, but a prerequisite of an enabler that is. Its cost is shared by the results of everything built on it. The same enabler can be required by one result and a foundation for another.",
    "The accountable role for a process. Used as a filter.",
    "A result achieved together by several processes. Its lead process (result.process_id) is accountable; its value and cost are split across the sharing processes by share, and it appears in each of their lanes and figures.",
    "The explicit link 'result requires enabler', with a weight saying how much of the result the enabler accounts for. Drives value attribution and cost allocation.",
    "One enabler needs another to be live before it can go live itself.",
    "The due date is when the result should be achieved. The ready date is when it can be: the latest go-live across its required enablers and their prerequisites.",
    "A result whose ready date is after its due date. Shown in red; counted on the scenario schedule.",
    "A prerequisite that goes live after the enabler that needs it. Shown as a red arrow.",
    "Run-rate is $/yr once fully adopted. Realised value is what is actually earned up to the horizon, after the adoption lag and ramp-up.",
    "The share of enabler cost charged to a result or process, including its share of foundations. Makes ROI and NPV per result possible.",
    "How an enabler's duration responds to more resources: 0 rigid, 1 linear, above 1 better than linear.",
    "The assumptions (oil price, realisation, overrun, discount rate, resources...). Changing them gives a scenario, compared with the base case."),
  question = c("Where does the value land, and who owns it?", "What tangible outcome do we commit to, by when?",
               "How much better does the process get?", "What step can management check has happened?",
               "What is the result worth?", "What do we build, when, for how much?", "What has to exist first?",
               rep("", 11)),
  example = c("Surveillance de yacimiento, owner Gerencia de Desarrollo y Producci\u00f3n",
              "K-P04-01 Employees per 100 wells, due 2029-12",
              "Employees per 100 wells: 2 \u2192 0.4",
              "M-X-04 250 wells per engineer, due 2029-12",
              "$6M/yr for employees per 100 wells",
              "Agentic AI, 2028Q1-2028Q4, $4M capex",
              "Data governance, semantic layer, WITSML upgrade",
              rep("", 11)),
  where = c("sheet process", "sheet result", "result.kind = kpi", "result.kind = milestone", "result.value_musd",
            "sheet enabler", "derived from enabler_dependency", "process.owner", "sheet result_process", "sheet result_enabler",
            "sheet enabler_dependency", "result.due / computed", "computed", "computed", "computed", "computed",
            "enabler.scalability", "sheet config"),
  stringsAsFactors = FALSE
)

#' Foundation-to-value tree for one result (pure; drawn by tree_svg())
#'
#' Columns, left to right: prerequisites (deepest first), required
#' enablers, the result, its value. An enabler sits one column left of the
#' leftmost enabler that needs it, so every dependency arrow points right.
#' @return list(nodes, edges).
result_tree <- function(data, model, result_id) {
  g <- model$graph
  ch <- g$chains[[result_id]]
  en <- c(ch$direct, ch$foundation)
  lvl <- stats::setNames(rep(NA_real_, length(en)), en)
  get_lvl <- function(e) {
    if (!is.na(lvl[[e]])) return(lvl[[e]])
    deps <- intersect(g$dependents[[e]], en)
    l <- if (length(deps)) 1 + max(vapply(deps, get_lvl, 1)) else 0
    lvl[[e]] <<- l
    l
  }
  for (e in en) get_lvl(e)
  maxl <- max(lvl)
  e <- data$enabler[match(en, data$enabler$id), ]
  alloc <- enabler_costs(model, result_id)[en]
  r <- data$result[data$result$id == result_id, ]
  p <- portfolio(model, result_id)
  late <- result_id %in% model$late$result_id
  nodes <- data.frame(
    id = en, type = ifelse(en %in% ch$direct, "enabler", "foundation"),
    group = e$enabler_group, col = maxl - lvl[en],
    label = e$name,
    sub = ifelse(en %in% ch$direct,
                 sprintf("required %s \u00b7 %s", fmt_pct(g$weight[en, result_id]), fmt_musd(alloc)),
                 sprintf("foundation \u00b7 %s", fmt_musd(alloc))),
    milestones = vapply(en, function(i) q_of(model$schedule$end[model$schedule$id == i]), ""),
    stringsAsFactors = FALSE)
  nodes <- nodes[order(nodes$col, match(nodes$group, GROUPS$id), nodes$label), ]
  sh <- g$share[result_id, ]
  sh <- sh[sh > 0]
  pname <- if (length(sh) > 1) sprintf("shared by %d processes", length(sh))
           else data$process$name[data$process$id == r$process_id]
  nodes <- rbind(nodes,
    data.frame(id = result_id, type = paste(r$kind, if (late) "late"), group = "", col = maxl + 1,
               label = paste0(if (r$kind == "kpi") "KPI \u00b7 " else "Milestone \u00b7 ", r$name),
               sub = if (r$kind == "kpi") sprintf("%s \u2192 %s \u00b7 due %s", fmt_num(r$baseline, r$unit), fmt_num(r$target, r$unit), r$due)
                     else sprintf("due %s \u00b7 ready %s", r$due, q_of(model$ready[[result_id]])),
               milestones = if (late) "late" else "", stringsAsFactors = FALSE),
    data.frame(id = "value", type = "value", group = "", col = maxl + 2,
               label = if (p$run_rate > 0) paste0(fmt_musd(p$run_rate), "/yr \u00b7 ", pname) else paste("No direct value \u00b7", pname),
               sub = if (length(sh) > 1) paste("split", paste(sprintf("%s %s", names(sh), fmt_pct(sh)), collapse = " \u00b7 "))
                     else sprintf("%s to %s \u00b7 NPV %s", fmt_musd(p$total_value), model$cfg$horizon_end, fmt_musd(p$npv)),
               milestones = "", stringsAsFactors = FALSE))
  dep <- data$enabler_dependency
  dep <- dep[dep$enabler_id %in% en & dep$requires_id %in% en, ]
  edges <- rbind(
    data.frame(from = dep$requires_id, to = dep$enabler_id, type = rep("dependency", nrow(dep)),
               label = rep("", nrow(dep)), stringsAsFactors = FALSE),
    data.frame(from = ch$direct, to = result_id, type = "link",
               label = fmt_pct(g$weight[ch$direct, result_id]), stringsAsFactors = FALSE),
    data.frame(from = result_id, to = "value", type = "value", label = "", stringsAsFactors = FALSE))
  rownames(nodes) <- NULL
  list(nodes = nodes, edges = edges)
}

#' Draw a tree (from kpi_tree() or the concept tree) as inline SVG
tree_svg <- function(tree, col_titles = NULL, node_w = 200, node_h = 46, gap_x = 64, gap_y = 14) {
  n <- tree$nodes
  ncol <- max(n$col) + 1
  rows <- tabulate(n$col + 1, ncol)
  max_rows <- max(rows)
  top <- if (is.null(col_titles)) 8 else 30
  H <- top + max_rows * (node_h + gap_y) + 8
  W <- ncol * node_w + (ncol - 1) * gap_x + 4
  n$row <- stats::ave(n$col, n$col, FUN = seq_along) - 1
  n$x <- 2 + n$col * (node_w + gap_x)
  n$y <- top + (max_rows - rows[n$col + 1]) * (node_h + gap_y) / 2 + n$row * (node_h + gap_y)
  pos <- function(id) n[match(id, n$id), ]
  esc <- function(x) htmltools::htmlEscape(x)
  trunc <- function(x, m) ifelse(nchar(x) > m, paste0(substr(x, 1, m - 1), "\u2026"), x)
  edges <- vapply(seq_len(nrow(tree$edges)), function(i) {
    a <- pos(tree$edges$from[i])
    b <- pos(tree$edges$to[i])
    x1 <- a$x + node_w
    y1 <- a$y + node_h / 2
    x2 <- b$x
    y2 <- b$y + node_h / 2
    mx <- (x1 + x2) / 2
    lab <- if (nzchar(tree$edges$label[i])) sprintf(
      '<text class="gl-elab" x="%.1f" y="%.1f">%s</text>', x1 + 5, y1 - 4, esc(tree$edges$label[i])) else ""
    sprintf('<path class="gl-edge %s" d="M%.1f,%.1fC%.1f,%.1f %.1f,%.1f %.1f,%.1f" marker-end="url(#gl-ah)"/>%s',
            tree$edges$type[i], x1, y1, mx, y1, mx, y2, x2 - 2, y2, lab)
  }, "")
  nodes <- vapply(seq_len(nrow(n)), function(i) {
    r <- n[i, ]
    bar <- if (r$group %in% GROUPS$id) sprintf('<rect class="gl-bar %s" x="%.1f" y="%.1f" width="4" height="%d"/>',
                                               r$group, r$x, r$y, node_h) else ""
    ms <- if (nzchar(r$milestones)) sprintf(
      '<text class="gl-mst%s" x="%.1f" y="%.1f" text-anchor="end">%s</text>',
      if (r$milestones == "late") " late" else "", r$x + node_w - 6, r$y + 13, esc(r$milestones)) else ""
    sprintf('<g class="gl-node %s"><title>%s</title><rect x="%.1f" y="%.1f" width="%d" height="%d" rx="4"/>%s<text class="gl-t" x="%.1f" y="%.1f">%s</text><text class="gl-s" x="%.1f" y="%.1f">%s</text>%s</g>',
            r$type, esc(paste(r$label, "\u2014", r$sub)), r$x, r$y, node_w, node_h, bar,
            r$x + 10, r$y + 19, esc(trunc(r$label, if (nzchar(r$milestones)) 30 - ceiling(nchar(r$milestones) * 0.9) else 30)), r$x + 10, r$y + 35, esc(trunc(r$sub, 33)), ms)
  }, "")
  titles <- if (is.null(col_titles)) "" else paste(vapply(seq_len(ncol), function(c) sprintf(
    '<text class="gl-col" x="%.1f" y="14">%s</text>', 2 + (c - 1) * (node_w + gap_x), esc(col_titles[c])), ""), collapse = "")
  htmltools::HTML(sprintf(
    '<svg class="gl-svg" width="%.0f" height="%.0f" viewBox="0 0 %.0f %.0f" role="img"><defs><marker id="gl-ah" viewBox="0 0 6 6" refX="5" refY="3" markerWidth="6" markerHeight="6" orient="auto"><path class="gl-arrow" d="M0,0L6,3L0,6Z"/></marker></defs>%s%s%s</svg>',
    W, H, W, H, titles, paste(edges, collapse = ""), paste(nodes, collapse = "")))
}

#' Column titles for a result tree
#'
#' Left columns hold prerequisites by level. A required enabler that is
#' also a prerequisite of another required enabler sits there too, so they
#' are titled "Prerequisites" rather than "Foundations"; each box says its role.
tree_titles <- function(tree) {
  ncol <- max(tree$nodes$col) + 1
  n_pre <- ncol - 3
  c(if (n_pre > 0) paste0("Prerequisites", if (n_pre > 1) paste0(" (level ", n_pre:1, ")") else ""),
    "Required enablers", "Result", "Value (process)")
}

#' Generic concept tree: foundation -> enabler -> results (KPI, milestone) -> process value
concept_tree <- function() {
  nodes <- data.frame(
    id = c("f1", "f2", "e1", "e2", "k", "m", "v"),
    type = c("foundation", "foundation", "enabler", "enabler", "kpi", "milestone", "value"),
    group = c("infra", "data", "digital", "people", "", "", ""),
    col = c(0, 0, 1, 1, 2, 2, 3),
    label = c("Foundation (infrastructure)", "Foundation (data)", "Enabler (digital solution)",
              "Enabler (people / adoption)", "Result: KPI", "Result: milestone", "Value of the process"),
    sub = c("prerequisite \u00b7 cost shared", "e.g. data platform", "money + people in \u00b7 go-live",
            "training, change, new roles", "baseline \u2192 target, due date", "achieved or not, due date",
            "$M per year, sum of its results"),
    milestones = "", stringsAsFactors = FALSE)
  edges <- data.frame(from = c("f1", "f2", "e1", "e2", "e1", "k", "m"), to = c("e1", "e1", "k", "k", "m", "v", "v"),
                      type = c("dependency", "dependency", "link", "link", "link", "value", "value"),
                      label = c("", "", "70%", "30%", "", "", ""), stringsAsFactors = FALSE)
  list(nodes = nodes, edges = edges)
}
