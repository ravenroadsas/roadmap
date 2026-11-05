# Glossary tab: definitions, and a foundation-to-value tree drawn as SVG.

GLOSSARY <- data.frame(
  term = c("Enabler", "Foundation", "KPI", "Value", "Milestone",
           "Process", "Process owner", "Enabler link (weight)", "Dependency", "Late dependency",
           "Ready date", "Run-rate vs realised value", "Allocated cost", "Scalability", "Config / scenario"),
  core = c(rep(TRUE, 5), rep(FALSE, 10)),
  definition = c(
    "Something we invest in and build: a digital solution, data, infrastructure or a people / change initiative. The only element that consumes money, internal staff (fte_internal) and partner staff (fte_partner). Has a start and a go-live date.",
    "Not a separate thing: an enabler in a particular role. It is needed by other enablers (a prerequisite) but does not move the KPI itself. Its cost is shared by the KPIs of everything built on it. The same enabler can be direct for one KPI and a foundation for another.",
    "A measurable result on one process, with a baseline and a target, in its own unit (days, %, bbl/FTE). Says how much better the process gets, not what is built.",
    "What a KPI is worth in money when its target is reached (value_musd per year). The only place money comes in. Scaled by realisation, the value driver (oil price or labour cost) and adoption over time.",
    "A visible checkpoint delivered by one enabler. Costs nothing and creates no value; it is for tracking and communication. Moves with its enabler when the build is shortened.",
    "The business process being transformed. Every KPI belongs to exactly one process.",
    "The accountable role for a process. Used as a filter.",
    "Says that an enabler helps move a KPI, and how much relative to the other enablers on the same KPI. Drives value attribution and cost allocation.",
    "One enabler needs another to be live before it can go live itself.",
    "A dependency where the prerequisite goes live after the enabler that needs it. Shown as a red arrow; counted on the scenario schedule.",
    "When a KPI can start producing value: the latest go-live across its enablers and all their prerequisites. Value then starts after the adoption lag and ramps up.",
    "Run-rate is $/yr once fully adopted. Realised value is what is actually earned up to the horizon, after delays and ramp-up.",
    "The share of enabler cost charged to a KPI or process, including its share of foundations. Makes ROI and NPV per KPI possible.",
    "How an enabler's duration responds to more resources: 0 rigid, 1 linear, above 1 better than linear.",
    "The assumptions (oil price, realisation, overrun, discount rate, resources...). Changing them gives a scenario, compared with the base case."),
  question = c("What do we build, when, for how much?", "What has to exist first?",
               "How do we know the process improved?", "What is the improvement worth?",
               "What can management check has happened?", "", "", "", "", "", "", "", "", "", ""),
  example = c("Predictive maintenance platform, 2027Q1-2028Q2, $6M capex",
              "Hybrid cloud, private 5G, OT cybersecurity",
              "Work-order turnaround: 18 -> 7 days",
              "$6.4M/yr for the turnaround KPI",
              "Predictive maintenance on critical equipment, 2028-06",
              "", "", "", "", "", "", "", "", "", ""),
  where = c("sheet enabler", "derived from enabler_dependency", "sheet kpi", "kpi.value_musd",
            "sheet milestone", "sheet process", "process.owner", "sheet enabler_link",
            "sheet enabler_dependency", "computed", "computed", "computed", "computed",
            "enabler.scalability", "sheet config"),
  stringsAsFactors = FALSE
)

