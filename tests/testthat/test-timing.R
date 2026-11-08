# K1 requires E2 + E3 (chain E1, E2, E3: ready 2027.5); K2 and M1 require E3 (ready 2026.5).

test_that("a result is late when its chain goes live after the due month", {
  expect_equal(nrow(tiny_model()$late), 0)
  t <- tiny_tables(); t$result$due[1] <- "2027-03"
  d <- prepare_data(t)
  m <- run_model(d, build_graph(d), tiny_cfg())
  expect_equal(m$late$result_id, "K1")
  expect_equal(m$late$enabler_id, "E2")
  expect_match(m$late$message, "can only be achieved in 2027Q2", fixed = TRUE)
})

test_that("late dependencies are counted on the scenario schedule", {
  m <- tiny_model(resources = c(E2 = 4))                     # E2 ends before its prerequisite E1
  late <- m$issues[m$issues$type == "prereq_ends_later", ]
  expect_equal(c(late$enabler_id, late$related_id), c("E2", "E1"))
})

test_that("solve_target: due dates and a common date, with blockers", {
  t <- tiny_tables(); t$result$due[1] <- "2027-03"
  d <- prepare_data(t); g <- build_graph(d)
  sol <- solve_target(d, g, tiny_cfg(), scope = "due")
  expect_true(sol$feasible)
  expect_equal(sol$resources[["E2"]], 1 / 0.75)
  expect_equal(nrow(run_model(d, g, tiny_cfg(), resources = sol$resources)$late), 0)
  sol <- solve_target(d, g, tiny_cfg(), target = 2026.75, scope = "date")
  expect_false(sol$feasible)
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E1"], "rigid")
})

test_that("scenario summary prices the acceleration", {
  t <- tiny_tables(); t$result$due[1] <- "2027-03"
  d <- prepare_data(t); g <- build_graph(d)
  sol <- solve_target(d, g, tiny_cfg(), scope = "due")
  m <- run_model(d, g, tiny_cfg(), resources = sol$resources)
  b <- run_model(d, g, tiny_cfg())
  s <- scenario_summary(d, m, b)
  expect_equal(c(s$late_base, s$late), c(1, 0))
  expect_equal(s$accelerated$id, names(which(sol$resources > 1)))
  expect_equal(sum(s$accelerated$extra_cost), s$p$total_cost - s$b$total_cost)
})
