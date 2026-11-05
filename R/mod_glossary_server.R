#' Glossary tab server: live foundation-to-value tree for the selected KPI
mod_glossary_server <- function(id, data, model) {
  moduleServer(id, function(input, output, session) {
    # open on the most valuable KPI
    top <- data$kpi$id[which.max(data$kpi$value_musd)]
    shiny::updateSelectInput(session, "kpi", selected = top)

    tree <- reactive({
      req(input$kpi)
      kpi_tree(data, model(), input$kpi)
    })
    output$tree <- shiny::renderUI(tree_svg(tree(), tree_titles(tree())))
    output$tree_note <- shiny::renderUI({
      n <- tree()$nodes
      tags$p(class = "hint", style = "margin:6px 0 0",
        sprintf("%d direct enablers, %d foundations. ", sum(n$type == "enabler"), sum(n$type == "foundation")),
        "Each box shows the cost allocated to this KPI; a foundation's cost is shared with the other KPIs built on it. ",
        "\u25c7 marks milestones delivered by that enabler.")
    })
  })
}
