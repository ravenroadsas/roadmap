# The editor's server, driven without a browser: load, add, connect, undo, export.

test_that("editor: copy, add an item, connect, undo, export and re-import", {
  skip_if_not_installed("shiny")
  shiny::testServer(editor_server, {
    session$setInputs(`start-current` = 1)
    expect_true(st$loaded)
    expect_false(st$dirty)
    n_en <- nrow(st$t$enabler)

    session$setInputs(`items-kind` = "enabler", `items-new` = 1)
    session$setInputs(`items-f_id` = "E-NEW", `items-f_name` = "Test enabler", `items-f_concept_id` = st$t$concept$id[1],
                      `items-f_start_q` = "2027Q1", `items-f_end_q` = "2027Q4", `items-f_capex_musd` = 2,
                      `items-f_opex_musd_yr` = 0.5, `items-f_cost_basis` = "fixed", `items-f_scalability` = 0.5)
    session$setInputs(`items-save` = 1)
    expect_equal(nrow(st$t$enabler), n_en + 1)
    expect_true(st$dirty)

    r1 <- st$t$result$id[1]
    session$setInputs(`board-connect` = list(from = "enabler:E-NEW", to = paste0("result:", r1)))
    expect_true(any(st$t$result_enabler$enabler_id == "E-NEW" & st$t$result_enabler$result_id == r1))
    expect_match(st$msg$text, "now requires")

    session$setInputs(`board-connect` = list(from = "enabler:E-NEW", to = "process:x"))
    expect_false(st$msg$ok)                                  # refused, nothing changes

    session$setInputs(undo = 1)
    expect_false(any(st$t$result_enabler$enabler_id == "E-NEW"))

    f <- tempfile(fileext = ".xlsx")
    write_input_excel(f, st$t, st$cfg)
    back <- editor_import(f)
    expect_length(back$probs, 0)
    expect_true("E-NEW" %in% back$tables$enabler$id)
  })
})

test_that("editor: a bad item is not saved and says why", {
  shiny::testServer(editor_server, {
    session$setInputs(`start-empty` = 1)
    session$setInputs(`items-kind` = "enabler", `items-new` = 1)
    session$setInputs(`items-f_id` = "E-01", `items-f_name` = "", `items-f_concept_id` = "",
                      `items-f_start_q` = "2027-1", `items-f_end_q` = "2027Q4", `items-save` = 1)
    expect_equal(nrow(st$t$enabler), 0)
    expect_false(st$msg$ok)
  })
})
