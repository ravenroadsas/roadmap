#' One process's maturity target: segmented M1..M5, levels below today greyed out
maturity_input <- function(ns, i, pr) {
  rb <- shiny::radioButtons(ns(paste0("t_", i)), NULL, inline = TRUE, selected = pr$target_level,
                            choiceValues = 1:5, choiceNames = paste0("M", 1:5))
  if (pr$current_level > 1) {
    rb <- htmltools::tagQuery(rb)$find("input")$
      filter(function(x, i) as.integer(x$attribs$value) < pr$current_level)$
      addAttrs(disabled = NA)$parent()$addClass("below")$allTags()
  }
  tags$div(class = "mat",
    tags$div(class = "mat-h", tags$span(class = "mat-n", pr$name), tags$span(class = "mat-c", paste("today", lvl(pr$current_level)))),
    tags$div(class = "seg", rb))
}

#' Scenario view: maturity targets and levers | what changes
mod_scenario_ui <- function(id, cfg_table, data) {
  ns <- NS(id)
  p <- data$process
  lev <- cfg_table[cfg_table$in_sensitivity & cfg_table$key != "resource_multiplier", ]
  slider <- function(r) tags$div(class = "lever",
    tags$div(class = "lever-h", tags$span(r$label), tags$span(class = "lever-v", shiny::textOutput(ns(paste0("v_", r$key)), inline = TRUE))),
    shiny::sliderInput(ns(r$key), NULL, min = r$min, max = r$max, value = r$value, step = r$step,
                       ticks = FALSE, sep = "", width = "100%"),
    tags$div(class = "lever-d", r$description))
  rm <- cfg_table[cfg_table$key == "resource_multiplier", ]
  due_t <- due_to_time(data$milestone$due)
  qs <- seq(2026.75, 2031, by = 0.25)
  last_q <- ceiling(max(due_t) * 4) / 4
  tags$div(class = "scn",
    tags$aside(class = "levers",
      tags$div(class = "pane-h", tags$span("Digital maturity targets"),
               shiny::actionLink(ns("m_base"), "base", class = "mini"), tags$span(class = "sep", "/"),
               shiny::actionLink(ns("m_cur"), "today", class = "mini"), tags$span(class = "sep", "/"),
               shiny::actionLink(ns("m_max"), "M5", class = "mini")),
      tags$div(class = "mats", lapply(seq_len(nrow(p)), function(i) maturity_input(ns, i, p[i, ]))),
      tags$div(class = "pane-h lev-h", tags$span("Levers"), shiny::actionLink(ns("reset"), "reset", class = "mini")),
      lapply(seq_len(nrow(lev)), function(i) slider(lev[i, ])),
      tags$div(class = "lever",
        tags$div(class = "lever-h", tags$span("Acceleration")),
        shiny::radioButtons(ns("acc"), NULL, choices = c("Plan" = "plan", "More resources" = "more",
                                                         "Target date" = "date", "Due dates" = "due")),
        shiny::conditionalPanel("input.acc == 'more'", ns = ns,
          tags$div(class = "lever-h", tags$span(rm$label), tags$span(class = "lever-v", shiny::textOutput(ns("v_rm"), inline = TRUE))),
          shiny::sliderInput(ns("rm"), NULL, min = rm$min, max = rm$max, value = 2, step = rm$step,
                             ticks = FALSE, sep = "", width = "100%"),
          tags$div(class = "lever-d", "Every scalable enabler gets this many times its planned resources.")),
        shiny::conditionalPanel("input.acc == 'date'", ns = ns,
          shiny::selectInput(ns("target"), "Every milestone ready by the end of",
                             choices = stats::setNames(qs, time_to_q(qs - 0.25)),
                             selected = qs[which.min(abs(qs - (last_q - 0.5)))], selectize = FALSE, width = "100%"),
          tags$div(class = "lever-d", "Resources per enabler are back-calculated from its scalability.")),
        shiny::conditionalPanel("input.acc == 'due'", ns = ns,
          tags$div(class = "lever-d", "Resources per enabler are back-calculated so every milestone in scope meets its own due date.")))),
    tags$section(class = "scn-out",
      shiny::uiOutput(ns("headline")),
      tags$div(class = "chart-wrap",
        tags$div(class = "pane-h", tags$span("Cumulative net value"),
                 tags$span(class = "hint", "line = scenario \u00b7 dashed = base \u00b7 bars = yearly value and cost, $M")),
        shiny::uiOutput(ns("chart"))),
      shiny::uiOutput(ns("maturity")),
      shiny::uiOutput(ns("timing")))
  )
}
