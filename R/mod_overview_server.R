#' Overview tab server
#' @param model reactive run_model() for the current scenario.
mod_overview_server <- function(id, data, model) {
  moduleServer(id, function(input, output, session) {
    et <- reactive(enabler_cost_table(data, model()))
    pt <- reactive(process_table(data, model()))
    st <- reactive(overview_stats(data, model()))

    output$strip <- shiny::renderUI(summary_strip(data, model(), data$result$id))

    output$indicators <- shiny::renderUI({
      s <- st()
      ind <- function(l, v, sub, cls = "") tags$div(class = paste("ind", cls),
        tags$div(class = "l", l), tags$div(class = "v", v), tags$div(class = "s", sub))
      tags$div(class = "inds",
        ind("Cost mix", sprintf("%s / %s / %s", fmt_pct(s$capex_share), fmt_pct(s$people_share), fmt_pct(s$opex_share)),
            "capex / people / opex"),
        ind("Foundations", fmt_pct(s$foundation_share), "of cost in data + infrastructure"),
        ind("Peak spend", fmt_musd(s$peak_spend), paste("in", s$peak_spend_year)),
        ind("Peak manpower", paste(formatC(s$peak_fte, format = "f", digits = 0), "FTE"),
            sprintf("in %s \u00b7 %s partners", s$peak_fte_year, fmt_pct(s$partner_share))),
        ind("First value", time_to_q(ceiling(s$first_value * 4 - 1e-9) / 4 - 0.25),
            sprintf("roadmap complete %s", time_to_q(ceiling(s$roadmap_end * 4 - 1e-9) / 4 - 0.25))),
        ind("Scope", sprintf("%d \u00b7 %d \u00b7 %d \u00b7 %d", s$n_process, s$n_kpi, s$n_milestone, s$n_enabler),
            "processes \u00b7 KPIs \u00b7 milestones \u00b7 enablers"),
        ind("Late results", s$n_late_results,
            if (s$n_late_results) "enablers ready after the due date" else "all results on time",
            if (s$n_late_results) "bad" else ""),
        ind("Late dependencies", s$n_late,
            if (s$n_issues) paste(issue_count_label(model()$issues), "\u00b7 red on the timeline") else "all prerequisites on time",
            if (s$n_issues) "bad" else ""))
    })

    output$process_chart <- echarts4r::renderEcharts4r(chart_process_value(pt()))
    output$enabler_chart <- echarts4r::renderEcharts4r(chart_enabler_cost(et()))
    output$spend_chart <- echarts4r::renderEcharts4r(chart_spend_groups(spend_by_group(data, model())))
    output$fte_chart <- echarts4r::renderEcharts4r(
      chart_fte(fte_profile(data$enabler, model()$years, model()$schedule)))

    output$process_table <- shiny::renderUI({
      d <- pt()
      q <- function(t) ifelse(is.na(t), "\u2013", time_to_q(ceiling(t * 4 - 1e-9) / 4 - 0.25))
      tags$table(class = "t",
        tags$thead(tags$tr(tags$th("Process"), tags$th("Owner"), tags$th(class = "r", "KPIs"),
                           tags$th(class = "r", "Milestones"), tags$th(class = "r", "Late"),
                           tags$th(class = "r", "Run-rate"), tags$th(class = "r", "NPV"),
                           tags$th(class = "r", "ROI"), tags$th(class = "r", "First value"))),
        tags$tbody(lapply(seq_len(nrow(d)), function(i) tags$tr(
          tags$td(d$name[i]), tags$td(class = "hint", d$owner[i]),
          tags$td(class = "r", d$kpis[i]), tags$td(class = "r", d$milestones[i]),
          tags$td(class = paste("r", if (d$late[i]) "neg"), d$late[i]),
          tags$td(class = "r", formatC(d$run_rate[i], format = "f", digits = 1)),
          tags$td(class = paste("r", sign_cls(d$npv[i])), formatC(d$npv[i], format = "f", digits = 1)),
          tags$td(class = "r", fmt_pct(d$roi[i])),
          tags$td(class = "r", q(d$first_value[i]))))))
    })

    output$leverage <- shiny::renderUI({
      d <- et()
      d <- d[!is.na(d$value_per_cost) & d$direct_value > 0, ]
      d <- d[order(-d$value_per_cost), ]
      mx <- max(d$value_per_cost)
      found <- et()$name[et()$direct_value <= 0]
      tagList(
        tags$table(class = "t", tags$tbody(lapply(seq_len(nrow(d)), function(i) tags$tr(
          tags$td(tags$span(class = "en", tags$span(class = paste("dot", d$group[i])), d$name[i]),
                  tags$div(class = "minibar", tags$i(style = sprintf("width:%.0f%%", d$value_per_cost[i] / mx * 100)))),
          tags$td(class = "r", sprintf("%.1fx", d$value_per_cost[i])))))),
        if (length(found)) tags$p(class = "hint", style = "margin:6px 0 0",
          "Foundations (cost shared through dependents): ", paste(found, collapse = ", ")))
    })
  })
}
