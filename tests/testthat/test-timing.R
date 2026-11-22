# S3 (due 2027-12) ready 2027.5; set it due 2027-03 to make it late (E2 goes live 2027Q2).

late_tables <- function() { t <- tiny_tables(); t$milestone$due[1] <- "2027-03"; t }

test_that("a milestone in scope is late when its chain goes live after the due month", {
  expect_equal(nrow(tiny_model()$late), 0)
  m <- tiny_model(t = late_tables())
  expect_equal(m$late$milestone_id, "S3")
  expect_equal(m$late$enabler_id, "E2")
  expect_match(m$late$message, "can only be achieved in 2027Q2", fixed = TRUE)
  expect_equal(nrow(tiny_model(t = late_tables(), targets = c(P1 = 2))$late), 0)   # out of scope: not late
})

test_that("late dependencies are counted on the scenario schedule", {
  m <- tiny_model(resources = c(E2 = 4))                     # E2 ends before its prerequisite E1
  late <- m$issues[m$issues$type == "prereq_ends_later", ]
  expect_equal(c(late$enabler_id, late$related_id), c("E2", "E1"))
})

test_that("solve_target: due dates and a common date, with blockers, on the milestones in scope", {
  d <- prepare_data(late_tables()); g <- build_graph(d)
  sol <- solve_target(d, g, tiny_cfg(), scope = "due")
  expect_true(sol$feasible)
  expect_equal(sol$resources[["E2"]], 1 / 0.75)
  expect_equal(nrow(run_model(d, g, tiny_cfg(), resources = sol$resources)$late), 0)
  expect_equal(sol$resources[["E4"]], 1)
  sol0 <- solve_target(d, g, tiny_cfg(), scope = "due", targets = c(P1 = 2, P2 = 1))
  expect_true(all(sol0$resources == 1))                      # nothing in scope, nothing to accelerate
  sol <- solve_target(d, g, tiny_cfg(), target = 2026.75, scope = "date")
  expect_false(sol$feasible)
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E1"], "rigid")
})

test_that("scenario summary prices the acceleration; maturity summary compares by process", {
  d <- prepare_data(late_tables()); g <- build_graph(d)
  sol <- solve_target(d, g, tiny_cfg(), scope = "due")
  m <- run_model(d, g, tiny_cfg(), resources = sol$resources)
  b <- run_model(d, g, tiny_cfg())
  s <- scenario_summary(d, m, b)
  expect_equal(c(s$late_base, s$late), c(1, 0))
  expect_equal(sum(s$accelerated$extra_cost), s$p$total_cost - s$b$total_cost)
  ms <- maturity_summary(d, run_model(d, g, tiny_cfg(), targets = c(P1 = 2)), b)
  expect_equal(ms$by_process$tgt, c(2, 3))
  expect_equal(ms$by_process$ms, c(0, 2))
  expect_equal(ms$dropped, "E4")
  expect_length(ms$added, 0)
})
