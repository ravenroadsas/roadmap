#' Application UI
#'
#' Tabs follow the review sequence: overview of cost and value, the roadmap
#' (trace a KPI to its enablers), stress-test the assumptions, check the data model.
app_ui <- function(request) {
  ctx <- app_context()
  shiny::fluidPage(
    title = "Transformation Roadmap 2026\u201329",
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Newsreader:opsz,wght@6..72,400;6..72,600&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap"),
      tags$link(rel = "stylesheet", href = "www/styles.css"),
      tags$script(src = "www/roadmap.js", defer = NA)
    ),
    tags$header(
      tags$div(class = "wrap hbar",
        tags$div(class = "brand",
          tags$h1("Transformation Roadmap 2026\u201329"),
          tags$p("Enablers \u2192 processes \u2192 KPIs \u2192 value")),
        tags$span(class = "user sp", shiny::textOutput("user", inline = TRUE)))),
    tags$main(class = "wrap", style = "padding-block:0 40px",
      shiny::tabsetPanel(id = "tab", type = "tabs",
        shiny::tabPanel("Overview", value = "overview", mod_overview_ui("overview")),
        shiny::tabPanel("Roadmap", value = "roadmap", mod_roadmap_ui("roadmap", ctx$data)),
        shiny::tabPanel("Sensitivity", value = "sensitivity", mod_sensitivity_ui("sens", ctx$cfg, ctx$data)),
        shiny::tabPanel("Data model", value = "model", mod_datamodel_ui("model")),
        shiny::tabPanel("Glossary", value = "glossary", mod_glossary_ui("glossary", ctx$data))))
  )
}
