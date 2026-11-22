# Building blocks shared by the views: headline figures, the scenario
# chart and the concept diagram (plain SVG, no chart library).

#' Headline figures for a model's scope
#' @param compare optional base portfolio() to show the change against.
headline <- function(data, model, compare = NULL, note = NULL) {
  p <- portfolio(model)
  h <- model$cfg$horizon_end
  delta <- function(a, b, fmt = fmt_musd, good_up = TRUE) {
    if (is.null(compare) || is.na(a) || is.na(b) || abs(a - b) < 0.05) return(NULL)
    d <- a - b
    tags$span(class = paste("fig-d", if ((d > 0) == good_up) "pos" else "neg"),
              paste0(if (d > 0) "+" else "\u2212", sub("^\u2212", "", fmt(abs(d)))))
  }
  fig <- function(label, value, sub, d = NULL) tags$div(class = "fig",
    tags$div(class = "fig-l", label), tags$div(class = "fig-v", value, d), tags$div(class = "fig-s", sub))
  n_late <- nrow(model$late)
  tags$div(class = "figs",
    fig("Investment", fmt_musd(p$total_cost, 0), paste("to", h), delta(p$total_cost, compare$total_cost, good_up = FALSE)),
    fig("Value", fmt_musd(p$total_value, 0), paste("realised to", h), delta(p$total_value, compare$total_value)),
    fig("Net present value", fmt_musd(p$npv, 0), fmt_pct(model$cfg$discount_rate), delta(p$npv, compare$npv)),
    fig("All milestones ready", q_of(p$last_ready),
        if (n_late) tags$span(class = "neg", sprintf("%d late", n_late)) else if (is.na(p$last_ready)) "no milestone in scope" else "all on time",
        if (!is.null(compare) && !is.na(p$last_ready) && !is.na(compare$last_ready) && abs(p$last_ready - compare$last_ready) > 0.01)
          tags$span(class = paste("fig-d", if (p$last_ready < compare$last_ready) "pos" else "neg"),
                    sprintf("%+.0f mo", (p$last_ready - compare$last_ready) * 12))),
    if (!is.null(note)) tags$div(class = "fig-note", note))
}

nice_ticks <- function(a, b, n = 4) {
  sp <- b - a
  if (sp <= 0) return(a)
  s0 <- sp / n
  mg <- 10^floor(log10(s0))
  st <- c(1, 2, 2.5, 5, 10)[which(c(1, 2, 2.5, 5, 10) * mg >= s0)[1]] * mg
  seq(ceiling(a / st) * st, floor(b / st) * st, by = st)
}

