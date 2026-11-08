#' Scenario view server
#' @return reactive list(cfg, base, resources) used by the roadmap view.
mod_scenario_server <- function(id, data, graph, cfg_table) {
  moduleServer(id, function(input, output, session) {
    base <- config_values(cfg_table)
    levers <- cfg_table$key[cfg_table$in_sensitivity & cfg_table$key != "resource_multiplier"]
    for (k in levers) local({
      kk <- k
      r <- cfg_table[cfg_table$key == kk, ]
      output[[paste0("v_", kk)]] <- shiny::renderText(fmt_cfg(r, input[[kk]] %||% r$value))
    })
    output$v_rm <- shiny::renderText(sprintf("\u00d7%.1f", input$rm %||% 2))
    observeEvent(input$reset, {
      for (k in levers) shiny::updateSliderInput(session, k, value = base[[k]])
      shiny::updateRadioButtons(session, "acc", selected = "plan")
    })

    cfg <- reactive({
      v <- base
      for (k in levers) v[[k]] <- input[[k]] %||% base[[k]]
      v$resource_multiplier <- if (identical(input$acc, "more")) input$rm %||% 2 else 1
      v
    }) |> shiny::debounce(200)

    solved <- reactive({
      acc <- input$acc %||% "plan"
      if (!acc %in% c("date", "due")) return(NULL)
      solve_target(data, graph, cfg(), as.numeric(input$target %||% NA),
                   scope = if (acc == "due") "due" else "date",
                   r_max = max(cfg_table$max[cfg_table$key == "resource_multiplier"], 1))
    })
    scenario <- reactive(list(cfg = cfg(), base = base,
                              resources = if (is.null(solved())) NULL else solved()$resources))
    model <- reactive(run_model(data, graph, scenario()$cfg, base, scenario()$resources))
    base_model <- reactive(run_model(data, graph, base, base))

    output$headline <- shiny::renderUI(headline(data, model(), compare = portfolio(base_model()),
                                                note = "All processes \u00b7 change vs base"))
    output$chart <- shiny::renderUI(cash_chart(portfolio(model()), portfolio(base_model())))
    output$timing <- shiny::renderUI(timing_ui(data, model(), base_model(), solved()))
    scenario
  })
}

#' What acceleration does: feasibility, late results, accelerated enablers
timing_ui <- function(data, model, base_model, solved = NULL) {
  s <- scenario_summary(data, model, base_model)
  ename <- function(id) data$enabler$name[match(id, data$enabler$id)]
  goal <- if (is.null(solved)) NULL else if (solved$scope == "due") "Every result by its due date" else
    sprintf("Every result by %s", q_of(solved$target))
  head <- if (is.null(solved)) NULL else if (solved$feasible) {
    tags$p(class = "t-ok", tags$b(goal), " is reachable.")
  } else {
    tags$div(class = "t-bad", tags$p(tags$b(goal), " can't be fully met. Limited by:"),
      tags$ul(lapply(seq_len(nrow(solved$blockers)), function(i)
        tags$li(ename(solved$blockers$enabler_id[i]), tags$span(class = "hint", paste0(" \u2014 ", solved$blockers$reason[i]))))))
  }
  a <- s$accelerated[order(-s$accelerated$extra_cost), ]
  tags$div(class = "timing",
    head,
    tags$p(class = "t-line", sprintf("Late results: %d", s$late),
           if (s$late != s$late_base) sprintf(" (base %d)", s$late_base),
           if (s$late_dep) tags$span(class = "neg", sprintf(" \u00b7 %d late dependenc%s", s$late_dep, if (s$late_dep > 1) "ies" else "y"))),
    if (nrow(a)) tags$table(class = "tt",
      tags$thead(tags$tr(tags$th("Accelerated enabler"), tags$th(class = "r", "Resources"),
                         tags$th(class = "r", "Go-live"), tags$th(class = "r", "Extra cost"))),
      tags$tbody(lapply(seq_len(nrow(a)), function(i) tags$tr(
        tags$td(a$name[i]), tags$td(class = "r", sprintf("\u00d7%.2f", a$resources[i])),
        tags$td(class = "r", q_of(a$end_plan[i]), " \u2192 ", q_of(a$end[i])),
        tags$td(class = "r", fmt_musd(a$extra_cost[i])))))))
}
