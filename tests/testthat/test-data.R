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

test_that("database load order respects foreign keys; earlier schemas are replaced", {
  # every table comes after the tables it references (DuckDB enforces this)
  sql <- paste(sql_statements(app_sys("sql", "schema.sql")), collapse = ";")
  for (t in DB_TABLES) {
    body <- regmatches(sql, regexpr(paste0("CREATE TABLE IF NOT EXISTS ", t, " \\([^;]*"), sql))
    refs <- unique(sub("REFERENCES ", "", regmatches(body, gregexpr("REFERENCES [a-z_]+", body))[[1]]))
    expect_true(all(match(refs, DB_TABLES) < match(t, DB_TABLES)), info = t)
  }
  expect_setequal(DB_TABLES, ROADMAP_TABLES)
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  f <- tempfile(fileext = ".db")
  con <- db_connect(f)
  DBI::dbExecute(con, "CREATE TABLE process (id VARCHAR PRIMARY KEY, name VARCHAR, owner VARCHAR)")   # v2 schema
  DBI::dbExecute(con, "CREATE TABLE result (id VARCHAR PRIMARY KEY, process_id VARCHAR REFERENCES process(id))")
  db_disconnect(con)
  d <- load_roadmap_data(f)
  expect_true("current_level" %in% names(d$process))
  con <- db_connect(f); on.exit(db_disconnect(con))
  expect_false("result" %in% DBI::dbListTables(con))
})
