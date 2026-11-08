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
  n_late <- nrow(model$late[model$late$result_id %in% p$results, , drop = FALSE])
  tags$div(class = "figs",
    fig("Investment", fmt_musd(p$total_cost, 0), paste("to", h), delta(p$total_cost, compare$total_cost, good_up = FALSE)),
    fig("Value", fmt_musd(p$total_value, 0), paste("realised to", h), delta(p$total_value, compare$total_value)),
    fig("Net present value", fmt_musd(p$npv, 0), fmt_pct(model$cfg$discount_rate), delta(p$npv, compare$npv)),
    fig("All results ready", q_of(p$last_ready),
        if (n_late) tags$span(class = "neg", sprintf("%d late", n_late)) else "all on time",
        if (!is.null(compare) && !is.na(compare$last_ready) && abs(p$last_ready - compare$last_ready) > 0.01)
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

#' The value chain as a concept diagram
concept_diagram <- function() {
  box <- function(x, y, w, t, s, cls) sprintf(
    '<g class="cd %s"><rect x="%d" y="%d" width="%d" height="54" rx="27"/><text class="cd-t" x="%d" y="%d">%s</text><text class="cd-s" x="%d" y="%d">%s</text></g>',
    cls, x, y, w, x + 22, y + 24, t, x + 22, y + 40, s)
  arrow <- function(x1, x2, y) sprintf('<path class="cd-a" d="M%d,%dL%d,%d"/><path class="cd-h" d="M%d,%dl-7,-4v8z"/>', x1, y, x2 - 2, y, x2, y)
  htmltools::HTML(paste0('<svg class="diagram" viewBox="0 0 940 80" role="img" aria-label="Value chain">',
    box(0, 12, 200, "Foundations", "enablers other enablers need", "f"), arrow(204, 236, 39),
    box(240, 12, 200, "Enablers", "money and people in", "e"), arrow(444, 476, 39),
    box(480, 12, 200, "Results", "due date, optional measure", "r"), arrow(684, 716, 39),
    box(720, 12, 216, "Value", "$ per year, for processes", "v"), "</svg>"))
}
