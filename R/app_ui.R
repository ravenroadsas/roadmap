#' Application UI: four views, in the order a scenario is built.
#' Scenario (maturity targets and levers), Frontier (which targets are worth
#' pursuing), Roadmap (what, when, for what value, for the scenario), Method.
app_ui <- function(request) {
  ctx <- app_context()
  shiny::fluidPage(
    title = "Transformation Roadmap",
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Newsreader:opsz,wght@6..72,400;6..72,500&family=Inter:wght@300;400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap"),
      tags$link(rel = "stylesheet", href = "www/styles.css"),
      tags$script(src = "www/roadmap.js", defer = NA),
      tags$script(src = "www/frontier.js", defer = NA)),
    tags$header(class = "top",
      tags$div(class = "brand", tags$span(class = "brand-t", "Transformation Roadmap"),
               tags$span(class = "brand-y", "2026 \u2013 2029")),
      tags$span(class = "user", shiny::textOutput("user", inline = TRUE))),
    shiny::tabsetPanel(id = "view", type = "tabs",
      shiny::tabPanel("Scenario", value = "scenario", mod_scenario_ui("scenario", ctx$cfg, ctx$data)),
      shiny::tabPanel("Frontier", value = "frontier", mod_frontier_ui("frontier")),
      shiny::tabPanel("Roadmap", value = "roadmap", mod_roadmap_ui("roadmap", ctx$data)),
      shiny::tabPanel("Method", value = "model", mod_model_ui("model")))
  )
}
