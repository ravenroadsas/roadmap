# Results shared by several processes.
shared_data <- function() {
  t <- tiny_tables()
  t$result_process <- data.frame(result_id = c("K1", "K1"), process_id = c("P1", "P2"), share = c(3, 1))
  prepare_data(t)
}

test_that("shares: lead only by default, split by share when listed", {
  expect_equal(unname(build_graph(tiny_data())$share["K1", ]), c(1, 0))
  g <- build_graph(shared_data())
  expect_equal(unname(g$share["K1", ]), c(0.75, 0.25))
  expect_setequal(results_of_process(g, "P2"), c("K1", "K2"))
  expect_equal(processes_of_result(g, "K1"), c("P1", "P2"))
})

test_that("scope counts a shared result at the in-scope share", {
  d <- shared_data()
  g <- build_graph(d)
  m <- run_model(d, g, tiny_cfg(), scope = "P2")
  expect_equal(unname(m$scope_w[c("K1", "K2", "M1")]), c(0.25, 1, 0))
  expect_equal(portfolio(m)$run_rate, 0.25 * 10 + 4)
  expect_true(m$scope_factor[["E2"]] > 0)                   # K1 is in scope (shared): its enablers are needed
  full <- run_model(d, g, tiny_cfg())
  by_p <- vapply(c("P1", "P2"), function(p) {
    ks <- results_of_process(g, p); attributed(full, ks, g$share[ks, p])$cost }, 0)
  expect_equal(sum(by_p), portfolio(full)$total_cost)
})

test_that("payload lists every process of a shared result", {
  d <- shared_data()
  m <- run_model(d, build_graph(d), tiny_cfg(), scope = "P2")
  p <- viz_payload(d, m)
  k1 <- p$results[p$results$id == "K1", ]
  expect_equal(unlist(k1$procs), c("P1", "P2"))
  expect_equal(unlist(k1$shares), c(0.75, 0.25))
  expect_equal(p$processes$id[p$processes$show], "P2")
  expect_equal(p$results$id[p$results$show], c("K1", "K2"))
})
