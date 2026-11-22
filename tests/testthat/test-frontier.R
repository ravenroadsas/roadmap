test_that("enumeration matches the model for every combination of targets", {
  d <- tiny_data(); g <- build_graph(d)
  fr <- frontier_enumerate(d, g, tiny_cfg(discount_rate = 0.1), tiny_cfg())
  expect_equal(fr$n, 4 * 5)                                   # P1: M2..M5, P2: M1..M5
  for (i in seq_len(fr$n)) {
    p <- portfolio(run_model(d, g, tiny_cfg(discount_rate = 0.1), tiny_cfg(), targets = fr$targets[i, ]))
    expect_equal(fr$points$investment[i], p$total_cost)
    expect_equal(fr$points$npv[i], p$npv)
  }
  expect_equal(fr$targets[fr$base, ], c(P1 = 4L, P2 = 3L))
})

test_that("the frontier holds the best NPV for each investment", {
  d <- tiny_data(); g <- build_graph(d)
  fr <- frontier_enumerate(d, g, tiny_cfg(discount_rate = 0.1))
  f <- fr$points[fr$frontier, ]
  expect_true(all(diff(f$investment) >= 0) && all(diff(f$npv) > 0))
  dominated <- vapply(seq_len(nrow(f)), function(j)
    any(fr$points$investment <= f$investment[j] & fr$points$npv > f$npv[j] + 1e-9), TRUE)
  expect_false(any(dominated))
  expect_equal(f$investment[1], 0)                            # everyone at the current level
  expect_equal(frontier_rows(data.frame(investment = c(1, 1, 2, 3), npv = c(5, 6, 4, 7))), c(2L, 4L))
})
