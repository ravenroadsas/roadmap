#' Editor step 4: check the working copy and export the workbook
mod_edit_export_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "ed-export",
    tags$div(class = "ed-exp-main", shiny::uiOutput(ns("check"))),
    tags$aside(class = "ed-side",
      tags$div(class = "pane-h", tags$span("Export")),
      shiny::textInput(ns("name"), "File name", value = sprintf("roadmap_input_%s.xlsx", format(Sys.Date(), "%Y%m%d"))),
      shiny::downloadButton(ns("download"), "Download workbook", class = "btn-ed primary"),
      tags$p(class = "hint", "One sheet per table plus README and config, in the format the roadmap app reads."),
      tags$p(class = "hint", "To publish it, replace the app's workbook (", tags$code("ROADMAP_INPUT_XLSX"),
             ") with this file and restart the app. The editor never writes it.")))
}
