#' Editor step 2: items (processes, results, concepts, enablers)
mod_edit_items_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "ed-items",
    tags$div(class = "ed-list",
      tags$div(class = "ed-seg",
        shiny::radioButtons(ns("kind"), NULL, inline = TRUE,
                            choices = stats::setNames(names(ITEM_TITLES), ITEM_TITLES))),
      tags$div(class = "ed-row ed-tools",
        shiny::textInput(ns("q"), NULL, placeholder = "Search"),
        shiny::actionButton(ns("new"), "+ New", class = "btn-ed")),
      tags$div(class = "ed-tbl", `data-input` = ns("pick"), shiny::uiOutput(ns("list")))),
    tags$div(class = "ed-form", shiny::uiOutput(ns("form"))))
}
