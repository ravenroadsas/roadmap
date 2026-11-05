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
  expect_error(read_input_excel(t), "sheet 'result' has no rows", fixed = TRUE)
})

test_that("optional columns get defaults; extra columns, blank rows and loose formats are tolerated", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler$scalability <- NULL
  tabs$enabler$comment <- "ignored"
  tabs$result$value_driver <- NULL
  tabs$result$value_musd[3] <- NA                           # milestone without value
  tabs$result$kind[3] <- "Milestone"                        # case is tolerated
  tabs$enabler$start_q[1] <- "2026 q1"
  tabs$result$due[3] <- "2026-3"
  tabs$result_enabler <- rbind(tabs$result_enabler, data.frame(result_id = NA, enabler_id = NA, weight = NA))
  x <- read_input_excel(xlsx_from(tabs))
  expect_equal(x$enabler$scalability, c(0, 0, 0))
  expect_equal(x$result$value_driver, c("none", "none", "none"))
  expect_equal(x$result$value_musd[3], 0)
  expect_equal(x$result$kind[3], "milestone")
  expect_false("comment" %in% names(x$enabler))
  expect_equal(x$enabler$start_q[1], "2026Q1")
  expect_equal(x$result$due[3], "2026-03")
  expect_equal(nrow(x$result_enabler), 4)
})

test_that("problems are all reported with sheet, column and row", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$result$due <- NULL                                   # required column missing
  tabs$result$baseline[1] <- NA                             # a KPI needs a baseline
  tabs$enabler$capex_musd <- c("4", "two", "1")            # not a number (row 3)
  tabs$enabler$end_q[3] <- "Q3 2027"                        # not a quarter (row 4)
  tabs$process <- rbind(tabs$process, tabs$process[1, ])    # duplicate ID
  err <- tryCatch(read_input_excel(xlsx_from(tabs, drop_sheet = "enabler_dependency")), error = conditionMessage)
  expect_match(err, "sheet 'enabler_dependency' is missing", fixed = TRUE)
  expect_match(err, "sheet 'result': column 'due' is missing", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'capex_musd', row 3: 'two' is not a number", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'end_q', row 4: 'Q3 2027' is not a quarter", fixed = TRUE)
  expect_match(err, "sheet 'process': duplicate P1", fixed = TRUE)
})

test_that("broken references and bad groups are reported after the format checks", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$result_enabler$result_id[1] <- "K9"
  tabs$enabler$enabler_group[2] <- "software"
  tabs$result$baseline[1] <- NA
  tabs$result$value_driver <- c("oil_price", "gas", "none")
  err <- tryCatch(read_input_excel(xlsx_from(tabs)), error = conditionMessage)
  expect_match(err, "unknown result", fixed = TRUE)
  expect_match(err, "result K1: a KPI needs baseline and target", fixed = TRUE)
  expect_match(err, "value_driver 'gas'", fixed = TRUE)
  expect_match(err, "enabler_group 'software'", fixed = TRUE)
})

test_that("date conflicts do not block the import", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler$end_q[3] <- "2025Q4"                         # ends before it starts
  expect_silent(x <- read_input_excel(xlsx_from(tabs)))
  expect_equal(nrow(date_issues(x)), 1)
})

test_that("config comes from the workbook's config sheet", {
  ct <- config_read(board_type = "")
  expect_true(all(CONFIG_REQUIRED %in% ct$key))
  expect_type(ct$value, "double")
  expect_type(ct$is_pct, "logical")
  expect_equal(readxl::excel_sheets(input_path())[7], "config")
})

test_that("exported workbook carries the config and reads back the same", {
  skip_if_not_installed("writexl")
  ct <- config_read(board_type = "")
  f <- tempfile(fileext = ".xlsx")
  write_input_excel(f, tiny_tables(), ct)
  expect_equal(config_read(board_type = "", input = f), ct)
  readme <- readxl::read_excel(f, "README")
  expect_true("config" %in% readme$sheet)
})

test_that("config problems are reported together", {
  skip_if_not_installed("writexl")
  ct <- config_read(board_type = "")
  ct$value[ct$key == "oil_price"] <- 500                     # outside min-max
  ct <- ct[ct$key != "discount_rate", ]                       # required key missing
  ct$is_pct <- as.character(ct$is_pct)
  ct$is_pct[ct$key == "fte_cost"] <- "maybe"                  # not TRUE/FALSE
  ct$in_sensitivity <- ifelse(ct$in_sensitivity, "yes", "no") # yes/no is accepted
  f <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(config = ct), f)
  err <- tryCatch(config_read(board_type = "", input = f), error = conditionMessage)
  expect_match(err, "key 'fte_cost', column 'is_pct': 'maybe' is not TRUE/FALSE", fixed = TRUE)
  expect_match(err, "missing key(s): discount_rate", fixed = TRUE)
  ct$is_pct[ct$key == "fte_cost"] <- "FALSE"
  ct <- rbind(ct, config_read(board_type = "")[config_read(board_type = "")$key == "discount_rate", ])
  writexl::write_xlsx(list(config = ct), f)
  err <- tryCatch(config_read(board_type = "", input = f), error = conditionMessage)
  expect_match(err, "key 'oil_price': value 500 is outside min-max (45-110)", fixed = TRUE)
  f2 <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(process = data.frame(id = "P1")), f2)
  expect_error(config_read(board_type = "", input = f2), "sheet 'config' is missing", fixed = TRUE)
})
