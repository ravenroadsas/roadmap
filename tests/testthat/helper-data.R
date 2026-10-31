# Shared fixtures: the packaged sample data, loaded through the data layer.
sample_data <- function() {
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  load_roadmap_data(":memory:")
}
sample_cfg <- function() config_read(board_type = "")

# Minimal hand-made roadmap: E1 (foundation) -> E2 -> K1; E3 -> K1, K2
tiny_data <- function() {
  list(
    process = data.frame(id = c("P1", "P2"), name = c("A", "B"), owner = "x", visibility = "public"),
    kpi = data.frame(id = c("K1", "K2"), process_id = c("P1", "P2"), name = c("k1", "k2"), unit = "%",
                     baseline = 1, target = 2, target_year = 2028, value_musd = c(10, 4),
                     value_driver = c("oil_price", "none"), visibility = c("public", "private")),
    enabler = data.frame(id = c("E1", "E2", "E3"), enabler_group = c("infra", "digital", "people"),
                         subcategory = "s", name = c("e1", "e2", "e3"),
                         start_q = c("2026Q1", "2026Q3", "2026Q1"), end_q = c("2026Q4", "2027Q2", "2026Q2"),
                         capex_musd = c(4, 2, 1), opex_musd_yr = c(1, 0, 0),
                         fte_internal = c(0, 1, 0), fte_partner = c(0, 1, 0),
                         scalability = c(0, 1, 0.5), visibility = "public"),
    enabler_link = data.frame(enabler_id = c("E2", "E3", "E3"), kpi_id = c("K1", "K1", "K2"),
                              weight = c(3, 1, 1)),
    enabler_dependency = data.frame(enabler_id = "E2", requires_id = "E1"),
    milestone = data.frame(id = "M1", milestone_date = "2026-12", name = "m", enabler_id = "E1",
                           visibility = "public")
  )
}
tiny_cfg <- function(...) {
  cfg <- list(oil_price = 75, realization = 1, adoption_delay = 0, ramp_years = 1,
              capex_overrun = 0, fte_cost = 100, partner_premium = 0, discount_rate = 0,
              horizon_end = 2030, resource_multiplier = 1)
  utils::modifyList(cfg, list(...))
}