#' Cumulative net value, scenario vs base, with annual value and cost
cash_chart <- function(p, b, W = 760, H = 260) {
  yrs <- p$years
  L <- 52; R <- 70; T <- 18; B <- 28
  lo <- min(0, -p$cost, p$cum_net, b$cum_net); hi <- max(0, p$value, p$cum_net, b$cum_net)
  if (hi - lo < 1e-9) hi <- lo + 10                         # nothing in scope: a flat zero line
  pad <- (hi - lo) * 0.06; lo <- lo - pad; hi <- hi + pad
  sx <- function(i) L + (i - 0.5) / length(yrs) * (W - L - R)
  sy <- function(v) T + (hi - v) / (hi - lo) * (H - T - B)
  bw <- (W - L - R) / length(yrs) * 0.22
  o <- character(0)
  for (t in nice_ticks(lo, hi, 5)) o <- c(o, sprintf(
    '<line class="ch-grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="ch-ax" x="%d" y="%.1f" text-anchor="end">%s</text>',
    L, W - R, sy(t), sy(t), L - 8, sy(t) + 3.5, formatC(t, format = "f", digits = 0)))
  o <- c(o, sprintf('<line class="ch-zero" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/>', L, W - R, sy(0), sy(0)))
  for (i in seq_along(yrs)) o <- c(o, sprintf(
    '<rect class="ch-val" x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="1.5"><title>%s value %s</title></rect><rect class="ch-cost" x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="1.5"><title>%s cost %s</title></rect><text class="ch-ax" x="%.1f" y="%d" text-anchor="middle">%s</text>',
    sx(i) - bw - 1, sy(p$value[i]), bw, sy(0) - sy(p$value[i]), yrs[i], fmt_musd(p$value[i]),
    sx(i) + 1, sy(0), bw, sy(-p$cost[i]) - sy(0), yrs[i], fmt_musd(p$cost[i]),
    sx(i), H - 8, yrs[i]))
  line <- function(v, cls) sprintf('<path class="%s" d="%s"/>', cls,
    paste0(ifelse(seq_along(v) == 1, "M", "L"), sprintf("%.1f,%.1f", sx(seq_along(v)), sy(v)), collapse = ""))
  n <- length(yrs)
  o <- c(o, line(b$cum_net, "ch-base"), line(p$cum_net, "ch-line"),
         sprintf('<circle class="ch-end" cx="%.1f" cy="%.1f" r="3.5"/><text class="ch-lab" x="%.1f" y="%.1f">%s</text>',
                 sx(n), sy(p$cum_net[n]), sx(n) + 8, sy(p$cum_net[n]) + 4, fmt_musd(p$cum_net[n], 0)),
         sprintf('<text class="ch-lab base" x="%.1f" y="%.1f">%s</text>', sx(n) + 8, sy(b$cum_net[n]) + 4,
                 if (abs(b$cum_net[n] - p$cum_net[n]) > (hi - lo) * 0.05) fmt_musd(b$cum_net[n], 0) else ""))
  htmltools::HTML(sprintf('<svg class="chart" viewBox="0 0 %d %d" role="img" aria-label="Cumulative net value">%s</svg>',
                          W, H, paste(o, collapse = "")))
}

#' The logic: investment -> enablers (concepts) + processes (target M) -> milestones -> metrics (curve) -> value
concept_diagram <- function() {
  box <- function(x, y, w, h, t, s = NULL, cls = "") sprintf(
    '<g class="cd %s"><rect x="%d" y="%d" width="%d" height="%d" rx="14"/><text class="cd-t" x="%d" y="%d" text-anchor="middle">%s</text>%s</g>',
    cls, x, y, w, h, x + w / 2, y + h / 2 + (if (is.null(s)) 5 else -2), t,
    if (is.null(s)) "" else sprintf('<text class="cd-s" x="%d" y="%d" text-anchor="middle">%s</text>', x + w / 2, y + h / 2 + 15, s))
  m <- function(x, y, t, anchor = "middle") sprintf('<text class="cd-m" x="%d" y="%d" text-anchor="%s">%s</text>', x, y, anchor, t)
  arrow <- function(d, x2, y2, dir = "r") sprintf('<path class="cd-a" d="%s"/><path class="cd-h" d="M%d,%d%s"/>', d, x2, y2,
    switch(dir, r = "l-8,-4.5v9z", d = "l-4.5,-8h9z"))
  cpt <- paste(vapply(0:2, function(i) sprintf('<g class="cd c"><rect x="322" y="%d" width="96" height="22" rx="6"/><text class="cd-c" x="370" y="%d" text-anchor="middle">concept</text></g>',
    196 + i * 27, 211 + i * 27), ""), collapse = "")
  htmltools::HTML(paste0('<svg class="diagram" viewBox="0 0 980 314" role="img" aria-label="How maturity, investment and value connect">',
    m(210, 24, "Digital maturity target per process (M1 \u2192 M5)"),
    box(150, 36, 150, 64, "Processes", "current \u2192 target", "p"),
    arrow("M300,68H474", 482, 68),
    box(0, 196, 130, 64, "Investment", "capex, people, opex", "i"),
    arrow("M130,228H164", 170, 228),
    '<g class="cd e"><rect x="170" y="186" width="254" height="104" rx="14"/><text class="cd-t" x="244" y="236" text-anchor="middle">Enablers</text><text class="cd-s" x="244" y="253" text-anchor="middle">dates, cost, FTE</text></g>', cpt,
    m(297, 306, "level (M) it enables"),
    '<path class="cd-a" d="M424,238H452V68"/><circle class="cd-j" cx="452" cy="68" r="3"/>',
    box(482, 36, 150, 64, "Milestones", "due date", "ms"),
    m(557, 120, "level (M)"),
    arrow("M632,68H660", 666, 68),
    box(666, 36, 150, 64, "Metrics", "baseline \u2192 target", "k"),
    m(741, 120, "impact curve: % vs M"),
    arrow("M816,68H844", 850, 68),
    box(850, 36, 128, 64, "Value", "$M per year", "v"),
    '</svg>'))
}

