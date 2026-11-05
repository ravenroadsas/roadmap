test_that("cost parts add up to the cost profile", {
  d <- tiny_data()
  m <- run_model(d, build_graph(d), tiny_cfg(resource_multiplier = 2))
  cp <- m$cost_parts
  expect_equal(cp$capex + cp$people + cp$opex, m$cost)
  expect_equal(sum(cp$capex["E2", ]), 2 * m$schedule$cost_factor[2])   # capex 2, overrun 0
})

test_that("enabler cost table: totals, direct value and leverage", {
  d <- tiny_data()
  m <- run_model(d, build_graph(d), tiny_cfg())
  et <- enabler_cost_table(d, m)
  expect_equal(sum(et$total), sum(m$cost))
  expect_equal(et$id[1], et$id[which.max(et$total)])
  e1 <- et[et$id == "E1", ]
  expect_equal(e1$direct_value, 0)                       # foundation
  e3 <- et[et$id == "E3", ]
  expect_equal(e3$value_per_cost, e3$direct_value / e3$total)
})

test_that("process table: value and allocated cost add up to the portfolio", {
  d <- tiny_data()
  m <- run_model(d, build_graph(d), tiny_cfg())
  pt <- process_table(d, m)
  p <- portfolio(m)
  expect_equal(sum(pt$value), p$total_value)
  expect_equal(sum(pt$cost), p$total_cost)
  expect_equal(pt$owner[pt$id == "P2"], "CFO")
  expect_true(all(pt$first_value <= pt$full_value))
})

test_that("spend by group and FTE profile", {
  d <- tiny_data()
  m <- run_model(d, build_graph(d), tiny_cfg())
  sg <- spend_by_group(d, m)
  expect_equal(sum(sg[GROUPS$id]), sum(m$cost), tolerance = 1e-6)
  fte <- fte_profile(d$enabler, m$years, m$schedule)
  expect_equal(sum(fte$internal), 1)                     # E2: 1 FTE for 1 year
  expect_equal(sum(fte$partner), 1)
  s <- overview_stats(d, m)
  expect_equal(s$capex_share + s$people_share + s$opex_share, 1)
  expect_equal(s$n_issues, 0)
})
