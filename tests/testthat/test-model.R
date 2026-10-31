test_that("cost profile conserves capex and adds people and opex", {
  d <- tiny_data()
  cfg <- tiny_cfg(capex_overrun = 0.5, partner_premium = 1)
  years <- 2026:2030
  m <- cost_profile(d$enabler, cfg, years)
  # E3: capex 1 x 1.5, all in 2026
  expect_equal(unname(m["E3", ]), c(1.5, 0, 0, 0, 0))
  # E2: capex 2 x 1.5 = 3, people (1 x 100 + 1 x 100 x 2) / 1000 = 0.3 /yr over 1 year build
  expect_equal(sum(m["E2", ]), 3 + 0.3)
  # E1: capex 4 x 1.5 in 2026, opex 1/yr from 2027 to 2030
  expect_equal(unname(m["E1", ]), c(6, 1, 1, 1, 1))
})

test_that("value starts after readiness and ramps to full", {
  d <- tiny_data()
  g <- build_graph(d)
  cfg <- tiny_cfg()
  v <- value_profile(d$kpi, g$ready, cfg, cfg, 2026:2030)
  expect_equal(unname(v["K1", "2026"]), 0)
  expect_equal(unname(v["K1", "2029"]), 10)          # fully ramped (ready mid-2027, ramp 1 yr)
  expect_true(v["K1", "2027"] < v["K1", "2028"])
  expect_equal(unname(attr(v, "run_rate")), c(10, 4))
})

test_that("drivers scale value relative to the base case", {
  d <- tiny_data()
  g <- build_graph(d)
  base <- tiny_cfg()
  hi <- tiny_cfg(oil_price = 150)
  m0 <- run_model(d, g, base, base)
  m1 <- run_model(d, g, hi, base)
  expect_equal(m1$run_rate[["K1"]], 2 * m0$run_rate[["K1"]])
  expect_equal(m1$run_rate[["K2"]], m0$run_rate[["K2"]])   # driver 'none'
})

test_that("portfolio of all KPIs carries the full cost; subsets add up", {
  d <- tiny_data()
  g <- build_graph(d)
  cfg <- tiny_cfg()
  m <- run_model(d, g, cfg)
  all <- portfolio(m)
  expect_equal(all$total_cost, sum(m$cost))
  k1 <- portfolio(m, "K1")
  k2 <- portfolio(m, "K2")
  expect_equal(k1$total_cost + k2$total_cost, all$total_cost)
  expect_equal(k1$total_value + k2$total_value, all$total_value)
  expect_equal(all$npv, sum(all$net))                          # discount rate 0
  expect_equal(all$roi, (all$total_value - all$total_cost) / all$total_cost)
})

test_that("payback is the first year with non-negative cumulative net", {
  d <- tiny_data()
  g <- build_graph(d)
  p <- portfolio(run_model(d, g, tiny_cfg()))
  i <- which(p$cum_net >= 0)[1]
  expect_equal(p$payback, p$years[i])
  expect_true(all(p$cum_net[seq_len(i - 1)] < 0))
})

test_that("tornado moves NPV in the expected direction on sample data", {
  d <- sample_data()
  g <- build_graph(d)
  ct <- sample_cfg()
  base <- config_values(ct)
  t <- tornado(d, g, base, base, ct)
  expect_equal(nrow(t), sum(ct$in_sensitivity))
  expect_true(all(diff(t$spread) <= 0))
  r <- t[t$key == "realization", ]
  expect_gt(r$npv_high, r$npv_low)
  o <- t[t$key == "capex_overrun", ]
  expect_lt(o$npv_high, o$npv_low)
})

test_that("no acceleration keeps the plan schedule and costs", {
  d <- tiny_data()
  sch <- schedule(d$enabler, tiny_cfg())
  expect_equal(sch$end, q_to_time(d$enabler$end_q, TRUE))
  expect_equal(sch$cost_factor, c(1, 1, 1))
})

test_that("acceleration shortens durations up to compressibility, with non-linear cost", {
  d <- tiny_data()
  full <- schedule(d$enabler, tiny_cfg(acceleration = 1, crash_exponent = 2))
  # E2: 1 year, compressibility 0.5 -> 0.5 year; E1 not compressible
  expect_equal(full$duration, c(1, 0.5, 0.5 * 0.8))
  expect_equal(full$people_factor[2], 4)        # (1 - 0.5)^-2
  expect_equal(full$cost_factor[2], 2)          # (1 - 0.5)^(1 - 2)
  lin <- schedule(d$enabler, tiny_cfg(acceleration = 1, crash_exponent = 1))
  expect_equal(lin$cost_factor, c(1, 1, 1))     # linear: same effort, less time
  half <- schedule(d$enabler, tiny_cfg(acceleration = 0.5, crash_exponent = 2))
  # cost premium grows faster than compression
  expect_gt((full$cost_factor[2] - 1) / (half$cost_factor[2] - 1),
            full$compression[2] / half$compression[2])
  expect_equal(schedule(transform(d$enabler, compressibility = 5), tiny_cfg(acceleration = 1))$compression[1], 0.9)
})

test_that("acceleration brings KPIs forward and raises build cost", {
  d <- tiny_data()
  g <- build_graph(d)
  base <- tiny_cfg()
  fast <- tiny_cfg(acceleration = 1)
  m0 <- run_model(d, g, base, base)
  m1 <- run_model(d, g, fast, base)
  expect_lt(m1$ready[["K1"]], m0$ready[["K1"]])
  expect_equal(m1$ready[["K1"]], 2027.0)        # E2 now ends 2027.0; E1 still 2027.0
  expect_gt(sum(m1$cost["E2", ]), sum(m0$cost["E2", ]))
  expect_gt(sum(m1$value["K1", ]), sum(m0$value["K1", ]))
})

test_that("database without compressibility column is migrated", {
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  con <- db_connect(":memory:")
  on.exit(db_disconnect(con))
  DBI::dbExecute(con, "CREATE TABLE enabler (id VARCHAR PRIMARY KEY, enabler_group VARCHAR, subcategory VARCHAR,
    name VARCHAR, start_q VARCHAR, end_q VARCHAR, capex_musd DOUBLE, opex_musd_yr DOUBLE,
    fte_internal DOUBLE, fte_partner DOUBLE, visibility VARCHAR)")
  db_init(con)
  expect_true("compressibility" %in% DBI::dbListFields(con, "enabler"))
})
