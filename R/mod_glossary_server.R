#' Glossary tab server: live foundation-to-value tree for the selected result
mod_glossary_server <- function(id, data, model) {
  moduleServer(id, function(input, output, session) {
    # open on the most valuable result
    top <- data$result$id[which.max(data$result$value_musd)]
    shiny::updateSelectInput(session, "result", selected = top)

    tree <- reactive({
      req(input$result)
      result_tree(data, model(), input$result)
    })
    output$tree <- shiny::renderUI(tree_svg(tree(), tree_titles(tree())))
    output$tree_note <- shiny::renderUI({
      n <- tree()$nodes
      tags$p(class = "hint", style = "margin:6px 0 0",
        sprintf("%d required enablers, %d foundations. ", sum(n$type == "enabler"), sum(n$type == "foundation")),
        "Each box shows the cost allocated to this result and its go-live quarter (scenario); ",
        "a foundation's cost is shared with the other results built on it. A late result is outlined in red.")
    })
  })
}
