#' Application server
app_server <- function(input, output, session) {
  ctx <- app_context()
  output$user <- shiny::renderText(if (is.null(session$user)) "local" else session$user)

  model <- mod_sensitivity_server("sens", ctx$data, ctx$graph, ctx$cfg)
  mod_overview_server("overview", ctx$data, model)
  mod_roadmap_server("roadmap", ctx$data, ctx$graph, model)
  mod_datamodel_server("model", ctx$data, ctx$cfg)
  mod_glossary_server("glossary", ctx$data, model)
}

#' Data, graph and config, loaded once per R process and shared by sessions
app_context <- local({
  cache <- NULL
  function(reload = FALSE) {
    if (is.null(cache) || reload) {
      data <- load_roadmap_data()
      cache <<- list(data = data, graph = build_graph(data), cfg = config_read())
    }
    cache
  }
})
