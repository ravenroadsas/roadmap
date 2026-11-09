#' Editor step 3 server: the board, its links and the side panel
mod_edit_board_server <- function(id, st) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    send <- function() {
      p <- board_payload(st$t, ns(""))
      session$sendCustomMessage("ed-board", list(
        id = ns("board"),
        data = as.character(jsonlite::toJSON(p, dataframe = "rows", auto_unbox = TRUE, na = "null"))))
    }
    shiny::observe(send())
    shiny::observeEvent(st$focus, {
      f <- st$focus
      if (is.null(f$kind) || is.null(f$id)) return()
      session$sendCustomMessage("ed-focus", list(id = ns("board"), key = paste0(f$kind, ":", f$id)))
    })

    shiny::observeEvent(input$connect, {
      res <- connect_nodes(st$t, input$connect$from, input$connect$to)
      if (is.character(res)) editor_commit(st, res) else editor_commit(st, res$tables, res$message)
    })
    shiny::observeEvent(input$disconnect, {
      l <- input$disconnect
      info <- link_info(st$t, l)
      if (!isTRUE(info$removable)) {
        st$msg <- list(text = info$note, ok = FALSE)
        return()
      }
      editor_commit(st, remove_link(st$t, l), paste("Removed:", info$text))
    })
    shiny::observeEvent(input$set_value, {
      l <- input$sel_link
      editor_commit(st, set_link_value(st$t, l, input$value), sprintf("%s set to %s: %s", link_info(st$t, l)$value_label %||% "Value", format(input$value), link_info(st$t, l)$text))
    })
    shiny::observeEvent(input$remove, {
      session$sendCustomMessage("ed-clear", ns("board"))
      l <- input$sel_link
      info <- link_info(st$t, l)
      editor_commit(st, remove_link(st$t, l), paste("Removed:", info$text))
    })
    shiny::observeEvent(input$edit, {
      k <- input$sel_box
      editor_show(st, "items", node_kind(k), node_id(k))
    })
    shiny::observeEvent(input$add, {
      k <- input$add
      st$focus <- list(kind = k, id = NULL, draft = TRUE, row = new_item(st$t, k), n = (st$focus$n %||% 0) + 1)
      st$goto <- list(tab = "items", n = (st$goto$n %||% 0) + 1)
    })

    output$side <- shiny::renderUI({
      t <- st$t
      l <- input$sel_link %||% ""
      b <- input$sel_box %||% ""
      if (nzchar(l)) {
        info <- link_info(t, l)
        return(tags$div(
          tags$div(class = "pane-h", tags$span("Connection")),
          tags$p(class = "ed-side-t", info$text),
          if (!is.null(info$value_label)) tags$div(class = "ed-row ed-val",
            shiny::numericInput(ns("value"), info$value_label, value = info$value, min = 0, step = 0.5, width = "110px"),
            shiny::actionButton(ns("set_value"), "Apply", class = "btn-ed")),
          tags$p(class = "hint", info$note),
          if (isTRUE(info$removable)) shiny::actionButton(ns("remove"), "Remove connection", class = "btn-ed danger"),
          if (isTRUE(info$removable)) tags$p(class = "hint", "or press Delete")))
      }
      if (nzchar(b)) {
        k <- node_kind(b); i <- node_id(b)
        df <- t[[k]]
        if (!i %in% df$id) return(NULL)
        row <- as.list(df[df$id == i, , drop = FALSE])
        return(tags$div(
          tags$div(class = "pane-h", tags$span(if (nzchar(row$name)) row$name else i), tags$span(class = "hint", ITEM_SINGULAR[[k]])),
          tags$p(tags$code(i)),
          relations_ui(t, k, i),
          shiny::actionButton(ns("edit"), paste("Edit", ITEM_SINGULAR[[k]]), class = "btn-ed")))
      }
      tags$div(
        tags$div(class = "pane-h", tags$span("How to connect")),
        tags$dl(class = "ed-how",
          tags$dt("Enabler \u2192 result"), tags$dd("The result requires the enabler (weight 1; change it here)."),
          tags$dt("Enabler \u2192 enabler"), tags$dd("The second needs the first before it can go live. Loops are refused."),
          tags$dt("Result \u2192 process"), tags$dd("The result is shared with that process (share 1)."),
          tags$dt("Enabler \u2192 concept"), tags$dd("The enabler moves to that concept.")),
        tags$p(class = "hint", "Click a box to see its connections; click a line to change or remove it. Esc clears the selection."),
        tags$p(class = "hint", tables_summary(t)))
    })
  })
}
