FIELD_LABELS <- c(id = "ID", name = "Name", owner = "Owner", process_id = "Lead process", due = "Due (YYYY-MM)",
                  value_musd = "Value, $M / year", value_driver = "Value driver", unit = "Unit",
                  baseline = "Baseline", target = "Target", enabler_group = "Group", subgroup = "Subgroup",
                  fte_internal = "Internal FTE", fte_partner = "Partner FTE", concept_id = "Concept",
                  start_q = "Start (YYYYQn)", end_q = "Go-live (YYYYQn)", capex_musd = "Capex, $M",
                  opex_musd_yr = "Opex, $M / year", cost_basis = "Cost basis", scalability = "Scalability")

FORM_LAYOUT <- list(
  process = list(list(NULL, c("id", "name", "owner"))),
  result = list(list(NULL, c("id", "name", "process_id", "due")),
                list("Value", c("value_musd", "value_driver")),
                list("Measure (optional)", c("unit", "baseline", "target"))),
  concept = list(list(NULL, c("id", "name", "enabler_group", "subgroup")),
                 list("People over the build window", c("fte_internal", "fte_partner"))),
  enabler = list(list(NULL, c("id", "name", "concept_id")),
                 list("Schedule", c("start_q", "end_q", "scalability")),
                 list("Cost", c("capex_musd", "opex_musd_yr", "cost_basis"))))

#' Editor step 2 server: list, form, add, save, delete
mod_edit_items_server <- function(id, st) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    sel <- shiny::reactiveVal(NULL)        # list(kind, id, draft, row)
    probs <- shiny::reactiveVal(character(0))
    kind <- shiny::reactive(input$kind %||% "process")

    shiny::observeEvent(kind(), if (!identical(sel()$kind, kind())) { sel(NULL); probs(character(0)) })
    shiny::observeEvent(input$pick, { sel(list(kind = kind(), id = input$pick, draft = FALSE)); probs(character(0)) })
    shiny::observeEvent(st$focus, {
      f <- st$focus
      if (is.null(f$kind) || !f$kind %in% names(ITEM_TITLES)) return()
      shiny::updateRadioButtons(session, "kind", selected = f$kind)
      sel(list(kind = f$kind, id = f$id, draft = isTRUE(f$draft), row = f$row))
      probs(character(0))
    })
    shiny::observeEvent(input$new, {
      sel(list(kind = kind(), id = NULL, draft = TRUE, row = new_item(st$t, kind())))
      probs(character(0))
    })

    output$list <- shiny::renderUI({
      k <- kind(); t <- st$t
      tb <- item_table(t, k)
      q <- tolower(trimws(input$q %||% ""))
      if (nzchar(q)) tb <- tb[grepl(q, tolower(paste(tb$id, tb$Name)), fixed = TRUE), , drop = FALSE]
      cur <- if (identical(sel()$kind, k) && !isTRUE(sel()$draft)) sel()$id else ""
      if (!nrow(tb)) return(tags$p(class = "hint ed-empty",
        if (nzchar(q)) "Nothing matches." else sprintf("No %s yet. Add one with + New, or import a workbook in step 1.", tolower(ITEM_TITLES[[k]]))))
      cols <- setdiff(names(tb), "id")
      tags$table(class = "tt ed-tt",
        tags$thead(tags$tr(tags$th("ID"), lapply(cols, function(cc) tags$th(class = if (cc != "Name") "r", cc)))),
        tags$tbody(lapply(seq_len(nrow(tb)), function(i) tags$tr(
          class = if (tb$id[i] == cur) "on", `data-pick` = tb$id[i],
          tags$td(tags$code(tb$id[i])),
          lapply(cols, function(cc) tags$td(class = if (cc != "Name") "r", tb[[cc]][i]))))))
    })

    current_row <- shiny::reactive({
      s <- sel(); t <- st$t
      if (is.null(s)) return(NULL)
      if (isTRUE(s$draft)) return(s$row)
      df <- t[[s$kind]]
      if (!s$id %in% df$id) return(NULL)
      as.list(df[df$id == s$id, , drop = FALSE])
    })

    field <- function(t, col, v, sp) {
      inp <- ns(paste0("f_", col))
      lab <- tags$span(FIELD_LABELS[[col]], if (sp[[2]]) tags$span(class = "req", "*"))
      ch <- field_choices(t, col)
      w <- if (!is.null(ch)) {
        if (!is.na(v) && nzchar(v) && !v %in% ch) ch <- c(ch, stats::setNames(v, paste(v, "(missing)")))
        shiny::selectInput(inp, lab, choices = c(if (!length(ch)) c("(none yet)" = ""), ch), selected = if (is.null(v) || is.na(v)) NULL else v, selectize = FALSE)
      } else if (sp[[1]] %in% c("num", "int")) {
        shiny::numericInput(inp, lab, value = if (is.null(v)) NA else v, step = if (col == "scalability") 0.1 else 1)
      } else {
        shiny::textInput(inp, lab, value = if (is.null(v) || is.na(v)) "" else v)
      }
      tags$div(class = paste("ed-f", paste0("ed-f-", col)), w, tags$div(class = "ed-help", sp[[4]]))
    }

    output$form <- shiny::renderUI({
      row <- current_row(); s <- sel(); t <- st$t
      if (is.null(row)) return(tags$div(class = "ed-noform",
        tags$p(class = "hint", sprintf("Select a %s in the list, or add one with + New.", ITEM_SINGULAR[[kind()]]))))
      k <- s$kind
      spec <- INPUT_SPEC[[k]]
      title <- if (isTRUE(s$draft)) paste("New", ITEM_SINGULAR[[k]]) else (if (nzchar(row$name %||% "")) row$name else row$id)
      tags$div(
        tags$div(class = "pane-h", tags$span(title), tags$span(class = "hint", ITEM_SINGULAR[[k]])),
        lapply(FORM_LAYOUT[[k]], function(sec) tags$div(class = "ed-sec",
          if (!is.null(sec[[1]])) tags$div(class = "ed-sec-h", sec[[1]]),
          tags$div(class = "ed-grid", lapply(sec[[2]], function(col) field(t, col, row[[col]], spec[[col]]))))),
        derived_info(t, k, row),
        if (length(probs())) tags$ul(class = "ed-probs neg", lapply(probs(), tags$li)),
        tags$div(class = "ed-row ed-actions",
          shiny::actionButton(ns("save"), if (isTRUE(s$draft)) "Add" else "Save", class = "btn-ed primary"),
          if (!isTRUE(s$draft)) shiny::actionButton(ns("dup"), "Duplicate", class = "btn-ed"),
          if (!isTRUE(s$draft) && k %in% c("enabler", "result", "process", "concept"))
            shiny::actionButton(ns("show"), "Show connections", class = "btn-ed"),
          if (!isTRUE(s$draft)) shiny::actionButton(ns("del"), "Delete", class = "btn-ed danger"),
          if (isTRUE(s$draft)) shiny::actionButton(ns("cancel"), "Cancel", class = "btn-ed ghost")),
        if (!isTRUE(s$draft)) relations_ui(t, k, row$id))
    })

    read_form <- function(k) {
      spec <- INPUT_SPEC[[k]]
      lapply(stats::setNames(names(spec), names(spec)), function(col) {
        v <- input[[paste0("f_", col)]]
        if (is.character(v)) v <- trimws(v)
        v
      })
    }
    shiny::observeEvent(input$save, {
      s <- sel(); k <- s$kind
      row <- read_form(k)
      old <- if (isTRUE(s$draft)) NULL else s$id
      res <- upsert_item(st$t, k, row, old)
      if (is.character(res)) { probs(res); st$msg <- list(text = "Not saved: see the form", ok = FALSE); return() }
      probs(character(0))
      editor_commit(st, res, sprintf("%s %s %s", if (is.null(old)) "Added" else "Saved", ITEM_SINGULAR[[k]], row$id))
      sel(list(kind = k, id = row$id, draft = FALSE))
    })
    shiny::observeEvent(input$dup, {
      s <- sel(); k <- s$kind
      row <- read_form(k)
      row$id <- next_id(st$t, k)
      row$name <- paste(row$name, "(copy)")
      sel(list(kind = k, id = NULL, draft = TRUE, row = row))
    })
    shiny::observeEvent(input$cancel, sel(NULL))
    shiny::observeEvent(input$del, {
      s <- sel()
      res <- delete_item(st$t, s$kind, s$id)
      if (editor_commit(st, res, sprintf("Deleted %s %s", ITEM_SINGULAR[[s$kind]], s$id))) sel(NULL)
    })
    shiny::observeEvent(input$show, editor_show(st, "board", sel()$kind, sel()$id))
  })
}

