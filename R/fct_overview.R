# Overview tab: portfolio summaries (pure, tested) and their charts.

COST_COL <- list(capex = "#2f6db0", people = "#c97a1e", opex = "#9aa3ab")
GROUP_COL <- c(people = "#c97a1e", digital = "#2f6db0", data = "#14857a", infra = "#6b5fa8")

#' Cost to horizon per enabler, by type, with direct value and leverage
enabler_cost_table <- function(data, model) {
  cp <- model$cost_parts
  e <- data$enabler
  dv <- enabler_direct_value(model)[e$id]
  out <- data.frame(
    id = e$id, name = e$name, group = e$enabler_group,
    capex = rowSums(cp$capex)[e$id], people = rowSums(cp$people)[e$id],
    opex = rowSums(cp$opex)[e$id], stringsAsFactors = FALSE
  )
  out$total <- out$capex + out$people + out$opex
  out$direct_value <- unname(dv)
  out$value_per_cost <- ifelse(out$total > 0, out$direct_value / out$total, NA_real_)
  rownames(out) <- NULL
  out[order(-out$total), ]
}

#' Value, allocated cost and timing per process
process_table <- function(data, model) {
  rows <- lapply(seq_len(nrow(data$process)), function(i) {
    pid <- data$process$id[i]
    ks <- data$kpi$id[data$kpi$process_id == pid]
    if (!length(ks)) {
      return(data.frame(id = pid, name = data$process$name[i], owner = data$process$owner[i],
                        kpis = 0L, run_rate = 0, value = 0, cost = 0, npv = 0, roi = NA_real_,
                        first_value = NA_real_, full_value = NA_real_))
    }
    p <- portfolio(model, ks)
    r <- model$ready[ks] + model$cfg$adoption_delay
    data.frame(id = pid, name = data$process$name[i], owner = data$process$owner[i],
               kpis = length(ks), run_rate = p$run_rate, value = p$total_value,
               cost = p$total_cost, npv = p$npv, roi = p$roi,
               first_value = min(r), full_value = max(r) + model$cfg$ramp_years)
  })
  out <- do.call(rbind, rows)
  out[order(-out$value), ]
}

#' Yearly spend per enabler group, and portfolio value per year
spend_by_group <- function(data, model) {
  g <- data$enabler$enabler_group[match(rownames(model$cost), data$enabler$id)]
  out <- data.frame(year = as.character(model$years))
  for (gid in GROUPS$id) out[[gid]] <- round(colSums(model$cost[g == gid, , drop = FALSE]), 2)
  out$value <- round(colSums(model$value), 2)
  out
}

#' Headline indicators for the overview
overview_stats <- function(data, model) {
  et <- enabler_cost_table(data, model)
  sp <- colSums(model$cost)
  fte <- fte_profile(data$enabler, model$years, model$schedule)
  tot_fte <- fte$internal + fte$partner
  found <- et$group %in% c("infra", "data")
  pt <- process_table(data, model)
  list(
    total_cost = sum(et$total),
    capex_share = sum(et$capex) / sum(et$total),
    people_share = sum(et$people) / sum(et$total),
    opex_share = sum(et$opex) / sum(et$total),
    peak_spend = max(sp), peak_spend_year = model$years[which.max(sp)],
    peak_fte = max(tot_fte), peak_fte_year = model$years[which.max(tot_fte)],
    partner_share = sum(fte$partner) / max(sum(tot_fte), 1e-9),
    foundation_share = sum(et$total[found]) / sum(et$total),
    first_value = min(pt$first_value, na.rm = TRUE),
    roadmap_end = max(model$schedule$end),
    n_process = nrow(data$process), n_kpi = nrow(data$kpi),
    n_enabler = nrow(data$enabler), n_milestone = nrow(data$milestone),
    n_issues = nrow(model$graph$issues)
  )
}

# ---- charts -------------------------------------------------------------

chart_enabler_cost <- function(et) {
  df <- et[rev(seq_len(nrow(et))), ]
  df$label <- df$name
  df[c("capex", "people", "opex")] <- lapply(df[c("capex", "people", "opex")], round, 2)
  df |>
    echarts4r::e_charts_("label") |>
    echarts4r::e_bar_("capex", name = "Capex", stack = "c", itemStyle = list(color = COST_COL$capex)) |>
    echarts4r::e_bar_("people", name = "People", stack = "c", itemStyle = list(color = COST_COL$people)) |>
    echarts4r::e_bar_("opex", name = "Opex", stack = "c", itemStyle = list(color = COST_COL$opex)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_grid(left = 220, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

chart_process_value <- function(pt) {
  df <- pt[rev(seq_len(nrow(pt))), c("name", "value", "cost")]
  df$value <- round(df$value, 1)
  df$cost <- round(df$cost, 1)
  df |>
    echarts4r::e_charts_("name") |>
    echarts4r::e_bar_("value", name = "Value", itemStyle = list(color = COL$pos)) |>
    echarts4r::e_bar_("cost", name = "Allocated cost", itemStyle = list(color = COL$neg)) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_grid(left = 170, right = 20, top = 30, bottom = 24) |>
    echarts4r::e_y_axis(axisLabel = list(fontSize = 10)) |>
    chart_theme()
}

chart_spend_groups <- function(sg) {
  e <- echarts4r::e_charts_(sg, "year")
  for (i in seq_len(nrow(GROUPS))) {
    e <- echarts4r::e_bar_(e, GROUPS$id[i], name = GROUPS$name[i], stack = "s",
                           itemStyle = list(color = GROUP_COL[[GROUPS$id[i]]]))
  }
  e |>
    echarts4r::e_line_("value", name = "Value realised", symbolSize = 5,
                       itemStyle = list(color = COL$pos), lineStyle = list(width = 2)) |>
    echarts4r::e_grid(left = 44, right = 16, top = 50, bottom = 24) |>
    chart_theme()
}

chart_fte <- function(fte) {
  fte$year <- as.character(fte$year)
  fte$internal <- round(fte$internal, 1)
  fte$partner <- round(fte$partner, 1)
  fte |>
    echarts4r::e_charts_("year") |>
    echarts4r::e_bar_("internal", name = "Internal", stack = "f", itemStyle = list(color = COL$ink)) |>
    echarts4r::e_bar_("partner", name = "Partners & contractors", stack = "f", itemStyle = list(color = COL$muted)) |>
    echarts4r::e_grid(left = 40, right = 16, top = 30, bottom = 24) |>
    chart_theme()
}
