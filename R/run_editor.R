# Roadmap editor: a companion app to build and edit the roadmap workbook.
# It works on an in-memory copy: import a workbook (or start empty), edit
# items and connections, export a workbook. It never writes the workbook
# the roadmap app reads.

#' Run the roadmap editor
#' @param ... passed to shiny::shinyApp() options.
#' @export
run_editor <- function(...) {
  shiny::addResourcePath("www", app_sys("app", "www"))
  shiny::addResourcePath("ed", app_sys("editor", "www"))
  shiny::shinyApp(ui = editor_ui, server = editor_server, options = list(...))
}

#' Editor UI: four steps, in order
editor_ui <- function(request) {
  shiny::fluidPage(
    title = "Roadmap Editor",
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Newsreader:opsz,wght@6..72,400;6..72,500&family=Inter:wght@300;400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap"),
      tags$link(rel = "stylesheet", href = "www/styles.css"),
      tags$link(rel = "stylesheet", href = "ed/editor.css"),
      tags$script(src = "ed/editor.js", defer = NA)),
    tags$header(class = "top ed-top",
      tags$div(class = "brand", tags$span(class = "brand-t", "Roadmap Editor"),
               tags$span(class = "brand-y", shiny::textOutput("src", inline = TRUE))),
      tags$div(class = "ed-status", shiny::uiOutput("status", inline = TRUE)),
      shiny::actionButton("undo", "Undo", class = "btn-ed ghost", title = "Undo the last change (Ctrl+Z)"),
      tags$span(class = "user", shiny::textOutput("user", inline = TRUE))),
    shiny::tabsetPanel(id = "step", type = "tabs",
      shiny::tabPanel("1 \u00b7 Start", value = "start", mod_edit_start_ui("start")),
      shiny::tabPanel("2 \u00b7 Items", value = "items", mod_edit_items_ui("items")),
      shiny::tabPanel("3 \u00b7 Connections", value = "board", mod_edit_board_ui("board")),
      shiny::tabPanel("4 \u00b7 Check & export", value = "export", mod_edit_export_ui("export")))
  )
}

#' Editor server: one working copy per session
editor_server <- function(input, output, session) {
  st <- editor_state()
  output$user <- shiny::renderText(if (is.null(session$user)) "" else session$user)
  output$src <- shiny::renderText(st$src)
  output$status <- shiny::renderUI({
    m <- st$msg
    tagList(
      if (isTRUE(st$dirty)) tags$span(class = "ed-dirty", "unsaved changes"),
      if (!is.null(m)) tags$span(class = paste("ed-msg", if (isTRUE(m$ok)) "ok" else "err"), m$text))
  })
  shiny::observe({
    session$sendCustomMessage("ed-dirty", isTRUE(st$dirty))
    session$sendCustomMessage("ed-undo", length(st$hist) > 0)
  })
  shiny::observeEvent(input$undo, editor_undo(st))
  shiny::observeEvent(st$goto, {
    g <- st$goto
    shiny::updateTabsetPanel(session, "step", selected = g$tab)
  }, ignoreInit = TRUE)
  mod_edit_start_server("start", st)
  mod_edit_items_server("items", st)
  mod_edit_board_server("board", st)
  mod_edit_export_server("export", st)
}

#' Shared state of an editor session
#'
#' t: working tables; cfg: config table carried to the export; src: where
#' the copy came from; probs: problems found at import; hist: undo stack;
#' dirty: changed since the last import or export; msg: last action;
#' focus: item to show (kind, id, n); goto: tab to open.
editor_state <- function() {
  shiny::reactiveValues(t = empty_tables(), cfg = default_config(), src = "new roadmap",
                        probs = character(0), hist = list(), dirty = FALSE, loaded = FALSE,
                        msg = NULL, focus = NULL, goto = NULL)
}

#' Replace the working copy (import, copy of the app's workbook, empty)
editor_load <- function(st, res) {
  st$t <- res$tables
  st$cfg <- res$cfg
  st$src <- res$src
  st$probs <- res$probs
  st$hist <- list()
  st$dirty <- FALSE
  st$loaded <- TRUE
  st$focus <- NULL
  st$msg <- list(text = sprintf("Loaded %s", res$src), ok = TRUE)
}

#' Apply a change; keeps the previous copy for undo
#' @param res updated tables, or a problem message (nothing changes).
#' @return TRUE when applied.
editor_commit <- function(st, res, msg) {
  if (is.character(res)) {
    st$msg <- list(text = paste(res, collapse = "; "), ok = FALSE)
    return(FALSE)
  }
  st$hist <- c(utils::tail(st$hist, 49), list(shiny::isolate(st$t)))
  st$t <- res
  st$dirty <- TRUE
  st$msg <- list(text = msg, ok = TRUE)
  TRUE
}

editor_undo <- function(st) {
  h <- st$hist
  if (!length(h)) {
    st$msg <- list(text = "Nothing to undo", ok = FALSE)
    return(invisible(FALSE))
  }
  st$t <- h[[length(h)]]
  st$hist <- h[-length(h)]
  st$dirty <- TRUE
  st$msg <- list(text = "Undone", ok = TRUE)
  invisible(TRUE)
}

#' Ask another view to show an item: st$goto opens the tab
editor_show <- function(st, tab, kind = NULL, id = NULL) {
  n <- (shiny::isolate(st$goto$n) %||% 0) + 1
  st$focus <- list(kind = kind, id = id, n = n)
  st$goto <- list(tab = tab, n = n)
}
