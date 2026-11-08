#' Application server
app_server <- function(input, output, session) {
  ctx <- app_context()
  output$user <- shiny::renderText(if (is.null(session$user)) "" else session$user)
  scenario <- mod_scenario_server("scenario", ctx$data, ctx$graph, ctx$cfg)
  mod_roadmap_server("roadmap", ctx$data, ctx$graph, scenario)
  mod_model_server("model", ctx$data, ctx$cfg)
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