#' Figures the model derives from an item (read-only, under the form)
derived_info <- function(t, kind, row) {
  if (kind == "enabler" && !is.null(row$id) && row$id %in% t$enabler$id) {
    p <- enabler_people(t)
    p <- p[p$id == row$id, ]
    if (!nrow(p)) return(NULL)
    return(tags$p(class = "hint ed-derived", sprintf("People: %.1f internal + %.1f partner FTE during the build, spread from its concept by build time.",
                                                     p$fte_internal, p$fte_partner)))
  }
  if (kind == "concept" && !is.null(row$id)) {
    e <- t$enabler[t$enabler$concept_id == row$id, ]
    if (!nrow(e)) return(tags$p(class = "hint ed-derived", "No enablers yet: the people are spread over the concept's enablers by build time."))
    s <- suppressWarnings(min(q_to_time(e$start_q), na.rm = TRUE))
    f <- suppressWarnings(max(q_to_time(e$end_q, TRUE), na.rm = TRUE))
    fte <- sum(c(row$fte_internal, row$fte_partner), na.rm = TRUE)
    if (!is.finite(s) || !is.finite(f)) return(NULL)
    return(tags$p(class = "hint ed-derived", sprintf("Build window %s \u2013 %s (%.1f years), %d enabler%s: %.0f FTE-years in total.",
      min(e$start_q), max(e$end_q), f - s, nrow(e), if (nrow(e) == 1) "" else "s", fte * (f - s))))
  }
  NULL
}

relations_ui <- function(t, kind, id) {
  rel <- item_relations(t, kind, id)
  tags$div(class = "ed-rel",
    lapply(rel, function(r) tags$div(class = "ed-rel-r",
      tags$span(class = "ed-rel-l", r$label),
      if (length(r$items)) tags$span(paste(r$items, collapse = "; ")) else tags$span(class = "hint", "none"))),
    tags$p(class = "hint", "Connections are made in step 3 by dragging one box onto another."))
}
