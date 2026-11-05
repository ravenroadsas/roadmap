#' Sensitivity tab server
#' @return reactive named list with the scenario parameter values.
mod_sensitivity_server <- function(id, data, graph, cfg_table) {
  moduleServer(id, function(input, output, session) {
    base <- config_values(cfg_table)

    scenario <- reactive({
      v <- lapply(cfg_table$key, function(k) input[[k]] %||% base[[k]])
      stats::setNames(v, cfg_table$key)
    }) |> shiny::debounce(200)

    lapply(seq_len(nrow(cfg_table)), function(i) {
      r <- cfg_table[i, ]
      output[[paste0("v_", r$key)]] <- shiny::renderText(fmt_cfg(r, input[[r$key]] %||% r$value))
    })

    observeEvent(input$reset, {
      for (i in seq_len(nrow(cfg_table))) {
        shiny::updateSliderInput(session, cfg_table$key[i], value = cfg_table$value[i])
      }
    })

    kpi_ids <- reactive(data$kpi$id)
    model <- reactive(run_model(data, graph, scenario(), base))
    base_model <- reactive({
      b <- base
      b$horizon_end <- scenario()$horizon_end
      run_model(data, graph, b, base)
    })

    output$strip <- shiny::renderUI(summary_strip(data, model(), kpi_ids()))

    output$flow <- echarts4r::renderEcharts4r({
      chart_flow(flow_data(model(), base_model(), kpi_ids()))
    })
    output$tornado <- echarts4r::renderEcharts4r({
      chart_tornado(tornado_data(data, graph, scenario(), base, cfg_table, kpi_ids()))
    })
    output$ready <- echarts4r::renderEcharts4r({
      chart_ready(ready_data(data, model(), base_model(), kpi_ids()))
    })
    output$kpis <- echarts4r::renderEcharts4r({
      chart_kpis(kpi_value_data(data, model(), base_model(), kpi_ids()))
    })

    model
  })
}
