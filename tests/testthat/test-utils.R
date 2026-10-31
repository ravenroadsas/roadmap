test_that("formatting helpers", {
  expect_equal(fmt_musd(12.345), "$12.3M")
  expect_equal(fmt_musd(-3), "\u2212$3.0M")
  expect_equal(fmt_pct(0.256), "26%")
  expect_equal(fmt_num(9800, "bbl"), "9,800 bbl")
  expect_equal(fmt_num(4.1, "%"), "4.1%")
})

test_that("user access: management groups on Connect, open locally", {
  withr::local_envvar(ROADMAP_LOCAL_PUBLIC_ONLY = "")
  expect_true(user_access(NULL, NULL)$can_manage)
  expect_false(user_access("ana", c("staff"), "exec,board")$can_manage)
  expect_true(user_access("bob", c("staff", "board"), "exec,board")$can_manage)
  expect_false(user_access("bob", "board", "")$can_manage)
})

test_that("public audience hides private KPIs", {
  d <- tiny_data()
  expect_equal(visible_kpis(d, "public"), "K1")
  expect_equal(visible_kpis(d, "mgmt"), c("K1", "K2"))
})

test_that("selection parsing and sets", {
  expect_null(parse_selection(""))
  expect_null(parse_selection("bogus:1"))
  expect_equal(parse_selection("kpi:K1"), list(type = "kpi", id = "K1"))
  d <- tiny_data()
  g <- build_graph(d)
  s <- selection_sets(d, g, list(type = "enabler", id = "E1"), c("K1", "K2"))
  expect_setequal(s$en, c("E1", "E2"))
  expect_equal(s$kpi, "K1")
})

test_that("client payload applies filters and audience", {
  d <- tiny_data()
  g <- build_graph(d)
  m <- run_model(d, g, tiny_cfg())
  p <- viz_payload(d, m, "public", list(process = c("P1", "P2"), group = GROUPS$id, query = ""))
  expect_equal(p$kpis$id, "K1")
  expect_true(all(p$enablers$show))
  p <- viz_payload(d, m, "mgmt", list(process = "P2", group = GROUPS$id, query = ""))
  expect_equal(p$kpis$id[p$kpis$show], "K2")
  expect_equal(p$enablers$id[p$enablers$show], "E3")
})
