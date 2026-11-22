test_that("quarter and month conversions", {
  expect_equal(q_to_time("2027Q1"), 2027)
  expect_equal(q_to_time("2027Q3", end = TRUE), 2027.75)
  expect_equal(month_to_time("2026-12"), 2026 + 11.5 / 12)
  expect_equal(due_to_time("2027-03"), 2027.25)
  expect_equal(time_to_q(2028.25), "2028Q2")
  expect_equal(q_of(2027.3), "2027Q2")
})

test_that("weights, flow, chains, metric links and ready dates", {
  g <- build_graph(tiny_data())
  expect_equal(unname(g$weight[c("E1", "E2", "E3"), "S3"]), c(0, 0.75, 0.25))
  expect_equal(unname(g$flow["E1", c("S3", "T3")]), c(0.75, 1))    # foundation carries E2's milestones
  expect_setequal(g$chains$S3$direct, c("E2", "E3"))
  expect_equal(g$chains$S3$foundation, "E1")
  expect_equal(unname(g$ready[c("S3", "S4", "T2", "T3")]), c(2027.5, 2028, 2026.5, 2027.5))
  expect_equal(g$metric_ms$K1, c("S3", "S4"))
  expect_equal(g$ms_metrics$T2, "K2")
  expect_equal(unname(g$curves["concave", ]), c(0, .45, .75, .92, 1))
})

test_that("validation catches cycles, broken references and unlinked items", {
  d <- tiny_tables()
  expect_length(graph_validate(d), 0)
  d$enabler_dependency <- rbind(d$enabler_dependency, data.frame(enabler_id = "E1", requires_id = "E2"))
  expect_match(graph_validate(d), "cycle", all = FALSE)
  d <- tiny_tables()
  d$milestone_enabler$milestone_id[3] <- "S9"
  d$enabler$concept_id[1] <- "C9"
  d$metric$curve_id[2] <- "wavy"
  d$metric_milestone <- d$metric_milestone[d$metric_milestone$metric_id != "K2", ]
  v <- graph_validate(d)
  expect_match(v, "unknown milestone", all = FALSE)
  expect_match(v, "milestone S4 requires no enabler", all = FALSE)
  expect_match(v, "unknown concept C9", all = FALSE)
  expect_match(v, "metric K2: unknown curve wavy", all = FALSE)
  expect_match(v, "metric K2 is moved by no milestone", all = FALSE)
})

test_that("date and level problems load and are reported", {
  d <- tiny_tables()
  d$enabler$end_q[1] <- "2027Q4"                             # E1 (needed by E2) goes live after E2
  d$enabler$end_q[3] <- "2025Q4"                             # E3 ends before it starts
  d$enabler$level[4] <- 5                                    # E4 (M5) needed by S4 (M4)
  expect_length(graph_validate(d), 0)
  g <- build_graph(prepare_data(d))
  expect_setequal(g$issues$type, c("end_before_start", "prereq_ends_later"))
  expect_equal(g$level_issues$enabler_id, "E4")
  expect_match(g$level_issues$message, "e4 (M5) is required by s4, a M4 milestone", fixed = TRUE)
})
