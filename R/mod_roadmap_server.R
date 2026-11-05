#' Roadmap tab server
#' @param data roadmap data list (static).
#' @param graph build_graph() output.
#' @param model reactive run_model() for the current scenario.
mod_roadmap_server <- function(id, data, graph, model) {
  moduleServer(id, function(input, output, session) {
    owners <- unique(data$process$owner)

    observeEvent(input$reset_filters, {
      shiny::updateCheckboxGroupInput(session, "process", selected = data$process$id)
      shiny::updateCheckboxGroupInput(session, "owner", selected = owners)
      shiny::updateCheckboxGroupInput(session, "group", selected = GROUPS$id)
      shiny::updateCheckboxGroupInput(session, "kind", selected = c("kpi", "milestone"))
      shiny::updateTextInput(session, "query", value = "")
    })

    filters <- reactive({
      list(
        process = if (length(input$process)) input$process else data$process$id,
        owner = if (length(input$owner)) input$owner else owners,
        kind = if (length(input$kind)) input$kind else c("kpi", "milestone"),
        group = if (length(input$group)) input$group else GROUPS$id,
        query = input$query %||% ""
      )
    }) |> shiny::debounce(250)

    result_ids <- reactive(filtered_result_ids(data, graph, filters()))

    # payload to the browser canvas
    observe({
      p <- viz_payload(data, model(), filters(), session$ns(""))
      session$sendCustomMessage("roadmap-data",
        as.character(jsonlite::toJSON(p, dataframe = "rows", auto_unbox = TRUE, digits = 4)))
    })

    selection <- reactive(parse_selection(input$selection))

    output$strip <- shiny::renderUI({
      f <- filters()
      summary_strip(data, model(), result_ids(), groups = f$group,
                    filtered = filters_active(data, f))
    })
    output$detail_title <- shiny::renderText({
      s <- selection()
      if (is.null(s)) "Portfolio" else c(result = "Result", enabler = "Enabler", process = "Process")[[s$type]]
    })
    output$detail <- shiny::renderUI(detail_ui(data, model(), selection(), result_ids()))

    selection
  })
}
