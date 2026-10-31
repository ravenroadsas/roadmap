# Sensitivity charts: data preparation (pure, tested) and echarts4r rendering.

COL <- list(pos = "#2f8a55", neg = "#b4423a", ink = "#1b2025", muted = "#9aa3ab", accent = "#2f6db0")

flow_data <- function(model, base_model, kpi_ids) {
  p <- portfolio(model, kpi_ids)
  b <- portfolio(base_model, kpi_ids)
  data.frame(year = as.character(p$years), value = round(p$value, 2), cost = round(-p$cost, 2),
             cum_net = round(p$cum_net, 2), base_cum_net = round(b$cum_net, 2))
}

tornado_data <- function(data, graph, cfg, base, cfg_table, kpi_ids) {
  t <- tornado(data, graph, cfg, base, cfg_table, kpi_ids)
  npv <- portfolio(run_model(data, graph, cfg, base), kpi_ids)$npv
  rows <- match(t$key, cfg_table$key)
  t$lever <- sprintf("%s (%s \u2192 %s)", t$label,
                     vapply(rows, function(i) fmt_cfg(cfg_table[i, ], cfg_table$low[i]), ""),
                     vapply(rows, function(i) fmt_cfg(cfg_table[i, ], cfg_table$high[i]), ""))
  t$d_low <- round(t$npv_low - npv, 2)
  t$d_high <- round(t$npv_high - npv, 2)
  t[rev(seq_len(nrow(t))), c("lever", "d_low", "d_high")]  # largest at the top once flipped
}

kpi_value_data <- function(data, model, base_model, kpi_ids) {
  s <- rowSums(model$value[kpi_ids, , drop = FALSE])
  b <- rowSums(base_model$value[kpi_ids, , drop = FALSE])
  out <- data.frame(kpi = data$kpi$name[match(kpi_ids, data$kpi$id)],
                    scenario = round(s, 1), base = round(b, 1))
  out[order(out$scenario), ]
}

ready_data <- function(data, model, base_model, kpi_ids) {
  q <- function(t) ceiling(t * 4 - 1e-9) / 4      # end of the quarter
  out <- data.frame(kpi = data$kpi$name[match(kpi_ids, data$kpi$id)],
                    base = q(base_model$ready[kpi_ids]), scenario = q(model$ready[kpi_ids]))
  out$months_earlier <- round((out$base - out$scenario) * 12)
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

chart_kpis <- function(df) {
  df |>
    echarts4r::e_charts_("kpi") |>
    echarts4r::e_bar_("scenario", name = "Scenario", itemStyle = list(color = COL$pos)) |>
    echarts4r::e_bar_("base", name = "Base", itemStyle = list(color = COL$muted)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_grid(left = 190, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

chart_ready <- function(df) {
  lo <- floor(min(df$scenario, df$base))
  df |>
    echarts4r::e_charts_("kpi") |>
    echarts4r::e_scatter_("base", name = "Base", symbol = "rect", symbolSize = c(3, 14),
                          itemStyle = list(color = COL$muted)) |>
    echarts4r::e_scatter_("scenario", name = "Scenario", symbolSize = 9, itemStyle = list(color = COL$accent)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_x_axis(min = lo, axisLabel = list(fontSize = 10)) |>
    echarts4r::e_grid(left = 190, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

#' Headline figures shared by the Roadmap and Sensitivity tabs
summary_strip <- function(data, model, kpi_ids) {
  p <- portfolio(model, kpi_ids)
  share <- rowSums(model$graph$alloc[, kpi_ids, drop = FALSE])
  i <- match(names(share), data$enabler$id)
  capex <- sum(data$enabler$capex_musd[i] * model$schedule$cost_factor[i] * share) *
    (1 + model$cfg$capex_overrun)
  h <- model$cfg$horizon_end
  stat <- function(l, v, s) tags$div(class = "stat", tags$div(class = "l", l), tags$div(class = "v", v), tags$div(class = "s", s))
  tags$div(class = "strip",
    stat(paste("Investment to", h), fmt_musd(p$total_cost), paste("capex", fmt_musd(capex), "incl. overrun")),
    stat(paste("Value to", h), fmt_musd(p$total_value), "cumulative, realised"),
    stat("Run-rate value", paste0(fmt_musd(p$run_rate), "/yr"), "at full adoption"),
    stat(paste("NPV @", fmt_pct(model$cfg$discount_rate)), tags$span(class = sign_cls(p$npv), fmt_musd(p$npv)),
         paste0(model$start, "\u2013", h)),
    stat("ROI", tags$span(class = sign_cls(p$roi), fmt_pct(p$roi)), "(value \u2212 cost) / cost"),
    stat("Payback", if (is.na(p$payback)) paste(">", h) else p$payback,
         sprintf("%d enablers \u00b7 %d KPIs", nrow(data$enabler), length(kpi_ids))))
}
