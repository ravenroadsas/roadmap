test_that("formatting helpers", {
  expect_equal(fmt_musd(12.345), "$12.3M")
  expect_match(fmt_musd(-3), "^.+\\$3\\.0M$")
  expect_equal(fmt_pct(0.256), "26%")
  expect_equal(fmt_num(9800, "bbl"), "9,800 bbl")
  expect_equal(fmt_cfg(list(key = "cost_multiplier", unit = "x", is_pct = FALSE), 1.2), "\u00d71.20")
})

test_that("selection parsing and search", {
  expect_null(parse_selection(""))
  expect_null(parse_selection("kpi:K1"))
  expect_equal(parse_selection("result:K1"), list(type = "result", id = "K1"))
  d <- tiny_data(); g <- build_graph(d)
  expect_equal(search_results(d, g, ""), c("K1", "K2", "M1"))
  expect_equal(search_results(d, g, "e2"), "K1")               # via a required enabler
  expect_equal(search_results(d, g, "c3"), c("K1", "K2", "M1")) # via a concept name
})

test_that("payload: shown results and the enablers they need", {
  d <- tiny_data()
  m <- run_model(d, build_graph(d), tiny_cfg(), scope = "P2")
  p <- viz_payload(d, m)
  expect_equal(p$results$id[p$results$show], "K2")
  expect_equal(p$enablers$id[p$enablers$show], "E3")
  expect_equal(p$enablers$concept[p$enablers$id == "E3"], "c3")
  expect_equal(p$results$measure[p$results$id == "K1"], "1% \u2192 2%")
  expect_false(p$results$measured[p$results$id == "M1"])
})

test_that("views render: headline, detail panels, chart, diagram", {
  d <- tiny_data(); g <- build_graph(d)
  m <- run_model(d, g, tiny_cfg())
  txt <- function(x) gsub("\\s+", " ", as.character(x))
  h <- txt(headline(d, m, note = "All processes"))
  expect_match(h, fmt_musd(portfolio(m)$total_cost, 0), fixed = TRUE)
  expect_match(h, "all on time", fixed = TRUE)
  expect_match(txt(headline(d, tiny_model(cost_multiplier = 2), compare = portfolio(m))), "fig-d neg", fixed = TRUE)
  expect_match(txt(detail_ui(d, m, NULL)), "3 results in scope", fixed = TRUE)
  expect_match(txt(detail_ui(d, m, list(type = "result", id = "K1"))), "Requires 2 enablers", fixed = TRUE)
  expect_match(txt(detail_ui(d, m, list(type = "result", id = "M1"))), "none of its own", fixed = TRUE)
  expect_match(txt(detail_ui(d, m, list(type = "enabler", id = "E3"))), "per process", fixed = TRUE)
  expect_match(txt(detail_ui(d, m, list(type = "process", id = "P1"))), "2 results", fixed = TRUE)
  expect_match(as.character(cash_chart(portfolio(m), portfolio(m))), "<svg", fixed = TRUE)
  expect_match(as.character(concept_diagram()), "Foundations", fixed = TRUE)
})
