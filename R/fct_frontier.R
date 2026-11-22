# Efficient frontier of digital maturity targets.
#
# Every combination of targets (each process from its current level to M5)
# is evaluated with the same formulas as run_model(), on plan resources:
#   * cost: an enabler is needed when, for some process, the target reaches
#     the lowest level of that process's milestones that need it; its cost
#     is then counted in full (fixed) or scaled to the processes that need
#     it (per process). Costs are precomputed per enabler.
#   * value: a metric depends only on the targets of the processes whose
#     milestones move it, so its value is precomputed for every combination
#     of those few targets and looked up.
# The frontier keeps the combinations with the highest NPV for their
# investment (no other combination costs less and earns more).

#' Evaluate every combination of maturity targets
#' @param cfg scenario values (levers); acceleration is not applied.
#' @param max_combos above this, each process only takes current, base target or M5.
#' @return list(points = data frame investment, value, npv, roi, idx; targets = matrix
#'   combination x process; frontier = row indices; base, n).
frontier_enumerate <- function(data, graph, cfg, base = cfg, max_combos = 2e6) {
  p <- data$process
  cfg$resource_multiplier <- 1
  opts <- lapply(seq_len(nrow(p)), function(i) p$current_level[i]:5)
  n <- prod(lengths(opts))
  if (n > max_combos) opts <- lapply(seq_len(nrow(p)), function(i) sort(unique(c(p$current_level[i], p$target_level[i], 5L))))
  names(opts) <- p$id
  grid <- as.matrix(expand.grid(opts, KEEP.OUT.ATTRS = FALSE))
  storage.mode(grid) <- "integer"
  colnames(grid) <- p$id

  start <- floor(min(q_to_time(data$enabler$start_q)))
  years <- seq(start, cfg$horizon_end)
  disc <- 1 / (1 + cfg$discount_rate)^(years - start)
  sched <- schedule(data$enabler, cfg)
  ready <- milestone_ready(graph, sched)
  parts <- cost_parts(data$enabler, cfg, years, sched)
  full <- parts$capex + parts$people + parts$opex
  e_tot <- rowSums(full)
  e_npv <- as.vector(full %*% disc)

  # cost: lowest milestone level per (enabler, process) that needs the enabler
  ms <- data$milestone
  ids <- graph$ids
  minlev <- matrix(Inf, length(ids), nrow(p), dimnames = list(ids, p$id))
  for (m in ms$id) {
    ch <- graph$chains[[m]]
    pid <- ms$process_id[ms$id == m]
    l <- ms$level[ms$id == m]
    for (e in c(ch$direct, ch$foundation)) minlev[e, pid] <- min(minlev[e, pid], l)
  }
  en <- data$enabler[match(ids, data$enabler$id), ]
  sc <- pmin(pmax(ifelse(is.na(en$scalability), 0, en$scalability), 0), 2)
  cost <- numeric(nrow(grid)); cost_npv <- numeric(nrow(grid))
  for (j in seq_along(ids)) {
    served <- which(is.finite(minlev[j, ]))
    if (!length(served)) next
    k <- rowSums(sweep(grid[, served, drop = FALSE], 2, minlev[j, served], ">=")) # processes needing it
    f <- if (en$cost_basis[j] == "per_process") ifelse(k > 0, (k / length(served))^sc[j], 0) else as.numeric(k > 0)
    cost <- cost + f * e_tot[[ids[j]]]
    cost_npv <- cost_npv + f * e_npv[j]
  }

  # value: per metric, a table over the targets of the processes that move it
  value <- numeric(nrow(grid)); value_npv <- numeric(nrow(grid))
  mt <- data$metric
  for (i in seq_len(nrow(mt))) {
    lk <- graph$metric_ms[[mt$id[i]]]
    procs <- unique(ms$process_id[ms$id %in% lk])
    sub <- unique(grid[, procs, drop = FALSE])
    tab <- t(apply(sub, 1, function(row) {
      tg <- stats::setNames(p$target_level, p$id)
      tg[procs] <- row
      ins <- milestones_in_scope(data, tg)
      st <- metric_steps(utils::modifyList(data, list(metric = mt[i, , drop = FALSE])), graph, ready, ins)
      v <- value_profile(mt[i, , drop = FALSE], st, cfg, base, years)
      c(sum(v), sum(v * disc))
    }))
    key_sub <- do.call(paste, c(as.data.frame(sub), sep = "|"))
    key_all <- do.call(paste, c(as.data.frame(grid[, procs, drop = FALSE]), sep = "|"))
    k <- match(key_all, key_sub)
    value <- value + tab[k, 1]
    value_npv <- value_npv + tab[k, 2]
  }

  pts <- data.frame(idx = seq_len(nrow(grid)), investment = cost, value = value,
                    npv = value_npv - cost_npv,
                    roi = ifelse(cost > 0, (value - cost) / cost, NA_real_))
  list(points = pts, targets = grid, frontier = frontier_rows(pts), n = nrow(grid),
       reduced = n > max_combos,
       base = match_targets(grid, stats::setNames(p$target_level, p$id)))
}

