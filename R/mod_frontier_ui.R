#' Frontier view: which combination of maturity targets is worth pursuing
mod_frontier_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "fr-root", `data-input` = ns("pick"),
    tags$p(class = "lede", "Every combination of maturity targets, by investment and net present value. The frontier holds the combinations with the highest NPV for their investment."),
    shiny::uiOutput(ns("summary")),
    tags$div(class = "fr-layout",
      tags$section(class = "fr-chart",
        tags$div(class = "pane-h", tags$span("Investment vs NPV"),
                 tags$span(class = "hint", "squares = all combinations (darker = more) \u00b7 line = efficient frontier \u00b7 click a point")),
        shiny::uiOutput(ns("chart"))),
      tags$aside(class = "fr-side", shiny::uiOutput(ns("pick_ui")))),
    shiny::uiOutput(ns("table")))
}
