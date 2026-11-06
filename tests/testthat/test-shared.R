# Results shared by several processes (result_process).

shared_data <- function() {
  d <- tiny_data()
  # K1 (lead P1, value 10) is shared 75 / 25 with P2
  d$result_process <- data.frame(result_id = c("K1", "K1"), process_id = c("P1", "P2"), share = c(3, 1))
  d
}

test_that("shares: lead only by default, split by share when listed", {
  g0 <- build_graph(tiny_data())
  expect_equal(unname(g0$share["K1", ]), c(1, 0))
  g <- build_graph(shared_data())
  expect_equal(unname(g$share["K1", ]), c(0.75, 0.25))
  expect_equal(unname(g$share["K2", ]), c(0, 1))
  expect_equal(unname(rowSums(g$share)), c(1, 1, 1))
  expect_setequal(results_of_process(g, "P2"), c("K1", "K2"))
  expect_equal(processes_of_result(g, "K1"), c("P1", "P2"))
  expect_equal(unname(process_weights(g, c("K1", "K2", "M1"), "P2")), c(0.25, 1, 0))
})

test_that("process value and cost are split by share and still add up", {
  d <- shared_data()
  m <- run_model(d, build_graph(d), tiny_cfg())
  pt <- process_table(d, m)
  all <- portfolio(m)
  expect_equal(sum(pt$value), all$total_value)
  expect_equal(sum(pt$cost), all$total_cost)
  expect_equal(pt$run_rate[pt$id == "P2"], 0.25 * 10 + 4)
  expect_equal(pt$shared[pt$id == "P2"], 1)
  expect_equal(pt$kpis[pt$id == "P2"], 2)
  k1 <- portfolio(m, "K1")
  k1_p2 <- portfolio(m, "K1", 0.25)
  expect_equal(k1_p2$total_value, 0.25 * k1$total_value)
  expect_equal(k1_p2$total_cost, 0.25 * k1$total_cost)
})

test_that("filters, top bar and payload see shared results in every process", {
  d <- shared_data()
  g <- build_graph(d)
  m <- run_model(d, g, tiny_cfg())
  f <- list(process = "P2", owner = c("Ops lead", "CFO"), kind = c("kpi", "milestone"), group = GROUPS$id, query = "")
  ids <- filtered_result_ids(d, g, f)
  expect_equal(ids, c("K1", "K2"))
  w <- process_weights(g, ids, "P2")
  txt <- gsub("\\s+", " ", as.character(summary_strip(d, m, ids, w = w, filtered = TRUE)))
  expect_match(txt, fmt_musd(portfolio(m, ids, w)$total_value), fixed = TRUE)
  p <- viz_payload(d, m, f)
  k1 <- p$results[p$results$id == "K1", ]
  expect_equal(unlist(k1$procs), c("P1", "P2"))
  expect_equal(unlist(k1$shares), c(0.75, 0.25))
  expect_equal(p$processes$id[p$processes$show], "P2")          # only the filtered process
  s <- selection_sets(d, g, list(type = "result", id = "K1"), d$result$id)
  expect_setequal(s$proc, c("P1", "P2"))
  s <- selection_sets(d, g, list(type = "process", id = "P2"), d$result$id)
  expect_setequal(s$result, c("K1", "K2"))
})

test_that("sample workbook has a shared KPI", {
  d <- sample_data()
  g <- build_graph(d)
  expect_equal(unname(g$share["K2", c("P1", "P2")]), c(0.5, 0.5))
})
