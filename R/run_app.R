#' Run the roadmap app
#' @param ... passed to shiny::shinyApp() options.
run_app <- function(...) {
  shiny::addResourcePath("www", app_sys("app", "www"))
  shiny::shinyApp(ui = app_ui, server = app_server, options = list(...))
}
