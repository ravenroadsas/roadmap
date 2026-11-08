test_that("concept FTE is spread over its enablers, keeping total effort", {
  t <- tiny_tables()
  t$concept <- rbind(t$concept, data.frame(id = "C4", name = "c4", enabler_group = "data", subgroup = "",
                                           fte_internal = 10, fte_partner = 0))
  t$enabler <- rbind(t$enabler,
    data.frame(id = c("E4", "E5"), concept_id = "C4", name = c("e4", "e5"), start_q = c("2026Q1", "2026Q1"),
               end_q = c("2026Q4", "2026Q4"), capex_musd = 0, opex_musd_yr = 0, cost_basis = "fixed", scalability = 1))
  d <- prepare_data(t)
  e <- d$enabler
  expect_equal(e$fte_internal[e$id %in% c("E4", "E5")], c(5, 5))   # parallel: 10 FTE shared
  expect_equal(e$fte_internal[e$id == "E2"], 1)                    # single enabler keeps the concept FTE
  expect_equal(e$enabler_group[e$id == "E4"], "data")
  expect_equal(e$concept[e$id == "E4"], "c4")
  t$enabler$end_q[t$enabler$id == "E5"] <- "2027Q4"                # sequential-ish: effort kept
  d <- prepare_data(t)
  e <- d$enabler[d$enabler$id %in% c("E4", "E5"), ]
  dur <- c(1, 2)
  expect_equal(sum(e$fte_internal[order(e$id)] * dur), 10 * 2)     # concept FTE x window
})

test_that("cost parts: capex over the build, people from concept FTE, opex after go-live; multiplier on all", {
  m <- tiny_model()
  expect_equal(unname(m$cost_parts$capex["E1", ]), c(4, 0, 0, 0, 0))
  expect_equal(unname(m$cost_parts$opex["E1", ]), c(0, 1, 1, 1, 1))
  expect_equal(sum(m$cost_parts$people["E2", ]), (1 * 100 + 1 * 100) / 1000)
  m2 <- tiny_model(cost_multiplier = 1.5)
  expect_equal(sum(m2$full_cost), 1.5 * sum(m$full_cost))
})

test_that("scalability: 0 rigid, 1 linear, <1 diminishing, >1 better than linear", {
  d <- tiny_data()
  d$enabler$start_q <- "2026Q1"; d$enabler$end_q <- "2027Q4"
  sch <- function(sc, r) schedule(transform(d$enabler, scalability = sc), tiny_cfg(resource_multiplier = r))
  expect_equal(sch(0, 2)$duration, c(2, 2, 2))
  expect_equal(sch(1, 2)$duration, c(1, 1, 1))
  expect_equal(sch(1, 2)$cost_factor, c(1, 1, 1))
  expect_gt(sch(0.5, 2)$cost_factor[1], 1)
  expect_lt(sch(1.5, 2)$cost_factor[1], 1)
})

test_that("value ramps over the adoption time once the result is ready", {
  m <- tiny_model()
  expect_equal(unname(m$value["K1", "2026"]), 0)
  expect_equal(unname(m$value["K1", "2029"]), 10)            # ready mid-2027, 1 year ramp
  expect_lt(unname(tiny_model(adoption_years = 3)$value["K1", "2028"]), unname(m$value["K1", "2028"]))
  expect_equal(unname(m$run_rate), c(10, 4, 0))
  expect_equal(tiny_model(oil_price = 150)$run_rate[["K1"]], 20)
})

test_that("full scope: portfolio carries all cost and value; attribution adds up", {
  m <- tiny_model()
  p <- portfolio(m)
  expect_equal(p$total_cost, sum(m$full_cost))
  expect_equal(p$total_value, sum(m$value))
  a <- vapply(c("K1", "K2", "M1"), function(k) attributed(m, k)$cost, 0)
  expect_equal(sum(a), p$total_cost)
  expect_gt(a[["M1"]], 0)                                    # a result without value still carries cost
})

test_that("scope: value at in-scope share, only needed enablers, per-process cost scaled", {
  full <- tiny_model()
  p2 <- tiny_model(scope = "P2")                             # only K2: needs E3 only
  expect_equal(unname(p2$scope_w), c(0, 1, 0))
  expect_equal(unname(p2$scope_factor[c("E1", "E2")]), c(0, 0))
  # E3 is per process, serves P1 and P2, scalability 0.5: (1/2)^0.5
  expect_equal(p2$scope_N[["E3"]], 2)
  expect_equal(p2$scope_factor[["E3"]], 0.5^0.5)
  expect_equal(portfolio(p2)$total_cost, sum(full$full_cost["E3", ]) * 0.5^0.5)
  expect_equal(portfolio(p2)$total_value, sum(full$value["K2", ]))
  # fixed cost basis: full cost whatever the scope
  t <- tiny_tables(); t$enabler$cost_basis[3] <- "fixed"
  d <- prepare_data(t)
  expect_equal(run_model(d, build_graph(d), tiny_cfg(), scope = "P2")$scope_factor[["E3"]], 1)
  expect_equal(portfolio(tiny_model(scope = character(0)))$total_cost, 0)
})
