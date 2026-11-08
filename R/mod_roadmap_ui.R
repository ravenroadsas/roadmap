#' Roadmap view: scope | chronogram or value chain | detail
mod_roadmap_ui <- function(id, data) {
  ns <- NS(id)
  p <- data$process
  tags$div(class = "rm-root",
    shiny::uiOutput(ns("headline")),
    tags$div(class = "layout",
      tags$aside(class = "scope",
        tags$div(class = "pane-h", tags$span("Scope"),
                 shiny::actionLink(ns("all"), "all", class = "mini"), tags$span(class = "sep", "/"),
                 shiny::actionLink(ns("none"), "none", class = "mini")),
        shiny::checkboxGroupInput(ns("scope"), NULL, selected = p$id, choiceValues = p$id,
          choiceNames = lapply(seq_len(nrow(p)), function(i)
            tags$span(class = "sc", tags$span(class = "sc-n", p$name[i]), tags$span(class = "sc-o", p$owner[i])))),
        shiny::textInput(ns("query"), NULL, placeholder = "Search")),
      tags$section(class = "canvas",
        tags$div(class = "pane-h",
          tags$button(class = "vw", `data-view` = "chrono", `aria-pressed` = "true", "Chronogram"),
          tags$button(class = "vw", `data-view` = "chain", `aria-pressed` = "false", "Value chain")),
        tags$div(class = "vizscroll", tags$div(class = "rm-viz")),
        tags$div(class = "legend rm-legend")),
      tags$aside(class = "detail",
        tags$div(class = "pane-h", tags$span(shiny::textOutput(ns("dtitle"), inline = TRUE)),
                 tags$button(class = "mini rm-clear", "clear")),
        shiny::uiOutput(ns("detail"))))
  )
}
