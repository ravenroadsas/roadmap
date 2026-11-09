#' Editor step 3: connections, by dragging one box onto another
mod_edit_board_ui <- function(id) {
  ns <- NS(id)
  tags$div(class = "ed-board-l",
    tags$div(class = "ed-board-main",
      tags$div(class = "ed-row ed-tools",
        tags$input(type = "search", class = "ed-search", id = ns("search"), placeholder = "Find a box"),
        tags$span(class = "hint ed-rules",
          tags$b("Drag"), " enabler \u2192 result: requires \u00b7 enabler \u2192 enabler: needs it first \u00b7 ",
          "enabler \u2192 concept: move \u00b7 result \u2192 process: share")),
      tags$div(class = "ed-board", id = ns("board"), `data-ns` = ns(""))),
    tags$aside(class = "ed-side", shiny::uiOutput(ns("side"))))
}
