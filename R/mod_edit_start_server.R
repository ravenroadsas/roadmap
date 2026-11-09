#' Editor step 1 server: import, copy, empty, template
mod_edit_start_server <- function(id, st) {
  moduleServer(id, function(input, output, session) {
    pending <- shiny::reactiveVal(NULL)
    do_load <- function(f) {
      res <- tryCatch(f(), error = function(e) conditionMessage(e))
      if (is.character(res)) {
        st$msg <- list(text = paste("Could not read the workbook:", res), ok = FALSE)
        return(invisible())
      }
      editor_load(st, res)
    }
    load <- function(f) {
      if (!isTRUE(shiny::isolate(st$dirty))) return(do_load(f))
      pending(f)
      shiny::showModal(shiny::modalDialog(
        tags$p("Replace the work in progress?"),
        tags$p(class = "hint", "Changes not exported will be lost. Export first (step 4) to keep them."),
        footer = tagList(shiny::modalButton("Cancel"),
                         shiny::actionButton(session$ns("confirm"), "Replace", class = "btn-ed primary")),
        easyClose = TRUE, size = "s"))
    }
    shiny::observeEvent(input$confirm, {
      shiny::removeModal()
      if (!is.null(pending())) do_load(pending())
      pending(NULL)
    })
    shiny::observeEvent(input$file, {
      f <- input$file
      load(function() editor_import(f$datapath, f$name))
    })
    shiny::observeEvent(input$current, load(function() {
      res <- editor_import(input_path())
      res$src <- paste("copy of", res$src)
      res
    }))
    shiny::observeEvent(input$empty, load(function()
      list(tables = empty_tables(), cfg = default_config(), src = "new roadmap", probs = character(0))))
    output$template <- shiny::downloadHandler(
      filename = "roadmap_input_template.xlsx",
      content = function(file) write_input_excel(file, NULL, default_config()))

    shiny::observeEvent(input$go, editor_show(st, input$go))
    output$summary <- shiny::renderUI({
      if (!isTRUE(st$loaded)) return(NULL)
      probs <- st$probs
      tags$div(class = "ed-loaded",
        tags$div(class = "pane-h", tags$span("Working copy"), tags$span(class = "hint", st$src)),
        tags$p(tables_summary(st$t)),
        if (length(probs)) tags$div(class = "ed-probs",
          tags$p(class = "neg", sprintf("%d problem%s found at import. They don't block editing; fix them before exporting.",
                                        length(probs), if (length(probs) == 1) "" else "s")),
          tags$ul(lapply(utils::head(probs, 12), tags$li)),
          if (length(probs) > 12) tags$p(class = "hint", sprintf("\u2026 and %d more, listed in step 4.", length(probs) - 12))),
        tags$div(class = "ed-row",
          tags$button(class = "btn-ed primary", onclick = sprintf("Shiny.setInputValue('%s','items',{priority:'event'})", session$ns("go")), "Edit items"),
          tags$button(class = "btn-ed", onclick = sprintf("Shiny.setInputValue('%s','board',{priority:'event'})", session$ns("go")), "Edit connections")))
    })
  })
}
