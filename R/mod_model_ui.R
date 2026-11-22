DEFINITIONS <- list(
  c("Process", "A business process being transformed. It has a current digital maturity and a target; its owner is accountable for its milestones and metrics."),
  c("Digital maturity", "Five levels from M1 Manual to M5 Adaptive (see below). The target of each process is the scenario variable: it decides which milestones are pursued."),
  c("Milestone", "A step change on the way to a maturity level, with a due date. It is in scope when its process's target is at or above its level, and ready when its enablers and their foundations are live."),
  c("Metric", "A measured outcome (baseline today, target at M5) that creates value. Milestones move it up its impact curve; its value is the share of the impact reached."),
  c("Impact curve", "The % of a metric's impact reached at each level. Concave when most of the gain comes early (production), threshold when it only comes with automation (man-hours)."),
  c("Enabler", "Something built: a solution, data, infrastructure or a people initiative, with the level it enables. It costs money only if an in-scope milestone needs it."),
  c("Concept", "The level between subgroup and enabler (group \u203a subgroup \u203a concept \u203a enabler). People are planned here: FTEs entered on a concept are spread over its enablers' build time."),
  c("Foundation", "An enabler that other enablers need first. A milestone is ready only when its enablers and their foundations are live."),
  c("Cost basis", "Fixed: the enabler costs the same whatever the scope. Per process: its cost scales with the processes that need it, as (needing / served) ^ scalability."),
  c("Scalability", "How an enabler responds to scale: 0 rigid, 1 linear. It sets how much faster more resources make it, and how a per-process cost shrinks with the scope.")
)

STEPS <- list(
  c("Targets set the scope", "Each process aims at a maturity level. Milestones up to that level are pursued; those above are not."),
  c("Milestones set the investment", "The enablers the in-scope milestones require, with their foundations, are what gets built and paid for."),
  c("Enablers set the dates", "A milestone is ready when its last enabler or foundation goes live; a process reaches a level when its milestones up to that level are ready."),
  c("Curves set the value", "As its milestones are ready, a metric climbs its impact curve from the current level. Value = metric value \u00d7 share of impact reached, ramped over the adoption time.")
)

#' Method view: how it works, maturity levels, curves, definitions, the data workbook
mod_model_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "model",
    tags$p(class = "lede", "Investment builds enablers. Enablers and each process's digital maturity target make milestones possible. Milestones move metrics up their impact curve. Metrics create value."),
    concept_diagram(),
    tags$ol(class = "steps", lapply(STEPS, function(x) tags$li(tags$b(x[1]), tags$span(x[2])))),
    tags$div(class = "pane-h", tags$span("Digital maturity levels"), tags$span(class = "hint", "BPMM (OMG) \u00b7 acatech Industrie 4.0 Maturity Index \u00b7 CMMI \u00b7 Deloitte Digital and AI Maturity")),
    levels_table(),
    tags$details(class = "dims",
      tags$summary("How the levels differ, and how to assess a process"),
      dimensions_table(),
      tags$p(class = "hint", "The current level of a process is assessed on six dimensions:"),
      tags$table(class = "tt", tags$tbody(lapply(seq_len(nrow(ASSESSMENT_DIMENSIONS)), function(i) tags$tr(
        tags$td(tags$b(sprintf("%d. %s", i, ASSESSMENT_DIMENSIONS$dimension[i]))), tags$td(ASSESSMENT_DIMENSIONS$criterion[i])))))),
    shiny::uiOutput(ns("curves")),
    tags$div(class = "pane-h", tags$span("Definitions")),
    tags$dl(class = "defs", lapply(DEFINITIONS, function(d) tags$div(tags$dt(d[1]), tags$dd(d[2])))),
    shiny::uiOutput(ns("source")))
}

#' Model view server: the workbook and its sheets
mod_model_server <- function(id, data, cfg_table) {
  moduleServer(id, function(input, output, session) {
    src <- attr(data, "input")
    output$curves <- shiny::renderUI({
      cv <- data$curve
      used <- vapply(cv$id, function(k) sum(data$metric$curve_id == k), 0L)
      tags$div(class = "curves-wrap",
        tags$div(class = "pane-h", tags$span("Impact curves"), tags$span(class = "hint", "% of a metric's impact reached at each level \u00b7 sheet 'curve'")),
        tags$div(class = "curves-row",
          curves_chart(cv),
          tags$table(class = "tt", tags$tbody(lapply(seq_len(nrow(cv)), function(i) tags$tr(
            tags$td(tags$i(class = sprintf("cv-key c%d", (i - 1) %% 6 + 1)), tags$b(cv$name[i])),
            tags$td(class = "hint", cv$description[i]),
            tags$td(class = "r", sprintf("%d metric%s", used[i], if (used[i] == 1) "" else "s"))))))))
    })
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
                  tags$td(class = "hint", "levers and fixed assumptions")))),
        if (nrow(li <- level_issues(data))) tagList(
          tags$p(class = "d-section neg", sprintf("%d level check%s", nrow(li), if (nrow(li) == 1) "" else "s")),
          tags$ul(class = "hint", lapply(li$message, tags$li))))
    })
    output$download <- shiny::downloadHandler(
      filename = function() sprintf("roadmap_input_%s.xlsx", format(Sys.Date(), "%Y%m%d")),
      content = function(file) write_input_excel(file, data, cfg_table))
    output$template <- shiny::downloadHandler(
      filename = "roadmap_input_template.xlsx",
      content = function(file) write_input_excel(file, NULL, cfg_table))
  })
}