#' Rows on the efficient frontier: highest NPV for their investment
frontier_rows <- function(pts) {
  o <- order(pts$investment, -pts$npv)
  best <- -Inf
  keep <- integer(0)
  for (i in o) if (pts$npv[i] > best + 1e-9) { keep <- c(keep, i); best <- pts$npv[i] }
  keep
}

#' Row of the grid holding a set of targets
match_targets <- function(grid, targets) {
  key <- do.call(paste, c(as.data.frame(grid), sep = "|"))
  match(paste(targets[colnames(grid)], collapse = "|"), key)
}

#' Investment vs NPV: every combination (as density), the frontier, base and scenario
frontier_chart <- function(fr, scen_row = NA, pick = NA, ns = "", W = 820, H = 420) {
  pts <- fr$points
  L <- 64; R <- 24; T <- 22; B <- 40
  xlo <- 0; xhi <- max(pts$investment) * 1.04
  ylo <- min(0, pts$npv); yhi <- max(pts$npv, 0)
  pad <- (yhi - ylo) * 0.06; ylo <- ylo - pad; yhi <- yhi + pad
  sx <- function(v) L + (v - xlo) / (xhi - xlo) * (W - L - R)
  sy <- function(v) T + (yhi - v) / (yhi - ylo) * (H - T - B)
  o <- character(0)
  for (t in nice_ticks(ylo, yhi, 5)) o <- c(o, sprintf('<line class="ch-grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/><text class="ch-ax" x="%d" y="%.1f" text-anchor="end">%s</text>',
    L, W - R, sy(t), sy(t), L - 8, sy(t) + 3.5, formatC(t, format = "f", digits = 0)))
  for (t in nice_ticks(xlo, xhi, 6)) o <- c(o, sprintf('<text class="ch-ax" x="%.1f" y="%d" text-anchor="middle">%s</text>', sx(t), H - B + 18, formatC(t, format = "f", digits = 0)))
  o <- c(o, sprintf('<line class="ch-zero" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/>', L, W - R, sy(0), sy(0)),
         sprintf('<text class="ch-ax ttl" x="%d" y="%d" text-anchor="end">Investment to horizon, $M</text>', W - R, H - 4),
         sprintf('<text class="ch-ax ttl" x="%d" y="%d" text-anchor="start">NPV, $M</text>', L - 40, 10))
  # density: one square per occupied cell
  cx <- floor((sx(pts$investment) - L) / 6); cy <- floor((sy(pts$npv) - T) / 6)
  cell <- table(paste(cx, cy))
  xy <- do.call(rbind, strsplit(names(cell), " "))
  a <- pmin(1, 0.25 + 0.75 * log1p(as.vector(cell)) / log1p(max(cell)))
  o <- c(o, sprintf('<rect class="fr-cell" x="%d" y="%d" width="5" height="5" fill-opacity="%.2f"/>',
                    L + 6 * as.integer(xy[, 1]), T + 6 * as.integer(xy[, 2]), a))
  f <- pts[fr$frontier, ]
  o <- c(o, sprintf('<path class="fr-line" d="%s"/>', paste0(ifelse(seq_len(nrow(f)) == 1, "M", "L"),
                                                           sprintf("%.1f,%.1f", sx(f$investment), sy(f$npv)), collapse = "")))
  lv <- function(i) paste(sprintf("%s %s", colnames(fr$targets), lvl(fr$targets[i, ])), collapse = " \u00b7 ")
  tip <- function(i, title) htmltools::htmlEscape(sprintf("<b>%s</b><br>Investment %s \u00b7 NPV %s \u00b7 ROI %s<br>%s", title,
    fmt_musd(pts$investment[i], 0), fmt_musd(pts$npv[i], 0), fmt_pct(pts$roi[i]), lv(i)), attribute = TRUE)
  best <- f$idx[which.max(f$npv)]
  for (j in seq_len(nrow(f))) {
    i <- f$idx[j]
    o <- c(o, sprintf('<circle class="fr-pt%s%s" cx="%.1f" cy="%.1f" r="%s" data-pick="%d" data-tip="%s"/>',
      if (identical(i, pick)) " sel" else "", if (i == best) " best" else "", sx(pts$investment[i]), sy(pts$npv[i]),
      if (i == best || identical(i, pick)) "6" else "4.5", i, tip(i, if (i == best) "Highest NPV" else sprintf("Frontier portfolio %d", j))))
  }
  mark <- function(i, cls, label) if (!is.na(i)) sprintf('<g class="%s" data-pick="%d" data-tip="%s"><path d="M%.1f,%.1fl7,7l-7,7l-7,-7z"/><text x="%.1f" y="%.1f">%s</text></g>',
    cls, i, tip(i, label), sx(pts$investment[i]), sy(pts$npv[i]) - 7, sx(pts$investment[i]) + 10, sy(pts$npv[i]) + 4, label) else ""
  o <- c(o, mark(fr$base, "fr-mk base", "Base"), if (!identical(scen_row, fr$base)) mark(scen_row, "fr-mk scen", "Scenario"))
  htmltools::HTML(sprintf('<svg class="chart frontier" viewBox="0 0 %d %d" role="img" aria-label="Efficient frontier">%s</svg>',
                          W, H, paste(o, collapse = "")))
}