#' Foundation-to-value tree for one KPI (pure; drawn by tree_svg())
#'
#' Columns, left to right: foundations (deepest first), direct enablers,
#' the KPI, its value. An enabler sits one column left of the leftmost
#' enabler that needs it, so every dependency arrow points right.
#' @return list(nodes, edges).
kpi_tree <- function(data, model, kpi_id) {
  g <- model$graph
  ch <- g$chains[[kpi_id]]
  en <- c(ch$direct, ch$foundation)
  # level 0 = direct only; otherwise 1 + max level of dependents in the chain
  lvl <- stats::setNames(rep(NA_real_, length(en)), en)
  get_lvl <- function(e) {
    if (!is.na(lvl[[e]])) return(lvl[[e]])
    deps <- intersect(g$dependents[[e]], en)
    l <- if (length(deps)) 1 + max(vapply(deps, get_lvl, 1)) else 0
    if (!(e %in% ch$direct) && !length(deps)) l <- 1
    lvl[[e]] <<- l
    l
  }
  for (e in en) get_lvl(e)
  maxl <- max(lvl)
  e <- data$enabler[match(en, data$enabler$id), ]
  alloc <- enabler_costs(model, kpi_id)[en]
  ms <- model$milestones
  k <- data$kpi[data$kpi$id == kpi_id, ]
  p <- portfolio(model, kpi_id)
  nodes <- data.frame(
    id = en, type = ifelse(en %in% ch$direct, "enabler", "foundation"),
    group = e$enabler_group, col = maxl - lvl[en],
    label = e$name,
    sub = ifelse(en %in% ch$direct,
                 sprintf("direct %s \u00b7 %s", fmt_pct(g$weight[en, kpi_id]), fmt_musd(alloc)),
                 sprintf("foundation \u00b7 %s", fmt_musd(alloc))),
    milestones = vapply(en, function(i) {
      m <- ms$id[ms$enabler_id == i]
      lab <- paste(m, collapse = " ")
      if (nchar(lab) > 8) sprintf("%d milestones", length(m)) else lab
    }, ""),
    stringsAsFactors = FALSE)
  nodes <- nodes[order(nodes$col, match(nodes$group, GROUPS$id), nodes$label), ]
  nodes <- rbind(nodes,
    data.frame(id = kpi_id, type = "kpi", group = "", col = maxl + 1, label = k$name,
               sub = sprintf("%s \u00b7 %s \u2192 %s", data$process$name[data$process$id == k$process_id],
                             fmt_num(k$baseline, k$unit), fmt_num(k$target, k$unit)),
               milestones = "", stringsAsFactors = FALSE),
    data.frame(id = "value", type = "value", group = "", col = maxl + 2,
               label = paste0(fmt_musd(p$run_rate), "/yr at full adoption"),
               sub = sprintf("%s to %s \u00b7 NPV %s", fmt_musd(p$total_value), model$cfg$horizon_end, fmt_musd(p$npv)),
               milestones = "", stringsAsFactors = FALSE))
  dep <- data$enabler_dependency
  dep <- dep[dep$enabler_id %in% en & dep$requires_id %in% en, ]
  edges <- rbind(
    data.frame(from = dep$requires_id, to = dep$enabler_id, type = rep("dependency", nrow(dep)),
               label = rep("", nrow(dep)), stringsAsFactors = FALSE),
    data.frame(from = ch$direct, to = kpi_id, type = "link",
               label = fmt_pct(g$weight[ch$direct, kpi_id]), stringsAsFactors = FALSE),
    data.frame(from = kpi_id, to = "value", type = "value", label = "", stringsAsFactors = FALSE))
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
      '<path class="gl-ms" d="M%1$.1f,%2$.1fl5,5l-5,5l-5,-5z"/><text class="gl-mst" x="%3$.1f" y="%4$.1f" text-anchor="end">%5$s</text>',
      r$x + node_w - 10, r$y + 5, r$x + node_w - 18, r$y + 13, esc(r$milestones)) else ""
    sprintf('<g class="gl-node %s"><title>%s</title><rect x="%.1f" y="%.1f" width="%d" height="%d" rx="4"/>%s<text class="gl-t" x="%.1f" y="%.1f">%s</text><text class="gl-s" x="%.1f" y="%.1f">%s</text>%s</g>',
            r$type, esc(paste(r$label, "\u2014", r$sub)), r$x, r$y, node_w, node_h, bar,
            r$x + 10, r$y + 19, esc(trunc(r$label, if (nzchar(r$milestones)) 30 - ceiling(nchar(r$milestones) * 0.9) - 2 else 30)), r$x + 10, r$y + 35, esc(trunc(r$sub, 33)), ms)
  }, "")
  titles <- if (is.null(col_titles)) "" else paste(vapply(seq_len(ncol), function(c) sprintf(
    '<text class="gl-col" x="%.1f" y="14">%s</text>', 2 + (c - 1) * (node_w + gap_x), esc(col_titles[c])), ""), collapse = "")
  htmltools::HTML(sprintf(
    '<svg class="gl-svg" width="%.0f" height="%.0f" viewBox="0 0 %.0f %.0f" role="img"><defs><marker id="gl-ah" viewBox="0 0 6 6" refX="5" refY="3" markerWidth="6" markerHeight="6" orient="auto"><path class="gl-arrow" d="M0,0L6,3L0,6Z"/></marker></defs>%s%s%s</svg>',
    W, H, W, H, titles, paste(edges, collapse = ""), paste(nodes, collapse = "")))
}

#' Column titles for a KPI tree
#'
#' Left columns hold prerequisites by level. A direct enabler that is also
#' a prerequisite of another direct enabler sits there too, so they are
#' titled "Prerequisites" rather than "Foundations"; each box says its role.
tree_titles <- function(tree) {
  ncol <- max(tree$nodes$col) + 1
  n_pre <- ncol - 3
  c(if (n_pre > 0) paste0("Prerequisites", if (n_pre > 1) paste0(" (level ", n_pre:1, ")") else ""),
    "Direct enablers", "KPI on a process", "Value")
}

#' Generic concept tree: foundation -> enabler -> KPI -> value
concept_tree <- function() {
  nodes <- data.frame(
    id = c("f1", "f2", "e1", "e2", "k", "v"),
    type = c("foundation", "foundation", "enabler", "enabler", "kpi", "value"),
    group = c("infra", "data", "digital", "people", "", ""),
    col = c(0, 0, 1, 1, 2, 3),
    label = c("Foundation (infrastructure)", "Foundation (data)", "Enabler (digital solution)",
              "Enabler (people / adoption)", "KPI on a process", "Value"),
    sub = c("needed by enablers \u00b7 cost shared", "e.g. data platform", "money + people in \u00b7 go-live",
            "training, change, new roles", "baseline \u2192 target", "$M per year at target"),
    milestones = c("", "", "M", "", "", ""), stringsAsFactors = FALSE)
  edges <- data.frame(from = c("f1", "f2", "e1", "e2", "k"), to = c("e1", "e1", "k", "k", "v"),
                      type = c("dependency", "dependency", "link", "link", "value"),
                      label = c("", "", "weight 70%", "30%", ""), stringsAsFactors = FALSE)
  list(nodes = nodes, edges = edges)
}
