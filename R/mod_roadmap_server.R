#' Roadmap view server
#' @param scenario reactive list(cfg, base, resources) from the scenario view.
mod_roadmap_server <- function(id, data, graph, scenario) {
  moduleServer(id, function(input, output, session) {
    pids <- data$process$id
    observeEvent(input$all, shiny::updateCheckboxGroupInput(session, "scope", selected = pids))
    observeEvent(input$none, shiny::updateCheckboxGroupInput(session, "scope", selected = character(0)))
    scope <- reactive(input$scope %||% character(0)) |> shiny::debounce(250)
    query <- reactive(input$query %||% "") |> shiny::debounce(300)

    model <- reactive({
      sc <- scenario()
      run_model(data, graph, sc$cfg, sc$base, sc$resources, scope = scope())
    })

    observe({
      p <- viz_payload(data, model(), query(), session$ns(""))
      session$sendCustomMessage("roadmap-data",
        as.character(jsonlite::toJSON(p, dataframe = "rows", auto_unbox = TRUE, digits = 4)))
    })

    output$headline <- shiny::renderUI({
      n <- length(scope())
      headline(data, model(), note = if (n == length(pids)) "All processes" else
        if (n == 0) "No process in scope" else sprintf("%d of %d processes in scope", n, length(pids)))
    })
    selection <- reactive(parse_selection(input$selection))
    output$dtitle <- shiny::renderText({
      s <- selection()
      if (is.null(s)) "Results" else c(result = "Result", enabler = "Enabler", process = "Process")[[s$type]]
    })
    output$detail <- shiny::renderUI(detail_ui(data, model(), selection()))
  })
}
