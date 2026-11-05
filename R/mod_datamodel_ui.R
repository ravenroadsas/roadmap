#' Data model tab UI
mod_datamodel_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$div(class = "intro",
      tags$h2("Data model"),
      tags$p("Six tables plus a key / value config. Money goes into enablers; enablers move KPIs through ",
             "processes; KPIs carry value."),
      tags$div(class = "flow", tags$span(class = "n", "config"), "\u2192", tags$span(class = "n", "enabler"),
               "\u21e2", tags$span(class = "n", "enabler_link (weight)"), "\u2192", tags$span(class = "n", "kpi"),
               "\u2192", tags$span(class = "n", "process"),
               tags$span(class = "hint", style = "margin-left:10px",
                         "milestone \u2192 enabler \u00b7 enabler_dependency \u2192 enabler"))),
    shiny::uiOutput(ns("schema"))
  )
}
