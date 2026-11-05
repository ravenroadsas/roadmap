test_that("result tree: foundations left of required enablers, then result and value", {
  d <- tiny_data()
  m <- run_model(d, build_graph(d), tiny_cfg())
  t <- result_tree(d, m, "K1")
  col <- stats::setNames(t$nodes$col, t$nodes$id)
  expect_equal(unname(col[c("E1", "E2", "E3", "K1", "value")]), c(0, 1, 1, 2, 3))
  expect_equal(t$nodes$type[t$nodes$id == "E1"], "foundation")
  expect_match(t$nodes$type[t$nodes$id == "K1"], "^kpi")
  expect_setequal(paste(t$edges$from, t$edges$to, t$edges$type),
                  c("E1 E2 dependency", "E2 K1 link", "E3 K1 link", "K1 value value"))
  expect_true(all(col[t$edges$from] < col[t$edges$to]))
  expect_equal(sum(enabler_costs(m, "K1")[c("E1", "E2", "E3")]), portfolio(m, "K1")$total_cost)
  # a milestone has the same structure
  tm <- result_tree(d, m, "M1")
  expect_match(tm$nodes$type[tm$nodes$id == "M1"], "^milestone")
  expect_match(tm$nodes$label[tm$nodes$id == "value"], "No direct value", fixed = TRUE)
})

test_that("a required enabler that is also a prerequisite moves one column left", {
  d <- tiny_data()
  d$result_enabler <- rbind(d$result_enabler, data.frame(result_id = "K1", enabler_id = "E1", weight = 1))
  m <- run_model(d, build_graph(d), tiny_cfg())
  t <- result_tree(d, m, "K1")
  col <- stats::setNames(t$nodes$col, t$nodes$id)
  expect_equal(t$nodes$type[t$nodes$id == "E1"], "enabler")
  expect_lt(col[["E1"]], col[["E2"]])
  expect_true(all(col[t$edges$from] < col[t$edges$to]))
})

test_that("every sample result draws a tree with all arrows pointing right", {
  d <- sample_data()
  m <- run_model(d, build_graph(d), config_values(sample_cfg()))
  for (k in d$result$id) {
    t <- result_tree(d, m, k)
    col <- stats::setNames(t$nodes$col, t$nodes$id)
    expect_true(all(col[t$edges$from] < col[t$edges$to]), info = k)
    svg <- as.character(tree_svg(t, tree_titles(t)))
    expect_match(svg, "<svg", fixed = TRUE)
    expect_equal(length(tree_titles(t)), max(t$nodes$col) + 1)
  }
  expect_match(as.character(tree_svg(concept_tree())), "Result: milestone", fixed = TRUE)
})
