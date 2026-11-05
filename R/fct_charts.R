# Sensitivity charts: data preparation (pure, tested) and echarts4r rendering.

COL <- list(pos = "#2f8a55", neg = "#b4423a", ink = "#1b2025", muted = "#9aa3ab", accent = "#2f6db0")

flow_data <- function(model, base_model, result_ids) {
  p <- portfolio(model, result_ids)
  b <- portfolio(base_model, result_ids)
  data.frame(year = as.character(p$years), value = round(p$value, 2), cost = round(-p$cost, 2),
             cum_net = round(p$cum_net, 2), base_cum_net = round(b$cum_net, 2))
}

tornado_data <- function(data, graph, cfg, base, cfg_table, result_ids, resources = NULL) {
  t <- tornado(data, graph, cfg, base, cfg_table, result_ids, resources)
  npv <- portfolio(run_model(data, graph, cfg, base, resources), result_ids)$npv
  rows <- match(t$key, cfg_table$key)
  t$lever <- sprintf("%s (%s \u2192 %s)", t$label,
                     vapply(rows, function(i) fmt_cfg(cfg_table[i, ], cfg_table$low[i]), ""),
                     vapply(rows, function(i) fmt_cfg(cfg_table[i, ], cfg_table$high[i]), ""))
  t$d_low <- round(t$npv_low - npv, 2)
  t$d_high <- round(t$npv_high - npv, 2)
  t[rev(seq_len(nrow(t))), c("lever", "d_low", "d_high")]  # largest at the top once flipped
}

#' Short label with the result kind: "[KPI] Deferred production"
result_label <- function(data, ids) {
  r <- data$result[match(ids, data$result$id), ]
  paste0(ifelse(r$kind == "kpi", "\u25cf ", "\u25c6 "), r$name)
}

#' Value to horizon per result with value (scenario vs base)
result_value_data <- function(data, model, base_model, result_ids) {
  s <- rowSums(model$value[result_ids, , drop = FALSE])
  b <- rowSums(base_model$value[result_ids, , drop = FALSE])
  out <- data.frame(result = result_label(data, result_ids),
                    scenario = round(s, 1), base = round(b, 1))
  out <- out[out$scenario > 0 | out$base > 0, ]
  out[order(out$scenario), ]
}

#' Due date vs ready date (base and scenario) per result
ready_data <- function(data, model, base_model, result_ids) {
  q <- function(t) ceiling(t * 4 - 1e-9) / 4      # end of the quarter
  r <- data$result[match(result_ids, data$result$id), ]
  out <- data.frame(result = result_label(data, result_ids),
                    due = round(due_to_time(r$due), 3),
                    base = q(base_model$ready[result_ids]), scenario = q(model$ready[result_ids]))
  out$months_earlier <- round((out$base - out$scenario) * 12)
  out$late <- out$scenario > out$due + 1e-6
  out[order(-out$scenario), ]
}

chart_theme <- function(e) {
  e |>
    echarts4r::e_tooltip(trigger = "axis") |>
    echarts4r::e_legend(top = 0, textStyle = list(fontSize = 10, color = "#68727c")) |>
    echarts4r::e_text_style(fontFamily = "IBM Plex Sans", fontSize = 10)
}

chart_flow <- function(df) {
  df |>
    echarts4r::e_charts_("year") |>
    echarts4r::e_bar_("value", name = "Value", barGap = "-100%", itemStyle = list(color = COL$pos)) |>
    echarts4r::e_bar_("cost", name = "Cost", itemStyle = list(color = COL$neg)) |>
    echarts4r::e_line_("cum_net", name = "Cumulative net", symbolSize = 5,
                       itemStyle = list(color = COL$ink), lineStyle = list(width = 2)) |>
    echarts4r::e_line_("base_cum_net", name = "Base case", symbol = "none",
                       itemStyle = list(color = COL$muted), lineStyle = list(type = "dashed", width = 1.2)) |>
    echarts4r::e_grid(left = 50, right = 16, top = 30, bottom = 24) |>
    chart_theme()
}

