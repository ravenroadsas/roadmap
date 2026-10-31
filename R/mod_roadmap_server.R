#' Roadmap tab server
#' @param data roadmap data list (static).
#' @param graph build_graph() output.
#' @param model reactive run_model() for the current scenario.
#' @param audience reactive "mgmt" / "public".
mod_roadmap_server <- function(id, data, graph, model, audience) {
  moduleServer(id, function(input, output, session) {
    kpi_ids <- reactive(visible_kpis(data, audience()))

    observeEvent(input$reset_filters, {
      shiny::updateCheckboxGroupInput(session, "process", selected = data$process$id)
      shiny::updateCheckboxGroupInput(session, "group", selected = GROUPS$id)
      shiny::updateTextInput(session, "query", value = "")
    })

    filters <- reactive({
      list(
        process = if (length(input$process)) input$process else data$process$id,
        group = if (length(input$group)) input$group else GROUPS$id,
        query = input$query %||% ""
      )
    }) |> shiny::debounce(250)

    # payload to the browser canvas
    observe({
      p <- viz_payload(data, model(), audience(), filters(), session$ns(""))
      session$sendCustomMessage("roadmap-data",
        as.character(jsonlite::toJSON(p, dataframe = "rows", auto_unbox = TRUE, digits = 4)))
    })

    selection <- reactive(parse_selection(input$selection))

    output$strip <- shiny::renderUI(summary_strip(data, model(), kpi_ids()))
    output$detail_title <- shiny::renderText({
      s <- selection()
      if (is.null(s)) "Portfolio" else c(kpi = "KPI", enabler = "Enabler", process = "Process")[[s$type]]
    })
    output$detail <- shiny::renderUI(detail_ui(data, model(), selection(), kpi_ids()))

    selection
  })
}
