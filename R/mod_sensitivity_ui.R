#' Sensitivity tab UI: assumption sliders | charts
mod_sensitivity_ui <- function(id, cfg_table) {
  ns <- NS(id)
  sliders <- lapply(seq_len(nrow(cfg_table)), function(i) {
    r <- cfg_table[i, ]
    tags$div(class = "sl",
      tags$div(class = "slrow", tags$b(r$label), tags$span(class = "num", shiny::textOutput(ns(paste0("v_", r$key)), inline = TRUE))),
      shiny::sliderInput(ns(r$key), r$label, min = r$min, max = r$max, value = r$value,
                         step = r$step, ticks = FALSE, sep = "", width = "100%"),
      tags$div(class = "slrow", tags$span(class = "d", r$description),
               tags$span(class = "base", "base ", fmt_cfg(r))))
  })
  tagList(
    shiny::uiOutput(ns("strip")),
    tags$div(class = "grid2",
      tags$div(class = "box",
        tags$div(class = "bh", tags$h2("Assumptions"),
                 shiny::actionButton(ns("reset"), "Reset to base", class = "btn sp")),
        sliders),
      tags$div(class = "charts",
        tags$div(class = "box wide",
          tags$div(class = "bh", tags$h2("Annual cost vs value, cumulative net"),
                   tags$span(class = "sp hint", "$M \u00b7 dashed = base case")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("flow"), height = "280px"))),
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2("NPV tornado"),
                   tags$span(class = "sp hint", "change in NPV, each lever at low / high")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("tornado"), height = "300px"))),
        tags$div(class = "box",
          tags$div(class = "bh", tags$h2("Value to horizon by KPI"),
                   tags$span(class = "sp hint", "$M \u00b7 scenario vs base")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("kpis"), height = "300px"))),
        tags$div(class = "box wide",
          tags$div(class = "bh", tags$h2("KPI ready date"),
                   tags$span(class = "sp hint", "end of enabler chain \u00b7 base vs scenario (extra resources)")),
          tags$div(class = "cbody", echarts4r::echarts4rOutput(ns("ready"), height = "300px")))))
  )
}
