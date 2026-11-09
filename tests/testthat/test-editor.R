# Editor operations on an in-memory copy of the tables.
ed <- function() clean_tables(tiny_tables())

test_that("empty tables, ids and new items", {
  e <- empty_tables()
  expect_named(e, names(INPUT_SPEC))
  expect_equal(nrow(e$enabler), 0)
  t <- ed()
  expect_equal(next_id(t, "process"), "P3")                  # follows the existing pattern P1, P2
  expect_equal(next_id(empty_tables(), "enabler"), "E-01")    # default prefix when empty
  t2 <- t; t2$enabler$id <- c("E08", "E09", "X-1")
  expect_equal(next_id(t2, "enabler"), "E10")
  t$enabler$id <- c("E-01", "E-02", "E-07")
  expect_equal(next_id(t, "enabler"), "E-08")
  n <- new_item(t, "enabler")
  expect_equal(n$cost_basis, "fixed")
  expect_equal(n$concept_id, "C1")
})

test_that("upsert checks fields and cascades id renames", {
  t <- ed()
  row <- new_item(t, "result")
  row$name <- "new result"
  t2 <- upsert_item(t, "result", row)
  expect_equal(nrow(t2$result), 4)
  bad <- row; bad$due <- "June"; bad$baseline <- 1
  expect_setequal(upsert_item(t, "result", bad), c("due must look like 2027-03", "a measure needs both baseline and target"))
  dup <- row; dup$id <- "K1"
  expect_match(upsert_item(t, "result", dup), "already used")
  e <- as.list(t$enabler[t$enabler$id == "E2", ]); e$id <- "E9"; e$capex_musd <- 7
  t3 <- upsert_item(t, "enabler", e, old_id = "E2")
  expect_equal(t3$enabler$capex_musd[t3$enabler$id == "E9"], 7)
  expect_true("E9" %in% t3$result_enabler$enabler_id)
  expect_equal(t3$enabler_dependency$enabler_id, "E9")
  e$end_q <- "2025Q1"
  expect_match(upsert_item(t, "enabler", e, old_id = "E2"), "end_q is before start_q")
})

test_that("delete cascades connections, and refuses when still in use", {
  t <- ed()
  t2 <- delete_item(t, "enabler", "E1")
  expect_false("E1" %in% t2$enabler$id)
  expect_equal(nrow(t2$enabler_dependency), 0)
  expect_match(delete_item(t, "process", "P1"), "still leads 2 result")
  expect_match(delete_item(t, "concept", "C1"), "still has 1 enabler")
  t3 <- delete_item(t, "result", "K1")
  expect_false("K1" %in% t3$result_enabler$result_id)
})

test_that("connections: rules, loops, sharing, concepts", {
  t <- ed()
  r <- connect_nodes(t, "enabler:E1", "result:K2")
  expect_equal(r$message, "k2 now requires e1")
  expect_true(any(r$tables$result_enabler$enabler_id == "E1" & r$tables$result_enabler$result_id == "K2"))
  expect_equal(connect_nodes(t, "enabler:E2", "result:K1"), "already connected")
  expect_match(connect_nodes(t, "result:K1", "enabler:E1"), "a result can't be connected to a enabler")
  # E2 needs E1: making E1 need E2 closes a loop, named in order
  expect_equal(connect_nodes(t, "enabler:E2", "enabler:E1"), "this would close a loop: e1 \u2192 e2 \u2192 e1")
  d <- connect_nodes(t, "enabler:E3", "enabler:E2")
  expect_equal(d$message, "e2 now needs e3 first")
  s <- connect_nodes(t, "result:K1", "process:P2")
  expect_equal(nrow(s$tables$result_process), 2)               # lead row added with the share
  expect_equal(connect_nodes(t, "result:K1", "process:P1"), "this is already its lead process")
  m <- connect_nodes(t, "enabler:E1", "concept:C2")
  expect_equal(m$tables$enabler$concept_id[m$tables$enabler$id == "E1"], "C2")
})

test_that("link values and removal", {
  t <- ed()
  t2 <- set_link_value(t, "re|E2|K1", 5)
  expect_equal(t2$result_enabler$weight[t2$result_enabler$enabler_id == "E2"], 5)
  expect_match(set_link_value(t, "re|E2|K1", -1), "above 0")
  expect_match(set_link_value(t, "dep|E1|E2", 2), "no value")
  t3 <- remove_link(t, "dep|E1|E2")
  expect_equal(nrow(t3$enabler_dependency), 0)
  s <- connect_nodes(t, "result:K1", "process:P2")$tables
  s2 <- remove_link(s, "rp|K1|P2")
  expect_equal(nrow(s2$result_process), 0)                     # only the lead was left: sharing rows dropped
})

test_that("board payload has four columns and typed links", {
  p <- board_payload(ed())
  expect_equal(vapply(p$cols, `[[`, "", "key"), c("concept", "enabler", "result", "process"))
  expect_setequal(unique(p$links$kind), c("dep", "re", "lead", "cpt"))
  expect_equal(sum(p$links$kind == "re"), 4)
})

test_that("in-memory validation and lenient import", {
  t <- ed()
  expect_length(validate_tables(t), 0)
  t$result$process_id[1] <- ""
  t$enabler$cost_basis[1] <- "maybe"
  v <- validate_tables(t)
  expect_match(v, "process_id is empty for K1", all = FALSE, fixed = TRUE)
  expect_match(v, "cost_basis 'maybe'", all = FALSE, fixed = TRUE)
  skip_if_not_installed("writexl")
  f <- tempfile(fileext = ".xlsx")
  x <- ed(); x$enabler_dependency <- NULL
  writexl::write_xlsx(x, f)
  expect_error(read_input_excel(f), "enabler_dependency' is missing")
  y <- read_input_excel(f, strict = FALSE)
  expect_match(attr(y, "problems"), "enabler_dependency' is missing", all = FALSE)
  expect_equal(nrow(y$enabler), 3)
})

test_that("board payload works on empty tables", {
  p <- board_payload(empty_tables())
  expect_equal(nrow(p$links), 0)
  expect_true(all(vapply(p$cols, function(c) nrow(c$items), 0) == 0))
})
