# Excel input: round trip, defaults and validation messages.

xlsx_from <- function(tabs, drop_sheet = NULL) {
  f <- tempfile(fileext = ".xlsx")
  tabs <- tabs[setdiff(names(tabs), drop_sheet)]
  writexl::write_xlsx(tabs, f)
  f
}
test_that("packaged workbook loads and every sheet has its columns", {
  x <- read_input_excel(input_path())
  expect_named(x, ROADMAP_TABLES)
  for (t in ROADMAP_TABLES) expect_named(x[[t]], names(INPUT_SPEC[[t]]))
  expect_type(x$enabler$capex_musd, "double")
  expect_true(all(grepl("^\\d{4}Q[1-4]$", x$enabler$start_q)))
})

test_that("write then read gives the same tables, plus README and levels sheets", {
  skip_if_not_installed("writexl")
  f <- tempfile(fileext = ".xlsx")
  write_input_excel(f, tiny_tables())
  expect_equal(readxl::excel_sheets(f)[1], "README")
  expect_true("levels" %in% readxl::excel_sheets(f))
  expect_equal(readxl::read_excel(f, "process")$current_level, c("M2", "M1"))   # levels written as M1..M5
  back <- read_input_excel(f)
  expect_equal(back$enabler, tiny_tables()$enabler, ignore_attr = TRUE)
  expect_equal(back$milestone, tiny_tables()$milestone, ignore_attr = TRUE)
  t <- tempfile(fileext = ".xlsx")
  write_input_excel(t)                                    # empty template, with the proposed curves
  expect_equal(nrow(readxl::read_excel(t, "curve")), nrow(DEFAULT_CURVES))
  expect_error(read_input_excel(t), "sheet 'milestone' has no rows", fixed = TRUE)
})

test_that("optional columns get defaults; extra columns, blank rows and loose formats are tolerated", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler$scalability <- NULL
  tabs$enabler$comment <- "ignored"
  tabs$metric$value_driver <- NULL
  tabs$metric$value_musd[2] <- NA
  tabs$enabler$cost_basis <- c("", "Per_Process", "fixed", "FIXED")
  tabs$enabler$start_q[1] <- "2026 q1"
  tabs$milestone$due[3] <- "2026-3"
  tabs$milestone$level <- c("M3", "m4", "2", "M 3")             # levels as M3, m4, 2
  tabs$milestone_enabler <- rbind(tabs$milestone_enabler, data.frame(milestone_id = NA, enabler_id = NA, weight = NA))
  x <- read_input_excel(xlsx_from(tabs, drop_sheet = "curve"))   # curve sheet left out: default curves
  expect_equal(x$enabler$scalability, rep(0, 4))
  expect_equal(x$metric$value_driver, c("none", "none"))
  expect_equal(x$metric$value_musd[2], 0)
  expect_equal(x$enabler$cost_basis, c("fixed", "per_process", "fixed", "fixed"))
  expect_false("comment" %in% names(x$enabler))
  expect_equal(x$enabler$start_q[1], "2026Q1")
  expect_equal(x$milestone$due[3], "2026-03")
  expect_equal(x$milestone$level, c(3, 4, 2, 3))
  expect_equal(nrow(x$milestone_enabler), 5)
  expect_equal(x$curve, DEFAULT_CURVES)
})

test_that("problems are all reported with sheet, column and row", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$milestone$due <- NULL                                # required column missing
  tabs$enabler$capex_musd <- c("4", "two", "1", "3")        # not a number (row 3)
  tabs$enabler$end_q[3] <- "Q3 2027"                        # not a quarter (row 4)
  tabs$enabler$level[4] <- "M7"                             # not a level (row 5)
  tabs$process <- rbind(tabs$process, tabs$process[1, ])    # duplicate ID
  err <- tryCatch(read_input_excel(xlsx_from(tabs, drop_sheet = "enabler_dependency")), error = conditionMessage)
  expect_match(err, "sheet 'enabler_dependency' is missing", fixed = TRUE)
  expect_match(err, "sheet 'milestone': column 'due' is missing", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'capex_musd', row 3: 'two' is not a number", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'end_q', row 4: 'Q3 2027' is not a quarter", fixed = TRUE)
  expect_match(err, "sheet 'enabler', column 'level', row 5: 'M7' is not a maturity level (M1 to M5)", fixed = TRUE)
  expect_match(err, "sheet 'process': duplicate P1", fixed = TRUE)
})

test_that("broken references, bad values and inconsistent levels are reported after the format checks", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$milestone_enabler$milestone_id[1] <- "S9"
  tabs$concept$enabler_group[2] <- "software"
  tabs$enabler$cost_basis[1] <- "shared"
  tabs$enabler$concept_id[3] <- "C9"
  tabs$metric$baseline[1] <- NA
  tabs$metric$value_driver <- c("oil_price", "gas")
  tabs$process$target_level[2] <- 1; tabs$process$current_level[2] <- 2
  tabs$curve$m3[1] <- 30                                     # concave goes down from M2 to M3
  err <- tryCatch(read_input_excel(xlsx_from(tabs)), error = conditionMessage)
  expect_match(err, "unknown milestone", fixed = TRUE)
  expect_match(err, "metric K1: a measure needs both baseline and target", fixed = TRUE)
  expect_match(err, "cost_basis 'shared'", fixed = TRUE)
  expect_match(err, "unknown concept C9", fixed = TRUE)
  expect_match(err, "value_driver 'gas'", fixed = TRUE)
  expect_match(err, "enabler_group 'software'", fixed = TRUE)
  expect_match(err, "process P2: target level M1 is below its current level M2", fixed = TRUE)
  expect_match(err, "curve concave: m1..m5 must be percentages", fixed = TRUE)
})

test_that("date conflicts do not block the import", {
  skip_if_not_installed("writexl")
  tabs <- tiny_tables()
  tabs$enabler$end_q[3] <- "2025Q4"                         # ends before it starts
  tabs$enabler$level[4] <- 5                                # level above the milestone that needs it
  expect_silent(x <- read_input_excel(xlsx_from(tabs)))
  expect_equal(nrow(date_issues(prepare_data(x))), 1)
})

test_that("config comes from the workbook's config sheet", {
  ct <- config_read(board_type = "")
  expect_true(all(CONFIG_REQUIRED %in% ct$key))
  expect_type(ct$value, "double")
  expect_type(ct$is_pct, "logical")
  expect_true("config" %in% readxl::excel_sheets(input_path()))
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

