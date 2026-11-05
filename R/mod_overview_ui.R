#' Overview tab UI: headline figures, cost per enabler, value per process
mod_overview_ui <- function(id) {
  ns <- NS(id)
  box <- function(title, hint, ..., cls = "box") {
    tags$div(class = cls,
      tags$div(class = "bh", tags$h2(title), tags$span(class = "sp hint", hint)),
      tags$div(class = "cbody", ...))
  }
  tagList(
    shiny::uiOutput(ns("strip")),
    shiny::uiOutput(ns("indicators")),
    tags$div(class = "ov-grid",
      box("Value per process", "$M to horizon \u00b7 value vs allocated cost",
          echarts4r::echarts4rOutput(ns("process_chart"), height = "260px")),
      box("Processes", "sorted by value", shiny::uiOutput(ns("process_table"))),
      box("Cost per enabler", "$M to horizon \u00b7 capex, people, opex",
          echarts4r::echarts4rOutput(ns("enabler_chart"), height = "460px"), cls = "box"),
      box("Value for money", "direct value per $ of cost \u00b7 foundations have none",
          shiny::uiOutput(ns("leverage"))),
      box("Spend per year by enabler group", "$M \u00b7 line = value realised",
          echarts4r::echarts4rOutput(ns("spend_chart"), height = "260px")),
      box("Manpower on enabler builds", "average FTE per year",
          echarts4r::echarts4rOutput(ns("fte_chart"), height = "260px")))
  )
}
