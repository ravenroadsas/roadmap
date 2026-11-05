#' Data model tab UI
mod_datamodel_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$div(class = "intro",
      tags$h2("Data model"),
      tags$p("Five tables plus a config sheet. Each process has results (KPIs and milestones); each result ",
             "requires enablers; enablers may need other enablers first. Money goes into enablers; value comes out of results."),
      tags$div(class = "flow", tags$span(class = "n", "process"), "\u2192", tags$span(class = "n", "result (kpi | milestone)"),
               "\u2192", tags$span(class = "n", "result_enabler (weight)"), "\u2192", tags$span(class = "n", "enabler"),
               "\u2192", tags$span(class = "n", "enabler_dependency"),
               tags$span(class = "hint", style = "margin-left:10px", "config: scenario assumptions"))),
    shiny::uiOutput(ns("source")),
    shiny::uiOutput(ns("schema"))
  )
}
