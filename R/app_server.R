#' Application server
app_server <- function(input, output, session) {
  ctx <- app_context()
  access <- user_access(session$user, session$groups)

  output$user <- shiny::renderText(access$user)
  output$audience_ui <- shiny::renderUI({
    if (access$can_manage) {
      tags$div(class = "aud",
        shiny::radioButtons("audience", NULL, inline = TRUE, selected = "mgmt",
                            choiceNames = list(tags$span("Public"), tags$span("Management")),
                            choiceValues = c("public", "mgmt")))
    } else {
      tags$span(class = "aud-fixed", "Public view")
    }
  })
  audience <- reactive({
    if (!access$can_manage) return("public")
    input$audience %||% "mgmt"
  })

  model <- mod_sensitivity_server("sens", ctx$data, ctx$graph, ctx$cfg, audience)
  mod_roadmap_server("roadmap", ctx$data, ctx$graph, model, audience)
  mod_datamodel_server("model", ctx$data, ctx$cfg)
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
