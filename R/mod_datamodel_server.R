TABLE_NOTES <- list(
  process = "Business processes being transformed. Each owns a set of results.",
  result = "Tangible results of a process: KPIs (baseline -> target) and milestones. Each has a due date and an optional annual value, scaled by the config key named in value_driver.",
  enabler = "Investment item in one of 4 groups. Carries the resource types: money (capex, opex), expertise and manpower (internal vs partner FTE).",
  result_process = "Optional: a result shared by several processes. List every process that shares it, including the lead (result.process_id), with a share; value and cost are split by share. Results not listed belong 100% to their lead process.",
  result_enabler = "Explicit: which enablers each result requires. The weight drives value attribution and cost allocation.",
  enabler_dependency = "Prerequisites between enablers. Must be acyclic. Foundations share their cost across dependents."
)

#' Data model tab server
mod_datamodel_server <- function(id, data, cfg_table) {
  moduleServer(id, function(input, output, session) {
    info <- attr(data, "table_info")
    src <- attr(data, "input")

    output$source <- shiny::renderUI({
      tags$div(class = "callout source",
        tags$b("Input workbook: "), tags$code(basename(src$path)),
        sprintf(" \u00b7 last modified %s \u00b7 one sheet per table below plus a config sheet (a README sheet describes every column). ",
                format(src$modified, "%Y-%m-%d %H:%M")),
        "Edit the workbook and restart the app to reload it. ",
        shiny::downloadLink(session$ns("download"), "Download the current data as Excel"), " \u00b7 ",
        shiny::downloadLink(session$ns("template"), "empty template"))
    })
    output$download <- shiny::downloadHandler(
      filename = function() sprintf("roadmap_input_%s.xlsx", format(Sys.Date(), "%Y%m%d")),
      content = function(file) write_input_excel(file, data, cfg_table))
    output$template <- shiny::downloadHandler(
      filename = "roadmap_input_template.xlsx",
      content = function(file) write_input_excel(file, NULL, cfg_table))
    output$schema <- shiny::renderUI({
      cards <- lapply(names(info), function(t) {
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2(class = "tname", t), tags$span(class = "sp hint", info[[t]]$rows, " rows")),
          tags$p(TABLE_NOTES[[t]], " Sheet ", tags$code(t), "."),
          tags$table(class = "t", tags$tbody(lapply(info[[t]]$fields, function(f) tags$tr(tags$td(tags$code(f)))))))
      })
      cfg_card <- tags$div(class = "box",
        tags$div(class = "bh", tags$h2(class = "tname", "config"), tags$span(class = "sp hint", nrow(cfg_table), " rows")),
        tags$p("Scenario assumptions: base value, slider range and tornado low / high. Sheet ", tags$code("config"), " of the input workbook (a pin can override it on Posit Connect)."),
        tags$table(class = "t", tags$tbody(lapply(seq_len(nrow(cfg_table)), function(i) tags$tr(
          tags$td(tags$code(cfg_table$key[i])), tags$td(class = "hint", cfg_table$label[i]),
          tags$td(class = "r", fmt_cfg(cfg_table[i, ])))))))
      tags$div(class = "schema", cards, cfg_card)
    })
  })
}
