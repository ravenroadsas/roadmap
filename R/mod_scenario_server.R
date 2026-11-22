#' Scenario view server
#' @param apply reactiveVal of maturity targets to load (from the frontier).
#' @return reactive list(cfg, base, resources, targets) used by the roadmap view.
mod_scenario_server <- function(id, data, graph, cfg_table, apply = NULL) {
  moduleServer(id, function(input, output, session) {
    base <- config_values(cfg_table)
    p <- data$process
    set_targets <- function(v) for (i in seq_len(nrow(p))) shiny::updateRadioButtons(session, paste0("t_", i), selected = v[[i]])
    observeEvent(input$m_base, set_targets(p$target_level))
    observeEvent(input$m_cur, set_targets(p$current_level))
    observeEvent(input$m_max, set_targets(rep(5L, nrow(p))))
    if (!is.null(apply)) observeEvent(apply(), set_targets(apply()$targets[p$id]), ignoreNULL = TRUE)
    targets <- reactive({
      stats::setNames(vapply(seq_len(nrow(p)), function(i) as.integer(input[[paste0("t_", i)]] %||% p$target_level[i]), 0L), p$id)
    }) |> shiny::debounce(150)
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
                   r_max = max(cfg_table$max[cfg_table$key == "resource_multiplier"], 1),
                   targets = targets())
    })
    scenario <- reactive(list(cfg = cfg(), base = base, targets = targets(),
                              resources = if (is.null(solved())) NULL else solved()$resources))
    model <- reactive(run_model(data, graph, scenario()$cfg, base, scenario()$resources, targets()))
    base_model <- reactive(run_model(data, graph, base, base))

    output$headline <- shiny::renderUI({
      n <- sum(targets() != p$target_level)
      headline(data, model(), compare = portfolio(base_model()),
               note = paste0("Change vs base", if (n) sprintf(" \u00b7 %d maturity target%s changed", n, if (n > 1) "s" else "")))
    })
    output$chart <- shiny::renderUI(cash_chart(portfolio(model()), portfolio(base_model())))
    output$maturity <- shiny::renderUI(maturity_ui(data, model(), base_model()))
    output$timing <- shiny::renderUI(timing_ui(data, model(), base_model(), solved()))
    scenario
  })
}

#' What the maturity targets change, by process, and which enablers come in or out
maturity_ui <- function(data, model, base_model) {
  s <- maturity_summary(data, model, base_model)
  x <- s$by_process
  ename <- function(id) data$enabler$name[match(id, data$enabler$id)]
  d <- function(v, good_up = TRUE) if (abs(v) < 0.05) "" else
    tags$span(class = if ((v > 0) == good_up) "pos" else "neg", paste0(if (v > 0) "+" else "\u2212", fmt_musd(abs(v))))
  tags$div(class = "matsum",
    tags$div(class = "pane-h", tags$span("By process"), tags$span(class = "hint", "value per year at full adoption \u00b7 cost to horizon \u00b7 change vs base")),
    tags$table(class = "tt",
      tags$thead(tags$tr(tags$th("Process"), tags$th("Maturity"), tags$th(class = "r", "Milestones"),
                         tags$th(class = "r", "Value / yr"), tags$th(class = "r", "Cost"), tags$th(class = "r", "NPV"))),
      tags$tbody(lapply(seq_len(nrow(x)), function(i) tags$tr(class = if (x$tgt[i] != x$base_tgt[i]) "chg",
        tags$td(x$name[i]),
        tags$td(lvl(x$cur[i]), " \u2192 ", tags$b(lvl(x$tgt[i])), if (x$tgt[i] != x$base_tgt[i]) tags$span(class = "hint", paste0(" (base ", lvl(x$base_tgt[i]), ")"))),
        tags$td(class = "r", x$ms[i], if (x$ms[i] != x$ms_base[i]) tags$span(class = "hint", sprintf(" (%+d)", x$ms[i] - x$ms_base[i]))),
        tags$td(class = "r", fmt_musd(x$run[i]), " ", d(x$run[i] - x$run_base[i])),
        tags$td(class = "r", fmt_musd(x$cost[i]), " ", d(x$cost[i] - x$cost_base[i], FALSE)),
        tags$td(class = "r", fmt_musd(x$npv[i]), " ", d(x$npv[i] - x$npv_base[i])))))),
    if (length(s$added) || length(s$dropped)) tags$p(class = "t-line",
      if (length(s$added)) tagList(tags$b(sprintf("%d enabler%s added: ", length(s$added), if (length(s$added) > 1) "s" else "")), paste(ename(s$added), collapse = ", "), ". "),
      if (length(s$dropped)) tagList(tags$b(sprintf("%d no longer needed: ", length(s$dropped))), paste(ename(s$dropped), collapse = ", "), ".")))
}

#' What acceleration does: feasibility, late milestones, accelerated enablers
timing_ui <- function(data, model, base_model, solved = NULL) {
  s <- scenario_summary(data, model, base_model)
  ename <- function(id) data$enabler$name[match(id, data$enabler$id)]
  goal <- if (is.null(solved)) NULL else if (solved$scope == "due") "Every milestone by its due date" else
    sprintf("Every milestone by %s", q_of(solved$target))
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
    tags$p(class = "t-line", sprintf("Late milestones: %d", s$late),
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
