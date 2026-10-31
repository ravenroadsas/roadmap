test_that("data layer creates the schema and seeds every table", {
  d <- sample_data()
  expect_named(d, c("process", "kpi", "enabler", "enabler_link", "enabler_dependency", "milestone"))
  expect_equal(nrow(d$process), 6)
  expect_equal(nrow(d$enabler), 16)
  expect_true(all(d$kpi$visibility %in% c("public", "private")))
  expect_true(all(d$enabler$enabler_group %in% GROUPS$id))
  info <- attr(d, "table_info")
  expect_equal(info$kpi$rows, nrow(d$kpi))
})

test_that("seeding is idempotent", {
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  con <- db_connect(":memory:")
  on.exit(db_disconnect(con))
  db_init(con)
  db_init(con)
  expect_equal(nrow(db_read_all(con)$enabler), 16)
})

test_that("config reads from CSV and exposes values", {
  ct <- sample_cfg()
  v <- config_values(ct)
  expect_equal(v$horizon_end, 2033)
  expect_true(is.logical(ct$is_pct))
  expect_error(config_clean(ct[ct$key != "oil_price", ]), "oil_price")
})
