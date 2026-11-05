#' Glossary tab UI: concept diagram, definitions, live foundation-to-value tree
mod_glossary_ui <- function(id, data) {
  ns <- NS(id)
  core <- GLOSSARY[GLOSSARY$core, ]
  other <- GLOSSARY[!GLOSSARY$core, ]
  kpi_choices <- stats::setNames(data$kpi$id, paste0(data$kpi$name, " (",
    data$process$name[match(data$kpi$process_id, data$process$id)], ")"))
  tagList(
    tags$div(class = "intro",
      tags$h2("Glossary"),
      tags$p("The roadmap is one chain: investment goes into enablers; foundations make the enablers possible; ",
             "enablers move KPIs on processes; KPIs carry value. Milestones mark progress along the way.")),
    tags$div(class = "box gl-box",
      tags$div(class = "bh", tags$h2("How the elements connect"),
               tags$span(class = "sp hint", "dashed = requires \u00b7 solid = moves the KPI (weight) \u00b7 green = value")),
      tags$div(class = "cbody gl-scroll",
        tree_svg(concept_tree(), c("Foundations", "Enablers", "KPI", "Value"), node_w = 220))),
    tags$div(class = "gl-cards", lapply(seq_len(nrow(core)), function(i) {
      tags$div(class = "box gl-card",
        tags$div(class = "bh", tags$h2(core$term[i]), tags$span(class = "sp hint", core$where[i])),
        tags$div(class = "cbody",
          tags$p(class = "gl-q", core$question[i]),
          tags$p(core$definition[i]),
          tags$p(class = "hint", "Example: ", core$example[i])))
    })),
    tags$div(class = "box gl-box",
      tags$div(class = "bh", tags$h2("Follow one KPI from foundation to value"),
               tags$span(class = "sp hint", "costs allocated to this KPI \u00b7 current scenario")),
      tags$div(class = "cbody",
        shiny::selectInput(ns("kpi"), NULL, choices = kpi_choices, selectize = FALSE, width = "420px"),
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
