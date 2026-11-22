#' Resources view server
#' @param scenario reactive list(cfg, base, resources, targets) from the scenario view.
mod_resources_server <- function(id, data, graph, scenario) {
  moduleServer(id, function(input, output, session) {
    model <- reactive({ sc <- scenario(); run_model(data, graph, sc$cfg, sc$base, sc$resources, sc$targets) })
    rt <- reactive(resources_table(model()))
    f1 <- function(v) formatC(v, format = "f", digits = 1)
    output$figs <- shiny::renderUI({
      r <- rt()
      fig <- function(label, value, sub) tags$div(class = "fig", tags$div(class = "fig-l", label),
                                                  tags$div(class = "fig-v", value), tags$div(class = "fig-s", sub))
      pk <- function(v) if (max(v) > 1e-9) sprintf("peak in %d", r$year[which.max(v)]) else "none"
      tags$div(class = "figs",
        fig("Cash to horizon", fmt_musd(sum(r$cash), 0), sprintf("peak %s in %d", fmt_musd(max(r$cash), 0), r$year[which.max(r$cash)])),
        fig("Internal team", paste(f1(max(r$fte_internal)), "FTE"), pk(r$fte_internal)),
        fig("SMEs", paste(f1(max(r$fte_sme)), "FTE"), pk(r$fte_sme)),
        fig("Partners", paste(f1(max(r$fte_partner)), "FTE"), pk(r$fte_partner)),
        tags$div(class = "fig-note", "Follows the Scenario view: targets, levers, acceleration"))
    })
    output$cash <- shiny::renderUI({
      r <- rt()
      stack_chart(r$year, list(capex = r$capex, `internal team` = r$people_internal, SMEs = r$people_sme,
                               partners = r$people_partner, opex = r$opex),
                  c("rs-capex", "rs-int", "rs-sme", "rs-par", "rs-opex"), fmt = function(v) fmt_musd(v, if (max(r$cash) < 10) 1 else 0))
    })
    output$fte <- shiny::renderUI({
      r <- rt()
      stack_chart(r$year, list(`internal team` = r$fte_internal, SMEs = r$fte_sme, partners = r$fte_partner),
                  c("rs-int", "rs-sme", "rs-par"), fmt = f1)
    })
    output$table <- shiny::renderUI({
      r <- rt()
      m <- function(v) fmt_musd(v, 1)
      tags$div(class = "rs-tbl",
        tags$div(class = "pane-h", tags$span("By year"), tags$span(class = "hint", "cash in $M \u00b7 people in average FTE")),
        tags$table(class = "tt",
          tags$thead(tags$tr(tags$th("Year"), tags$th(class = "r", "Capex"), tags$th(class = "r", "Internal team"), tags$th(class = "r", "SMEs"),
                             tags$th(class = "r", "Partners"), tags$th(class = "r", "Opex"), tags$th(class = "r", "Cash"),
                             tags$th(class = "r sep-l", "Internal FTE"), tags$th(class = "r", "SME FTE"), tags$th(class = "r", "Partner FTE"))),
          tags$tbody(
            lapply(seq_len(nrow(r)), function(i) tags$tr(tags$td(r$year[i]),
              tags$td(class = "r", m(r$capex[i])), tags$td(class = "r", m(r$people_internal[i])), tags$td(class = "r", m(r$people_sme[i])),
              tags$td(class = "r", m(r$people_partner[i])), tags$td(class = "r", m(r$opex[i])), tags$td(class = "r", tags$b(m(r$cash[i]))),
              tags$td(class = "r sep-l", f1(r$fte_internal[i])), tags$td(class = "r", f1(r$fte_sme[i])), tags$td(class = "r", f1(r$fte_partner[i])))),
            tags$tr(class = "tot", tags$td("Total"), tags$td(class = "r", m(sum(r$capex))), tags$td(class = "r", m(sum(r$people_internal))),
              tags$td(class = "r", m(sum(r$people_sme))), tags$td(class = "r", m(sum(r$people_partner))), tags$td(class = "r", m(sum(r$opex))),
              tags$td(class = "r", tags$b(m(sum(r$cash)))),
              tags$td(class = "r sep-l", f1(sum(r$fte_internal)), " FTE-yr"), tags$td(class = "r", f1(sum(r$fte_sme)), " FTE-yr"),
              tags$td(class = "r", f1(sum(r$fte_partner)), " FTE-yr")))))
    })
    output$concepts <- shiny::renderUI({
      x <- resources_by_concept(data, model())
      f1 <- function(v) formatC(v, format = "f", digits = 1)
      tags$div(class = "rs-tbl",
        tags$div(class = "pane-h", tags$span("By concept"), tags$span(class = "hint", "FTE-years over the build \u00b7 cash to horizon")),
        tags$table(class = "tt",
          tags$thead(tags$tr(tags$th("Concept"), tags$th(class = "r", "Internal"), tags$th(class = "r", "SMEs"),
                             tags$th(class = "r", "Partners"), tags$th(class = "r", "Cash"))),
          tags$tbody(lapply(seq_len(nrow(x)), function(i) tags$tr(
            tags$td(tags$i(class = paste("gdot", x$group[i])), " ", x$name[i]),
            tags$td(class = "r", f1(x$internal[i])), tags$td(class = "r", f1(x$sme[i])), tags$td(class = "r", f1(x$partner[i])),
            tags$td(class = "r", fmt_musd(x$cash[i], 1)))))))
    })
  })
}
