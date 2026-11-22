#' Resources view: cash and people per year for the scenario
mod_resources_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "rs-root",
    tags$p(class = "lede", "What the scenario needs each year: cash, the internal team, part-time experts and partners."),
    shiny::uiOutput(ns("figs")),
    tags$div(class = "rs-grid",
      tags$section(
        tags$div(class = "pane-h", tags$span("Cash per year"), tags$span(class = "hint", "$M \u00b7 hover a bar for the split")),
        shiny::uiOutput(ns("cash")),
        tags$div(class = "legend", tags$span(tags$i(class = "lg sw rs-capex"), "capex"), tags$span(tags$i(class = "lg sw rs-int"), "internal team"),
                 tags$span(tags$i(class = "lg sw rs-sme"), "SMEs"), tags$span(tags$i(class = "lg sw rs-par"), "partners"),
                 tags$span(tags$i(class = "lg sw rs-opex"), "opex"))),
      tags$section(
        tags$div(class = "pane-h", tags$span("People per year"), tags$span(class = "hint", "average FTE \u00b7 SMEs as FTE-equivalent")),
        shiny::uiOutput(ns("fte")),
        tags$div(class = "legend", tags$span(tags$i(class = "lg sw rs-int"), "internal dedicated team"),
                 tags$span(tags$i(class = "lg sw rs-sme"), "part-time SMEs and others"), tags$span(tags$i(class = "lg sw rs-par"), "partners")))),
    shiny::uiOutput(ns("table")),
    shiny::uiOutput(ns("concepts")))
}
