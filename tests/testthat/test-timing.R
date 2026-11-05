# tiny: E1 infra 2026Q1-2026Q4 (rigid) -> needed by E2 2026Q3-2027Q2 (s = 1);
#       E3 2026Q1-2026Q2 (s = 0.5); milestone M1 2026-12 on E1.

timing_data <- function() {
  d <- tiny_data()
  d$milestone <- data.frame(id = c("M1", "M2"), milestone_date = c("2026-12", "2027-06"),
                            name = c("m1", "m2"), enabler_id = c("E1", "E2"))
  d
}

test_that("milestones keep their relative position in a shortened build", {
  d <- timing_data()
  sch <- schedule(d$enabler, tiny_cfg(), c(E2 = 2))           # E2 (s = 1) half as long
  ms <- milestone_schedule(d$milestone, sch)
  expect_equal(ms$t[1], ms$t_plan[1])                         # E1 not accelerated
  expect_equal(ms$t[2], 2026.5 + (ms$t_plan[2] - 2026.5) / 2)
})

test_that("late dependencies are counted on the scenario schedule", {
  d <- timing_data()
  g <- build_graph(d)
  expect_equal(nrow(run_model(d, g, tiny_cfg())$issues), 0)
  m <- run_model(d, g, tiny_cfg(), resources = c(E2 = 4))     # E2 ends 2026.75, before E1 (2027.0)
  late <- m$issues[m$issues$type == "prereq_ends_later", ]
  expect_equal(c(late$enabler_id, late$related_id), c("E2", "E1"))
  expect_match(late$message, "2026Q4 \\(after 2026Q3\\)")
})

test_that("solve_target gives each enabler exactly the resources it needs", {
  d <- timing_data()
  cfg <- tiny_cfg()
  # M2 (plan mid-2027) by 2027.0 on E2 (start 2026.5, s = 1): k = 0.5/0.958 -> r = 1/k
  sol <- solve_target(d, cfg, 2027.0, pull_prereqs = FALSE)
  t2 <- month_to_time("2027-06")
  expect_equal(sol$resources[["E2"]], (t2 - 2026.5) / 0.5)
  expect_equal(sol$resources[["E1"]], 1)
  expect_true(sol$feasible)
  ms <- milestone_schedule(d$milestone, schedule(d$enabler, cfg, sol$resources))
  expect_equal(max(ms$t), 2027.0)
  # diminishing returns need more: r = k^(-1/s)
  d$enabler$scalability[2] <- 0.5
  expect_equal(solve_target(d, cfg, 2027.0, pull_prereqs = FALSE)$resources[["E2"]],
               ((t2 - 2026.5) / 0.5)^2)
})

test_that("rigid or impossible enablers are reported as blockers", {
  d <- timing_data()
  sol <- solve_target(d, tiny_cfg(), 2026.5)                 # M1 on rigid E1 is due 2026.96
  expect_false(sol$feasible)
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E1"], "rigid")
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E2"], "starts after the target")
  sol <- solve_target(d, tiny_cfg(), 2026.75, scope = "enablers", r_max = 1.2)
  expect_match(sol$blockers$reason[sol$blockers$enabler_id == "E2"], "limit x1")
})

test_that("pulling prerequisites forward avoids new late dependencies", {
  d <- timing_data()
  d$enabler$scalability[1] <- 1                              # make E1 scalable
  g <- build_graph(d)
  cfg <- tiny_cfg()
  no_pull <- solve_target(d, cfg, 2026.75, scope = "enablers", pull_prereqs = FALSE)
  pull <- solve_target(d, cfg, 2026.75, scope = "enablers", pull_prereqs = TRUE)
  late <- function(sol) sum(run_model(d, g, cfg, resources = sol$resources)$issues$type == "prereq_ends_later")
  # scope enablers already pulls E1 to 2026.75; check the milestone scope instead
  m_no <- solve_target(d, cfg, 2026.8, pull_prereqs = FALSE)
  m_yes <- solve_target(d, cfg, 2026.8, pull_prereqs = TRUE)
  expect_equal(late(m_no), 1)
  expect_equal(late(m_yes), 0)
  expect_gt(m_yes$resources[["E1"]], 1)
  expect_equal(late(pull), 0)
})

test_that("timing summary prices the acceleration", {
  d <- timing_data()
  g <- build_graph(d)
  cfg <- tiny_cfg()
  sol <- solve_target(d, cfg, 2027.0)
  m <- run_model(d, g, cfg, resources = sol$resources)
  p <- run_model(d, g, cfg)
  s <- timing_summary(d, m, p)
  expect_equal(s$last_ms, 2027.0)
  expect_gt(s$last_ms_plan, s$last_ms)
  expect_equal(s$extra_cost, sum(m$cost) - sum(p$cost))
  expect_equal(s$accelerated$id, names(which(sol$resources > 1)))
})
