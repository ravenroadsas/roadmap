#' Editor step 1: where the working copy comes from
mod_edit_start_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "ed-start",
    tags$p(class = "lede", "Build the roadmap here, then export a workbook for the roadmap app."),
    tags$p(class = "hint ed-lede-s",
           "The editor works on a copy. It never changes the workbook the roadmap app reads: import, edit, export."),
    tags$div(class = "ed-cards",
      tags$div(class = "ed-card",
        tags$h3("Import a workbook"),
        tags$p(class = "hint", "An .xlsx in the input format: a filled template, an authoring agent's output or a previous export. Problems are listed, not blocking."),
        shiny::fileInput(ns("file"), NULL, accept = ".xlsx", buttonLabel = "Choose file\u2026", placeholder = "no file chosen")),
      tags$div(class = "ed-card",
        tags$h3("Copy the current roadmap"),
        tags$p(class = "hint", "Start from the workbook the roadmap app reads (", tags$code(basename(input_path())), "). The original is not touched."),
        shiny::actionButton(ns("current"), "Open a copy", class = "btn-ed")),
      tags$div(class = "ed-card",
        tags$h3("Start empty"),
        tags$p(class = "hint", "Create processes, results, concepts and enablers here, or fill the template in Excel and import it."),
        tags$div(class = "ed-row",
          shiny::actionButton(ns("empty"), "Start empty", class = "btn-ed"),
          shiny::downloadLink(ns("template"), "Download the template", class = "mini")))),
    shiny::uiOutput(ns("summary")))
}