#' Maturity levels: name, key trait, description
levels_table <- function() {
  tags$table(class = "tt lv-tt",
    tags$thead(tags$tr(tags$th("Level"), tags$th("Key trait"), tags$th("What it looks like"))),
    tags$tbody(lapply(seq_len(nrow(LEVELS)), function(i) tags$tr(
      tags$td(tags$span(class = paste0("lv-chip l", i), LEVELS$code[i]), " ", tags$b(LEVELS$name[i])),
      tags$td(LEVELS$key[i]), tags$td(class = "hint", LEVELS$description[i])))))
}

#' How levels differ, by dimension
dimensions_table <- function() {
  d <- LEVEL_DIMENSIONS
  tags$table(class = "tt dim-tt",
    tags$thead(tags$tr(tags$th(""), lapply(LEVELS$code, function(x) tags$th(x)))),
    tags$tbody(lapply(seq_len(nrow(d)), function(i) tags$tr(
      tags$td(tags$b(d$dimension[i])), lapply(LEVELS$code, function(x) tags$td(d[[x]][i]))))))
}

#' Impact curves: % of a metric's impact reached at each level
curves_chart <- function(curves, W = 520, H = 230) {
  L <- 44; R <- 150; T <- 14; B <- 26
  x <- function(l) L + (l - 1) / 4 * (W - L - R)
  y <- function(v) T + (1 - v / 100) * (H - T - B)
  o <- character(0)
  for (v in c(0, 25, 50, 75, 100)) o <- c(o, sprintf('<line class="ch-grid" x1="%d" x2="%.1f" y1="%.1f" y2="%.1f"/><text class="ch-ax" x="%d" y="%.1f" text-anchor="end">%d%%</text>',
    L, x(5), y(v), y(v), L - 8, y(v) + 3.5, v))
  for (l in 1:5) o <- c(o, sprintf('<text class="ch-ax" x="%.1f" y="%d" text-anchor="middle">M%d</text>', x(l), H - 8, l))
  ly <- numeric(0)
  for (i in seq_len(nrow(curves))) {
    v <- unlist(curves[i, paste0("m", 1:5)])
    o <- c(o, sprintf('<polyline class="cv-line c%d" points="%s"/>', (i - 1) %% 6 + 1,
                      paste(sprintf("%.1f,%.1f", x(1:5), y(v)), collapse = " ")),
           paste(sprintf('<circle class="cv-dot c%d" cx="%.1f" cy="%.1f" r="2.5"/>', (i - 1) %% 6 + 1, x(1:5), y(v)), collapse = ""))
  }
  # labels on the right, spread so they do not overlap
  yy <- vapply(seq_len(nrow(curves)), function(i) y(curves$m4[i]), 0)
  ord <- order(yy)
  pos <- yy[ord]
  for (j in seq_along(pos)[-1]) pos[j] <- max(pos[j], pos[j - 1] + 14)
  for (j in seq_along(ord)) {
    i <- ord[j]
    o <- c(o, sprintf('<text class="cv-lab c%d" x="%.1f" y="%.1f">%s</text>', (i - 1) %% 6 + 1, x(5) + 12, pos[j] + 4,
                      htmltools::htmlEscape(curves$name[i])))
  }
  htmltools::HTML(sprintf('<svg class="chart curves" viewBox="0 0 %d %d" role="img" aria-label="Impact curves">%s</svg>',
                          W, H, paste(o, collapse = "")))
}
