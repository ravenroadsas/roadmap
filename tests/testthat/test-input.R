# Excel input: round trip, defaults and validation messages.

xlsx_from <- function(tabs, drop_sheet = NULL) {
  f <- tempfile(fileext = ".xlsx")
  tabs <- tabs[setdiff(names(tabs), drop_sheet)]
  writexl::write_xlsx(tabs, f)
  f
}
tiny_tables <- function() {
  d <- tiny_data()
  lapply(stats::setNames(names(INPUT_SPEC), names(INPUT_SPEC)), function(t) d[[t]][, names(INPUT_SPEC[[t]])])
}

test_that("packaged workbook loads and every sheet has its columns", {
  x <- read_input_excel(input_path())
  expect_named(x, ROADMAP_TABLES)
  for (t in ROADMAP_TABLES) expect_named(x[[t]], names(INPUT_SPEC[[t]]))
  expect_type(x$enabler$capex_musd, "double")
  expect_true(all(grepl("^\\d{4}Q[1-4]$", x$enabler$start_q)))
})

test_that("write then read gives the same tables, plus a README sheet", {
  skip_if_not_installed("writexl")
  f <- tempfile(fileext = ".xlsx")
  write_input_excel(f, tiny_tables())
  expect_equal(readxl::excel_sheets(f)[1], "README")
  back <- read_input_excel(f)
  expect_equal(back$enabler, tiny_tables()$enabler, ignore_attr = TRUE)
  t <- tempfile(fileext = ".xlsx")
  write_input_excel(t)                                    # empty template
  expect_error(read_input_excel(t), "sheet 'kpi' has no rows", fixed = TRUE)
})

test_that("optional columns get defaults; extra columns, blank rows and loose formats are tolerated", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler$scalability <- NULL
  tabs$enabler$comment <- "ignored"
  tabs$kpi$value_driver <- NULL
  tabs$enabler$start_q[1] <- "2026 q1"
  tabs$milestone$milestone_date <- "2026-3"
  tabs$enabler_link <- rbind(tabs$enabler_link, data.frame(enabler_id = NA, kpi_id = NA, weight = NA))
  x <- read_input_excel(xlsx_from(tabs))
  expect_equal(x$enabler$scalability, c(0, 0, 0))
  expect_equal(x$kpi$value_driver, c("none", "none"))
  expect_false("comment" %in% names(x$enabler))
  expect_equal(x$enabler$start_q[1], "2026Q1")
  expect_equal(x$milestone$milestone_date, "2026-03")
  expect_equal(nrow(x$enabler_link), 3)
})

test_that("problems are all reported with sheet, column and row", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$kpi$value_musd <- NULL                              # required column missing
  tabs$enabler$capex_musd <- c("4", "two", "1")            # not a number (row 3)
  tabs$enabler$end_q[3] <- "Q3 2027"                        # not a quarter (row 4)
  tabs$process <- rbind(tabs$process, tabs$process[1, ])    # duplicate ID
  err <- tryCatch(read_input_excel(xlsx_from(tabs, drop_sheet = "milestone")), error = conditionMessage)
  expect_match(err, "sheet 'milestone' is missing", fixed = TRUE)
  expect_match(err, "sheet 'kpi': column 'value_musd' is missing", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'capex_musd', row 3: 'two' is not a number", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'end_q', row 4: 'Q3 2027' is not a quarter", fixed = TRUE)
  expect_match(err, "sheet 'process': duplicate P1", fixed = TRUE)
})

test_that("broken references and bad groups are reported after the format checks", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler_link$kpi_id[1] <- "K9"
  tabs$enabler$enabler_group[2] <- "software"
  err <- tryCatch(read_input_excel(xlsx_from(tabs)), error = conditionMessage)
  expect_match(err, "unknown kpi", fixed = TRUE)
  expect_match(err, "enabler_group 'software'", fixed = TRUE)
})

test_that("date conflicts do not block the import", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler$end_q[3] <- "2025Q4"                         # ends before it starts
  expect_silent(x <- read_input_excel(xlsx_from(tabs)))
  expect_equal(nrow(date_issues(x)), 1)
})
