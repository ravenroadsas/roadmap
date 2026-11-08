#' Scenario view: four levers | what changes
mod_scenario_ui <- function(id, cfg_table, data) {
  ns <- NS(id)
  lev <- cfg_table[cfg_table$in_sensitivity & cfg_table$key != "resource_multiplier", ]
  slider <- function(r) tags$div(class = "lever",
    tags$div(class = "lever-h", tags$span(r$label), tags$span(class = "lever-v", shiny::textOutput(ns(paste0("v_", r$key)), inline = TRUE))),
    shiny::sliderInput(ns(r$key), NULL, min = r$min, max = r$max, value = r$value, step = r$step,
                       ticks = FALSE, sep = "", width = "100%"),
    tags$div(class = "lever-d", r$description))
  rm <- cfg_table[cfg_table$key == "resource_multiplier", ]
  due_t <- due_to_time(data$result$due)
  qs <- seq(2026.75, 2031, by = 0.25)
  last_q <- ceiling(max(due_t) * 4) / 4
  tags$div(class = "scn",
    tags$aside(class = "levers",
      tags$div(class = "pane-h", tags$span("Levers"), shiny::actionLink(ns("reset"), "reset", class = "mini")),
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
          shiny::selectInput(ns("target"), "Every result ready by the end of",
                             choices = stats::setNames(qs, time_to_q(qs - 0.25)),
                             selected = qs[which.min(abs(qs - (last_q - 0.5)))], selectize = FALSE, width = "100%"),
          tags$div(class = "lever-d", "Resources per enabler are back-calculated from its scalability.")),
        shiny::conditionalPanel("input.acc == 'due'", ns = ns,
          tags$div(class = "lever-d", "Resources per enabler are back-calculated so every result meets its own due date.")))),
    tags$section(class = "scn-out",
      shiny::uiOutput(ns("headline")),
      tags$div(class = "chart-wrap",
        tags$div(class = "pane-h", tags$span("Cumulative net value"),
                 tags$span(class = "hint", "line = scenario \u00b7 dashed = base \u00b7 bars = yearly value and cost, $M")),
        shiny::uiOutput(ns("chart"))),
      shiny::uiOutput(ns("timing")))
  )
}
