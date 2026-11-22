test_that("concept FTE is spread over its enablers, keeping total effort", {
  t <- tiny_tables()
  t$concept <- rbind(t$concept, data.frame(id = "C4", name = "c4", enabler_group = "data", subgroup = "",
                                           fte_internal = 10, fte_partner = 0))
  t$enabler <- rbind(t$enabler,
    data.frame(id = c("E5", "E6"), concept_id = "C4", name = c("e5", "e6"), level = 3, start_q = c("2026Q1", "2026Q1"),
               end_q = c("2026Q4", "2026Q4"), capex_musd = 0, opex_musd_yr = 0, cost_basis = "fixed", scalability = 1))
  e <- prepare_data(t)$enabler
  expect_equal(e$fte_internal[e$id %in% c("E5", "E6")], c(5, 5))   # parallel: 10 FTE shared
  expect_equal(e$enabler_group[e$id == "E5"], "data")
  t$enabler$end_q[t$enabler$id == "E6"] <- "2027Q4"
  e <- prepare_data(t)$enabler
  e <- e[e$id %in% c("E5", "E6"), ]
  expect_equal(sum(e$fte_internal[order(e$id)] * c(1, 2)), 10 * 2)  # concept FTE x window
})

test_that("cost parts: capex over the build, people from concept FTE, opex after go-live; multiplier on all", {
  m <- tiny_model()
  expect_equal(unname(m$cost_parts$capex["E1", ]), c(4, 0, 0, 0, 0))
  expect_equal(unname(m$cost_parts$opex["E1", ]), c(0, 1, 1, 1, 1))
  expect_equal(sum(m$cost_parts$people[c("E2", "E4"), ]), (1 * 100 + 1 * 100) / 1000 * 1.5)  # C2 window 2026Q3-2027Q4
  expect_equal(sum(tiny_model(cost_multiplier = 1.5)$full_cost), 1.5 * sum(m$full_cost))
})

test_that("scalability: 0 rigid, 1 linear, <1 diminishing, >1 better than linear", {
  d <- tiny_data()
  d$enabler$start_q <- "2026Q1"; d$enabler$end_q <- "2027Q4"
  sch <- function(sc, r) schedule(transform(d$enabler, scalability = sc), tiny_cfg(resource_multiplier = r))
  expect_equal(sch(0, 2)$duration, rep(2, 4))
  expect_equal(sch(1, 2)$duration, rep(1, 4))
  expect_equal(sch(1, 2)$cost_factor, rep(1, 4))
  expect_gt(sch(0.5, 2)$cost_factor[1], 1)
  expect_lt(sch(1.5, 2)$cost_factor[1], 1)
})

test_that("targets: kept between current level and M5; scope leaves processes at their current level", {
  d <- tiny_data()
  expect_equal(effective_targets(d), c(P1 = 4L, P2 = 3L))
  expect_equal(effective_targets(d, c(P1 = 1, P2 = 9)), c(P1 = 2L, P2 = 5L))
  expect_equal(effective_targets(d, scope = "P2"), c(P1 = 2L, P2 = 3L))
  expect_equal(milestones_in_scope(d, c(P1 = 3L, P2 = 1L)), c(S3 = TRUE, S4 = FALSE, T2 = FALSE, T3 = FALSE))
})

test_that("metrics climb their curve as their milestones are ready", {
  m <- tiny_model()
  # K1: linear, from M2; S3 (M3) ready 2027.5 adds (0.5-0.25)/0.75, S4 (M4) ready 2028 adds the same
  expect_equal(m$steps$K1$level, c(3, 4))
  expect_equal(m$steps$K1$t, c(2027.5, 2028))
  expect_equal(m$steps$K1$delta, c(1, 1) / 3)
  # K2: concave, from M1: T2 (M2) +45%, T3 (M3) +30%
  expect_equal(m$steps$K2$delta, c(.45, .30))
  expect_equal(unname(m$impact), c(2 / 3, .75))
  expect_equal(unname(m$run_rate), c(10 * 2 / 3, 4 * .75))
  expect_equal(unname(m$metric_level), c(4, 3))
  expect_equal(unname(tiny_model(targets = c(P1 = 5))$impact[["K1"]]), 2 / 3)   # no M5 milestone: no more impact
  expect_equal(tiny_model(oil_price = 150)$run_rate[["K1"]], 2 * 10 * 2 / 3)
})

test_that("value ramps over the adoption time from each step", {
  m <- tiny_model()
  expect_equal(unname(m$value["K1", "2026"]), 0)
  expect_equal(unname(m$value["K1", "2030"]), 10 * 2 / 3)         # both steps fully adopted
  expect_lt(unname(tiny_model(adoption_years = 3)$value["K1", "2029"]), unname(m$value["K1", "2029"]))
})

test_that("process path: a level is reached when its milestones are ready", {
  m <- tiny_model()
  expect_equal(m$path$t[m$path$process_id == "P1"], c(2027.5, 2028))
  expect_equal(m$path$t[m$path$process_id == "P2"], c(2026.5, 2027.5))
  # without an M3 milestone, P1 reaches M3 together with M4
  t <- tiny_tables()
  t$milestone$level[1] <- 4
  expect_equal(tiny_model(t = t)$path$t[1:2], c(2028, 2028))
})

test_that("maturity targets set scope, investment and value", {
  full <- tiny_model()
  p <- portfolio(full)
  expect_equal(p$total_cost, sum(full$full_cost))                 # everything needed at base targets
  expect_equal(p$total_value, sum(full$value))
  # P1 stays at M2: S3, S4 out; E4 not needed; E3 per process: 1 of 2 processes, scalability 0.5
  m <- tiny_model(targets = c(P1 = 2))
  expect_equal(unname(m$in_scope), c(FALSE, FALSE, TRUE, TRUE))
  expect_equal(m$scope_factor[["E4"]], 0)
  expect_equal(m$scope_factor[["E2"]], 1)                          # still needed by T3
  expect_equal(m$scope_factor[["E3"]], 0.5^0.5)
  expect_equal(m$run_rate[["K1"]], 0)
  expect_equal(portfolio(m)$total_cost, sum(full$full_cost[c("E1", "E2"), ]) + sum(full$full_cost["E3", ]) * 0.5^0.5)
  # nobody moves: nothing is built, no value
  none <- tiny_model(targets = c(P1 = 2, P2 = 1))
  expect_equal(c(portfolio(none)$total_cost, portfolio(none)$total_value), c(0, 0))
  # same through the roadmap scope
  expect_equal(portfolio(tiny_model(scope = "P2"))$total_cost, portfolio(m)$total_cost)
})

test_that("attributed cost adds up to the portfolio over in-scope milestones", {
  for (tg in list(NULL, c(P1 = 3))) {
    m <- tiny_model(targets = tg)
    ids <- names(m$in_scope)[m$in_scope]
    a <- vapply(ids, function(k) attributed_cost(m, k)$cost, 0)
    expect_equal(sum(a), portfolio(m)$total_cost)
  }
  d <- tiny_data(); m <- tiny_model()
  f <- vapply(d$process$id, function(i) process_figures(d, m, i)$cost, 0)
  expect_equal(sum(f), portfolio(m)$total_cost)
})
