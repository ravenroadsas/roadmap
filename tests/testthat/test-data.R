test_that("sample workbook loads through the data layer", {
  d <- sample_data()
  expect_named(d, ROADMAP_TABLES)
  expect_true(all(c("enabler_group", "concept", "fte_internal", "level") %in% names(d$enabler)))
  expect_true(all(d$process$current_level <= d$process$target_level))
  expect_true(all(d$milestone$level %in% 1:5))
  expect_true(all(d$metric$curve_id %in% d$curve$id))
  expect_true(any(d$enabler$cost_basis == "per_process"))
  expect_equal(attr(d, "table_info")$metric$rows, nrow(d$metric))
})

test_that("import replaces the database content", {
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  tabs <- read_input_excel(input_path())
  con <- db_connect(":memory:")
  on.exit(db_disconnect(con))
  db_init(con)
  db_import(con, tabs); db_import(con, tabs)
  expect_equal(nrow(db_read_all(con)$enabler), nrow(tabs$enabler))
})

test_that("config: four levers and the fixed assumptions", {
  ct <- sample_cfg()
  expect_setequal(ct$key[ct$in_sensitivity], c("adoption_years", "oil_price", "cost_multiplier", "resource_multiplier"))
  expect_true(all(CONFIG_REQUIRED %in% ct$key))
  expect_error(config_clean(ct[ct$key != "oil_price", ]), "oil_price")
})
