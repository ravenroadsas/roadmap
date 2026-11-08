test_that("quarter and month conversions", {
  expect_equal(q_to_time("2027Q1"), 2027)
  expect_equal(q_to_time("2027Q3", end = TRUE), 2027.75)
  expect_equal(month_to_time("2026-12"), 2026 + 11.5 / 12)
  expect_equal(due_to_time("2027-03"), 2027.25)
  expect_equal(time_to_q(2028.25), "2028Q2")
  expect_equal(q_of(2027.3), "2027Q2")
})

test_that("weights, allocation, chains and ready dates", {
  g <- build_graph(tiny_data())
  expect_equal(unname(g$weight[c("E1", "E2", "E3"), "K1"]), c(0, 0.75, 0.25))
  expect_equal(g$alloc["E1", "K1"], 1)                       # foundation carries E2's results
  expect_equal(unname(rowSums(g$alloc)), c(1, 1, 1))
  expect_setequal(g$chains$K1$direct, c("E2", "E3"))
  expect_equal(g$chains$K1$foundation, "E1")
  expect_equal(g$ready[["K1"]], 2027.5)
  expect_equal(g$ready[["M1"]], 2026.5)
  expect_equal(ancestors("E2", g$prereq), "E1")
  expect_equal(descendants("E1", g$dependents), "E2")
})

test_that("validation catches cycles and broken references", {
  d <- tiny_tables()
  expect_length(graph_validate(d), 0)
  d$enabler_dependency <- rbind(d$enabler_dependency, data.frame(enabler_id = "E1", requires_id = "E2"))
  expect_match(graph_validate(d), "cycle", all = FALSE)
  d <- tiny_tables()
  d$result_enabler$result_id[1] <- "K9"
  d$enabler$concept_id[1] <- "C9"
  v <- graph_validate(d)
  expect_match(v, "unknown result", all = FALSE)
  expect_match(v, "unknown concept C9", all = FALSE)
})

test_that("date problems load and are reported", {
  d <- tiny_tables()
  d$enabler$end_q[1] <- "2027Q4"                             # E1 (needed by E2) goes live after E2
  d$enabler$end_q[3] <- "2025Q4"                             # E3 ends before it starts
  expect_length(graph_validate(d), 0)
  g <- build_graph(prepare_data(d))
  expect_setequal(g$issues$type, c("end_before_start", "prereq_ends_later"))
})
