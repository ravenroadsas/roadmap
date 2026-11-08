DEFINITIONS <- list(
  c("Process", "A business process being transformed. Results create value for it; its owner is accountable."),
  c("Result", "A tangible outcome with a due date and, optionally, a measure (baseline \u2192 target) and a value per year. One result can be shared by several processes."),
  c("Enabler", "Something built: a solution, data, infrastructure or a people initiative. It has capex, opex, dates and a cost basis."),
  c("Concept", "The level between subgroup and enabler (group \u203a subgroup \u203a concept \u203a enabler). People are planned here: FTEs entered on a concept are spread over its enablers' build time."),
  c("Foundation", "An enabler that other enablers need first. A result is ready only when its enablers and their foundations are live."),
  c("Scope", "The processes being transformed. Value counts the results they hold; investment counts the enablers those results need."),
  c("Cost basis", "Fixed: the enabler costs the same whatever the scope. Per process: its cost scales with the processes in scope, as (in scope / served) ^ scalability."),
  c("Scalability", "How an enabler responds to scale: 0 rigid, 1 linear. It sets how much faster more resources make it, and how a per-process cost shrinks with the scope.")
)

#' Model view: how it works, definitions, the data workbook
mod_model_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "model",
    tags$p(class = "lede", "Enablers make results possible. Results create value for processes."),
    concept_diagram(),
    tags$dl(class = "defs", lapply(DEFINITIONS, function(d) tags$div(tags$dt(d[1]), tags$dd(d[2])))),
    shiny::uiOutput(ns("source")))
}

#' Model view server: the workbook and its sheets
mod_model_server <- function(id, data, cfg_table) {
  moduleServer(id, function(input, output, session) {
    src <- attr(data, "input")
    info <- attr(data, "table_info")
    output$source <- shiny::renderUI({
      tags$div(class = "wb",
        tags$div(class = "pane-h", tags$span("Data"),
                 shiny::downloadLink(session$ns("download"), "download workbook", class = "mini"),
                 tags$span(class = "sep", "/"),
                 shiny::downloadLink(session$ns("template"), "empty template", class = "mini")),
        tags$p(class = "hint", tags$code(basename(src$path)), sprintf(" \u00b7 modified %s \u00b7 edit and restart to reload",
                                                                     format(src$modified, "%Y-%m-%d %H:%M"))),
        tags$table(class = "tt", tags$tbody(lapply(names(INPUT_SPEC), function(t) tags$tr(
          tags$td(tags$code(t)), tags$td(class = "r", info[[t]]$rows),
          tags$td(class = "hint", paste(names(INPUT_SPEC[[t]]), collapse = " \u00b7 ")))),
          tags$tr(tags$td(tags$code("config")), tags$td(class = "r", nrow(cfg_table)),
                  tags$td(class = "hint", "levers and fixed assumptions")))))
    })
    output$download <- shiny::downloadHandler(
      filename = function() sprintf("roadmap_input_%s.xlsx", format(Sys.Date(), "%Y%m%d")),
      content = function(file) write_input_excel(file, data, cfg_table))
    output$template <- shiny::downloadHandler(
      filename = "roadmap_input_template.xlsx",
      content = function(file) write_input_excel(file, NULL, cfg_table))
  })
}
