#' Frontier view server
#' @param scenario reactive list(cfg, base, targets) from the scenario view.
#' @param apply reactiveVal set to list(targets, n) to load a portfolio into the scenario.
#' @param goto function(tab) to switch view.
mod_frontier_server <- function(id, data, graph, scenario, apply, goto) {
  moduleServer(id, function(input, output, session) {
    p <- data$process
    fr <- reactive({
      sc <- scenario()
      frontier_enumerate(data, graph, sc$cfg, sc$base)
    }) |> shiny::bindCache(scenario()$cfg)
    scen_row <- reactive(match_targets(fr()$targets, scenario()$targets))
    best <- reactive({ f <- fr(); f$frontier[which.max(f$points$npv[f$frontier])] })
    pick <- reactive({
      i <- suppressWarnings(as.integer(input$pick))
      if (length(i) && !is.na(i) && i >= 1 && i <= fr()$n) i else best()
    })

    output$summary <- shiny::renderUI({
      f <- fr(); pts <- f$points; b <- best()
      fig <- function(label, value, sub) tags$div(class = "fig", tags$div(class = "fig-l", label),
                                                  tags$div(class = "fig-v", value), tags$div(class = "fig-s", sub))
      tags$div(class = "figs",
        fig("Combinations", formatC(f$n, format = "d", big.mark = ","), if (f$reduced) "current, base or M5 per process" else "every level per process"),
        fig("On the frontier", length(f$frontier), "no other costs less and earns more"),
        fig("Highest NPV", fmt_musd(pts$npv[b], 0), sprintf("for %s invested", fmt_musd(pts$investment[b], 0))),
        fig("Base case", fmt_musd(pts$npv[f$base], 0), sprintf("NPV for %s \u00b7 %s", fmt_musd(pts$investment[f$base], 0),
            if (f$base %in% f$frontier) "on the frontier" else "below the frontier")),
        tags$div(class = "fig-note", "Levers from the Scenario view \u00b7 plan resources \u00b7 horizon ", scenario()$cfg$horizon_end))
    })
    output$chart <- shiny::renderUI(frontier_chart(fr(), scen_row(), pick()))

    output$pick_ui <- shiny::renderUI({
      f <- fr(); i <- pick(); pt <- f$points[i, ]
      tg <- f$targets[i, ]
      title <- if (i == best()) "Highest NPV" else if (i == f$base) "Base case" else if (i %in% f$frontier)
        sprintf("Frontier portfolio %d", match(i, f$frontier)) else "Selected combination"
      tagList(
        tags$div(class = "pane-h", tags$span(title)),
        facts(Investment = fmt_musd(pt$investment, 1), Value = paste(fmt_musd(pt$value, 1), "to horizon"),
              NPV = if (pt$npv >= 0) pos(fmt_musd(pt$npv, 1)) else neg(fmt_musd(pt$npv, 1)), ROI = fmt_pct(pt$roi)),
        tags$table(class = "tt fr-tg", tags$tbody(lapply(seq_len(nrow(p)), function(j) tags$tr(
          tags$td(p$name[j]),
          tags$td(class = "r", tags$span(class = paste0("lv-chip l", tg[[j]]), lvl(tg[[j]])),
                  if (tg[[j]] != p$target_level[j]) tags$span(class = "hint", paste0(" base ", lvl(p$target_level[j])))))))),
        shiny::actionButton(session$ns("apply"), "Apply to scenario", class = "btn-fr"),
        tags$p(class = "hint", "Sets these targets in the Scenario view, with its levers and acceleration."))
    })
    observeEvent(input$apply, {
      apply(list(targets = fr()$targets[pick(), ], n = as.numeric(Sys.time())))
      goto("scenario")
    })

    output$table <- shiny::renderUI({
      f <- fr(); x <- f$points[f$frontier, ]; tg <- f$targets[f$frontier, , drop = FALSE]
      tags$div(class = "fr-tbl",
        tags$div(class = "pane-h", tags$span("Frontier portfolios"), tags$span(class = "hint", "from the smallest investment up \u00b7 click a row")),
        tags$table(class = "tt",
          tags$thead(tags$tr(tags$th("#"), tags$th(class = "r", "Investment"), tags$th(class = "r", "NPV"), tags$th(class = "r", "ROI"),
                             lapply(seq_len(nrow(p)), function(k) tags$th(class = "r", title = p$name[k], `data-tip` = htmltools::htmlEscape(p$name[k]), p$id[k])))),
          tags$tbody(lapply(seq_len(nrow(x)), function(j) tags$tr(
            class = paste("fr-row", if (x$idx[j] == pick()) "on"), `data-pick` = x$idx[j],
            tags$td(j), tags$td(class = "r", fmt_musd(x$investment[j], 1)), tags$td(class = "r", fmt_musd(x$npv[j], 1)),
            tags$td(class = "r", fmt_pct(x$roi[j])),
            lapply(seq_len(nrow(p)), function(k) tags$td(class = "r",
              tags$span(class = paste0("lv-chip l", tg[j, k], if (tg[j, k] == p$current_level[k]) " cur"), lvl(tg[j, k])))))))))
    })
  })
}
