# tiny: E1 infra 2026Q1-2026Q4 (rigid) -> needed by E2 2026Q3-2027Q2 (s = 1);
#       E3 2026Q1-2026Q2 (s = 0.5).
# K1 requires E2 + E3 (chain E1, E2, E3: ready 2027.5); K2 and M1 require E3 (ready 2026.5).

test_that("a result is late when its enabler chain goes live after the due month", {
  d <- tiny_data()
  g <- build_graph(d)
  expect_equal(nrow(run_model(d, g, tiny_cfg())$late), 0)
  d$result$due[1] <- "2027-03"                               # K1 due end of March 2027
  m <- run_model(d, build_graph(d), tiny_cfg())
  expect_equal(m$late$result_id, "K1")
  expect_equal(m$late$enabler_id, "E2")                       # the latest enabler in the chain
  expect_match(m$late$message, "can only be achieved in 2027Q2", fixed = TRUE)
  expect_equal(due_to_time("2027-03"), 2027.25)
})

test_that("late dependencies are counted on the scenario schedule", {
  d <- tiny_data()
  g <- build_graph(d)
  expect_equal(nrow(run_model(d, g, tiny_cfg())$issues), 0)
  m <- run_model(d, g, tiny_cfg(), resources = c(E2 = 4))     # E2 ends 2026.75, before E1 (2027.0)
  late <- m$issues[m$issues$type == "prereq_ends_later", ]
  expect_equal(c(late$enabler_id, late$related_id), c("E2", "E1"))
  expect_match(late$message, "2026Q4 \\(after 2026Q3\\)")
})

test_that("solve_target 'due': every result by its own due date, exact resources", {
  d <- tiny_data()
  d$result$due[1] <- "2027-03"
  g <- build_graph(d)
  cfg <- tiny_cfg()
  sol <- solve_target(d, g, cfg, scope = "due")
  expect_true(sol$feasible)
  expect_equal(sol$resources[["E2"]], 1 / 0.75)               # E2 may take 0.75 of its year, s = 1
  expect_equal(sol$resources[["E1"]], 1)
  m <- run_model(d, g, cfg, resources = sol$resources)
  expect_equal(nrow(m$late), 0)
  expect_equal(m$ready[["K1"]], 2027.25)
})

test_that("rigid or impossible enablers are reported as blockers", {
  d <- tiny_data()
  d$result$due[1] <- "2026-09"                               # K1 by 2026.75: E1 is rigid and ends 2027.0
  g <- build_graph(d)
  sol <- solve_target(d, g, tiny_cfg(), scope = "due")
  expect_false(sol$feasible)
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E1"], "rigid")
  sol <- solve_target(d, g, tiny_cfg(), target = 2026.4, scope = "results")
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E2"], "starts after the deadline")
  sol <- solve_target(d, g, tiny_cfg(), target = 2026.75, scope = "enablers", r_max = 1.2)
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E2"], "limit x1")
})

test_that("common target for milestones only touches milestone chains", {
  d <- tiny_data()
  g <- build_graph(d)
  sol <- solve_target(d, g, tiny_cfg(), target = 2026.25, scope = "milestones")
  # M1 requires E3 (2026.0-2026.5, s = 0.5): k = 0.5 -> r = 0.5^(-1/0.5) = 4
  expect_equal(sol$resources[["E3"]], 4)
  expect_equal(sol$resources[["E2"]], 1)
  expect_true(sol$feasible)
})

test_that("timing summary prices the acceleration", {
  d <- tiny_data()
  d$result$due[1] <- "2027-03"
  g <- build_graph(d)
  cfg <- tiny_cfg()
  sol <- solve_target(d, g, cfg, scope = "due")
  m <- run_model(d, g, cfg, resources = sol$resources)
  p <- run_model(d, g, cfg)
  s <- timing_summary(d, m, p)
  expect_equal(s$late_res_plan, 1)
  expect_equal(s$late_res, 0)
  expect_equal(s$extra_cost, sum(m$cost) - sum(p$cost))
  expect_equal(s$accelerated$id, names(which(sol$resources > 1)))
})