chart_tornado <- function(df) {
  df |>
    echarts4r::e_charts_("lever") |>
    echarts4r::e_bar_("d_low", name = "Low value", barGap = "-100%", itemStyle = list(color = COL$muted)) |>
    echarts4r::e_bar_("d_high", name = "High value", itemStyle = list(color = COL$accent)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_grid(left = 210, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

chart_results <- function(df) {
  df |>
    echarts4r::e_charts_("result") |>
    echarts4r::e_bar_("scenario", name = "Scenario", itemStyle = list(color = COL$pos)) |>
    echarts4r::e_bar_("base", name = "Base", itemStyle = list(color = COL$muted)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_grid(left = 190, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

chart_ready <- function(df) {
  lo <- floor(min(df$scenario, df$base, df$due))
  df |>
    echarts4r::e_charts_("result") |>
    echarts4r::e_scatter_("base", name = "Base", symbol = "rect", symbolSize = c(3, 14),
                          itemStyle = list(color = COL$muted)) |>
    echarts4r::e_scatter_("scenario", name = "Scenario", symbolSize = 9, itemStyle = list(color = COL$accent)) |>
    echarts4r::e_scatter_("due", name = "Due", symbol = "diamond", symbolSize = 9, itemStyle = list(color = COL$neg)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_x_axis(min = lo, axisLabel = list(fontSize = 10)) |>
    echarts4r::e_grid(left = 190, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

#' Headline figures (top bar)
#'
#' Follows the results passed in: value comes from those results, cost is the
#' enabler cost allocated to them. When the enabler-group filter is partial,
#' the investment card also shows the part spent in the selected groups.
#' @param groups enabler groups selected in the filter.
#' @param filtered TRUE when the left-panel filters narrow the portfolio.
summary_strip <- function(data, model, result_ids, groups = GROUPS$id, filtered = FALSE) {
  stat <- function(l, v, s) tags$div(class = "stat", tags$div(class = "l", l), tags$div(class = "v", v), tags$div(class = "s", s))
  h <- model$cfg$horizon_end
  if (!length(result_ids)) {
    return(tags$div(class = "strip filtered",
      stat("No result matches the filters", "\u2013", "change or reset the filters")))
  }
  p <- portfolio(model, result_ids)
  share <- rowSums(model$graph$alloc[, result_ids, drop = FALSE])
  i <- match(names(share), data$enabler$id)
  capex <- sum(rowSums(model$cost_parts$capex)[names(share)] * share)
  n_en <- sum(share > 1e-9)
  inv_sub <- paste("capex", fmt_musd(capex), "incl. overrun")
  if (length(groups) < nrow(GROUPS)) {
    in_grp <- data$enabler$enabler_group[i] %in% groups
    inv_sub <- sprintf("%s in %s", fmt_musd(sum(rowSums(model$cost)[names(share)][in_grp] * share[in_grp])),
                       if (length(groups) == 1) GROUPS$name[GROUPS$id == groups]
                       else sprintf("%d selected groups", length(groups)))
  }
  kinds <- data$result$kind[match(result_ids, data$result$id)]
  n_late <- sum(result_ids %in% model$late$result_id)
  scope <- sprintf("%d enablers \u00b7 %d KPIs \u00b7 %d milestones%s", n_en, sum(kinds == "kpi"),
                   sum(kinds == "milestone"), if (filtered) " \u00b7 filtered" else "")
  tags$div(class = paste("strip", if (filtered) "filtered"),
    stat(paste("Investment to", h), fmt_musd(p$total_cost), inv_sub),
    stat(paste("Value to", h), fmt_musd(p$total_value), "cumulative, realised"),
    stat("Run-rate value", paste0(fmt_musd(p$run_rate), "/yr"), "at full adoption"),
    stat(paste("NPV @", fmt_pct(model$cfg$discount_rate)), tags$span(class = sign_cls(p$npv), fmt_musd(p$npv)),
         paste0(model$start, "\u2013", h)),
    stat("ROI", tags$span(class = sign_cls(p$roi), fmt_pct(p$roi)), "(value \u2212 cost) / cost"),
    stat("Payback", if (is.na(p$payback)) paste(">", h) else p$payback,
         tagList(scope, if (n_late) tags$span(class = "neg", sprintf(" \u00b7 %d late", n_late)))))
}
