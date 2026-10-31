TABLE_NOTES <- list(
  process = "Business processes being transformed.",
  kpi = "KPI or metric on one process. value_musd = annual $M at full target, scaled by the config key named in value_driver.",
  enabler = "Investment item in one of 4 groups. Carries the resource types: money (capex, opex), expertise and manpower (internal vs partner FTE).",
  enabler_link = "Which enablers move which KPI (and so which process). The weight drives value attribution and cost allocation.",
  enabler_dependency = "Prerequisites between enablers. Must be acyclic. Foundations share their cost across dependents.",
  milestone = "Visible checkpoints, tied to the enabler that delivers them."
)

#' Data model tab server
mod_datamodel_server <- function(id, data, cfg_table) {
  moduleServer(id, function(input, output, session) {
    info <- attr(data, "table_info")
    output$schema <- shiny::renderUI({
      cards <- lapply(names(info), function(t) {
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2(class = "tname", t), tags$span(class = "sp hint", info[[t]]$rows, " rows")),
          tags$p(TABLE_NOTES[[t]]),
          tags$table(class = "t", tags$tbody(lapply(info[[t]]$fields, function(f) tags$tr(tags$td(tags$code(f)))))))
      })
      cfg_card <- tags$div(class = "box",
        tags$div(class = "bh", tags$h2(class = "tname", "config (pin)"), tags$span(class = "sp hint", nrow(cfg_table), " rows")),
        tags$p("Scenario assumptions. Read from a pin on Posit Connect, CSV in development."),
        tags$table(class = "t", tags$tbody(lapply(seq_len(nrow(cfg_table)), function(i) tags$tr(
          tags$td(tags$code(cfg_table$key[i])), tags$td(class = "hint", cfg_table$label[i]),
          tags$td(class = "r", fmt_cfg(cfg_table[i, ])))))))
      tags$div(class = "schema", cards, cfg_card)
    })
  })
}
