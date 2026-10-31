test_that("quarter and month conversions", {
  expect_equal(q_to_time("2027Q1"), 2027)
  expect_equal(q_to_time("2027Q3", end = TRUE), 2027.75)
  expect_equal(month_to_time("2026-12"), 2026 + 11.5 / 12)
  expect_equal(time_to_q(2028.25), "2028Q2")
})

test_that("tiny graph: weights, allocation, chains and ready dates", {
  g <- build_graph(tiny_data())
  expect_equal(unname(g$weight[, "K1"]), c(0, 0.75, 0.25))
  # E1 has no direct KPI but carries E2's flow -> all of its cost goes to K1
  expect_equal(g$alloc["E1", "K1"], 1)
  expect_equal(unname(rowSums(g$alloc)), c(1, 1, 1))
  expect_equal(g$chains$K1$direct, c("E2", "E3"))
  expect_equal(g$chains$K1$foundation, "E1")
  expect_equal(g$ready[["K1"]], 2027.5)
  expect_equal(g$ready[["K2"]], 2026.5)
})

test_that("ancestors and descendants follow the dependency chain", {
  g <- build_graph(tiny_data())
  expect_equal(ancestors("E2", g$prereq), "E1")
  expect_equal(descendants("E1", g$dependents), "E2")
  expect_length(ancestors("E3", g$prereq), 0)
})

test_that("graph_validate catches cycles and broken references", {
  d <- tiny_data()
  expect_length(graph_validate(d), 0)
  d$enabler_dependency <- rbind(d$enabler_dependency, data.frame(enabler_id = "E1", requires_id = "E2"))
  expect_match(graph_validate(d), "cycle", all = FALSE)
  expect_error(build_graph(d), "cycle")
  d <- tiny_data()
  d$enabler_link$kpi_id[1] <- "K9"
  expect_match(graph_validate(d), "unknown kpi", all = FALSE)
})

test_that("sample data is valid and every enabler reaches a KPI", {
  d <- sample_data()
  expect_length(graph_validate(d), 0)
  g <- build_graph(d)
  expect_true(all(abs(rowSums(g$alloc) - 1) < 1e-9))
  expect_true(all(g$ready >= 2026 & g$ready <= 2030))
})
