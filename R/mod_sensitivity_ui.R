#' Sensitivity tab UI: time target + assumption sliders | timing + charts
mod_sensitivity_ui <- function(id, cfg_table, data) {
  ns <- NS(id)
  due_t <- due_to_time(data$result$due)
  last_q <- if (length(due_t)) ceiling(max(due_t) * 4) / 4 else 2030
  qs <- seq(2026.75, 2031, by = 0.25)
  q_lab <- time_to_q(qs - 0.25)                 # end of quarter -> its label
  sliders <- lapply(seq_len(nrow(cfg_table)), function(i) {
    r <- cfg_table[i, ]
    wrap <- if (r$key == "resource_multiplier") {
      function(x) shiny::conditionalPanel("input.res_mode == 'uniform'", ns = ns, x)
    } else identity
    wrap(tags$div(class = "sl",
      tags$div(class = "slrow", tags$b(r$label), tags$span(class = "num", shiny::textOutput(ns(paste0("v_", r$key)), inline = TRUE))),
      shiny::sliderInput(ns(r$key), r$label, min = r$min, max = r$max, value = r$value,
                         step = r$step, ticks = FALSE, sep = "", width = "100%"),
      tags$div(class = "slrow", tags$span(class = "d", r$description),
               tags$span(class = "base", "base ", fmt_cfg(r)))))
  })
  target_box <- tags$div(class = "box",
    tags$div(class = "bh", tags$h2("Time")),
    tags$div(class = "sl",
      shiny::radioButtons(ns("res_mode"), NULL,
        choices = c("Same extra resources on every enabler" = "uniform",
                    "Back-calculate: every result by its due date" = "due",
                    "Back-calculate from a common target date" = "target")),
      shiny::conditionalPanel("input.res_mode == 'target'", ns = ns,
        shiny::selectInput(ns("target_q"), "Done by the end of",
                           choices = stats::setNames(qs, q_lab),
                           selected = qs[which.min(abs(qs - (last_q - 0.5)))], width = "100%",
                           selectize = FALSE),
        shiny::radioButtons(ns("target_scope"), NULL,
          choices = c("Every milestone" = "milestones",
                      "Every result (KPIs and milestones)" = "results",
                      "Every enabler (roadmap complete)" = "enablers"))),
      shiny::conditionalPanel("input.res_mode != 'uniform'", ns = ns,
        shiny::checkboxInput(ns("pull_prereqs"), "Bring prerequisites forward too (no new late dependencies)", TRUE),
        tags$div(class = "d", "Resources per enabler are back-calculated from its scalability. ",
                 "The Extra resources slider is not used in this mode."))))
  tagList(
    shiny::uiOutput(ns("strip")),
    tags$div(class = "grid2",
      tags$div(class = "side",
        target_box,
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2("Assumptions"),
                   shiny::actionButton(ns("reset"), "Reset to base", class = "btn sp")),
          sliders)),
      tags$div(class = "charts",
        tags$div(class = "box wide",
          tags$div(class = "bh", tags$h2("Timing and resources"),
                   tags$span(class = "sp hint", "scenario vs plan dates")),
          tags$div(class = "cbody", shiny::uiOutput(ns("timing")))),
        tags$div(class = "box wide",
          tags$div(class = "bh", tags$h2("Annual cost vs value, cumulative net"),
                   tags$span(class = "sp hint", "$M \u00b7 dashed = base case")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("flow"), height = "280px"))),
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2("NPV tornado"),
                   tags$span(class = "sp hint", "change in NPV, each lever at low / high")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("tornado"), height = "300px"))),
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2("Value to horizon by result"),
                   tags$span(class = "sp hint", "$M \u00b7 scenario vs base")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("results"), height = "300px"))),
        tags$div(class = "box wide",
          tags$div(class = "bh", tags$h2("Result ready date vs due date"),
                   tags$span(class = "sp hint", "end of enabler chain \u00b7 due \u25c6, base, scenario")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("ready"), height = "300px")))))
  )
}
