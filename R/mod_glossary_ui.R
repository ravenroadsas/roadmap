#' Glossary tab UI: concept diagram, definitions, live foundation-to-value tree
mod_glossary_ui <- function(id, data) {
  ns <- NS(id)
  core <- GLOSSARY[GLOSSARY$core, ]
  other <- GLOSSARY[!GLOSSARY$core, ]
  r <- data$result[order(match(data$result$process_id, data$process$id), data$result$kind), ]
  choices <- stats::setNames(r$id, paste0(ifelse(r$kind == "kpi", "KPI \u00b7 ", "Milestone \u00b7 "), r$name, " (",
    data$process$name[match(r$process_id, data$process$id)], ")"))
  tagList(
    tags$div(class = "intro",
      tags$h2("Glossary"),
      tags$p("Each process has results: KPIs and milestones, the two kinds of tangible outcome. Achieving a result ",
             "generates value for its process. Each result explicitly requires N enablers; enablers may need other ",
             "enablers first, and those prerequisites are the foundations. Money goes into enablers; value comes out of results.")),
    tags$div(class = "box gl-box",
      tags$div(class = "bh", tags$h2("How the elements connect"),
               tags$span(class = "sp hint", "dashed = enabler needs enabler \u00b7 solid = result requires enabler (weight) \u00b7 green = value")),
      tags$div(class = "cbody gl-scroll",
        tree_svg(concept_tree(), c("Foundations", "Required enablers", "Results", "Value"), node_w = 220))),
    tags$div(class = "gl-cards gl7", lapply(seq_len(nrow(core)), function(i) {
      tags$div(class = "box gl-card",
        tags$div(class = "bh", tags$h2(core$term[i]), tags$span(class = "sp hint", core$where[i])),
        tags$div(class = "cbody",
          tags$p(class = "gl-q", core$question[i]),
          tags$p(core$definition[i]),
          tags$p(class = "hint", "Example: ", core$example[i])))
    })),
    tags$div(class = "box gl-box",
      tags$div(class = "bh", tags$h2("Follow one result from foundation to value"),
               tags$span(class = "sp hint", "costs allocated to this result \u00b7 current scenario")),
      tags$div(class = "cbody",
        shiny::selectInput(ns("result"), NULL, choices = choices, selectize = FALSE, width = "520px"),
        tags$div(class = "gl-scroll", shiny::uiOutput(ns("tree"))),
        shiny::uiOutput(ns("tree_note")))),
    tags$div(class = "box gl-box",
      tags$div(class = "bh", tags$h2("Other terms")),
      tags$div(class = "cbody",
        tags$table(class = "t", tags$tbody(lapply(seq_len(nrow(other)), function(i) tags$tr(
          tags$td(class = "gl-term", other$term[i]), tags$td(other$definition[i]),
          tags$td(class = "hint", other$where[i])))))))
  )
}
