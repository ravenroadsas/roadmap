#' Editor step 4 server: problems, warnings, headline, download
mod_edit_export_server <- function(id, st) {
  moduleServer(id, function(input, output, session) {
    output$check <- shiny::renderUI({
      t <- st$t
      probs <- validate_tables(t)
      if (length(probs)) {
        return(tags$div(
          tags$div(class = "pane-h", tags$span("Check"), tags$span(class = "hint neg", sprintf("%d problem%s", length(probs), if (length(probs) == 1) "" else "s"))),
          tags$p("The roadmap app will refuse this workbook until these are fixed. You can still export it to continue later."),
          tags$ul(class = "ed-probs", lapply(probs, tags$li))))
      }
      m <- tryCatch(editor_model(t, st$cfg), error = function(e) conditionMessage(e))
      if (is.character(m)) return(tags$p(class = "neg", "The model could not run: ", m))
      model <- m$model
      warn <- c(model$late$message, model$issues$message)
      tags$div(
        tags$div(class = "pane-h", tags$span("Check"), tags$span(class = "hint pos", "ready for the roadmap app")),
        tags$p(class = "hint", tables_summary(t)),
        headline(m$data, model),
        tags$div(class = "pane-h", tags$span("Warnings"), tags$span(class = "hint", "allowed; shown in red in the app")),
        if (length(warn)) tags$ul(class = "ed-warn", lapply(warn, tags$li)) else tags$p(class = "hint", "None: every result is on time and every foundation goes live before what needs it."))
    })
    output$download <- shiny::downloadHandler(
      filename = function() {
        n <- trimws(input$name %||% "")
        if (!nzchar(n)) n <- "roadmap_input.xlsx"
        if (!grepl("\\.xlsx$", n, ignore.case = TRUE)) n <- paste0(n, ".xlsx")
        gsub("[/\\\\:*?\"<>|]", "_", n)
      },
      content = function(file) {
        write_input_excel(file, shiny::isolate(st$t), shiny::isolate(st$cfg))
        st$dirty <- FALSE
        st$msg <- list(text = "Exported", ok = TRUE)
      })
  })
}
