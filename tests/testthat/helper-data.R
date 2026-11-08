# Shared fixtures.
sample_data <- function() {
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  load_roadmap_data(":memory:")
}
sample_cfg <- function() config_read(board_type = "")

# Minimal roadmap. Concepts: C1 infra (E1), C2 digital (E2, 1 int + 1 partner FTE), C3 people (E3, per process).
# E1 (foundation) -> E2 -> K1; E3 -> K1, K2, M1. K1, K2 are measured; M1 has no measure and no value.
tiny_tables <- function() {
  list(
    process = data.frame(id = c("P1", "P2"), name = c("A", "B"), owner = c("Ops lead", "CFO")),
    result = data.frame(id = c("K1", "K2", "M1"), process_id = c("P1", "P2", "P1"), name = c("k1", "k2", "m1"),
                        due = c("2028-12", "2028-12", "2026-12"), value_musd = c(10, 4, 0),
                        value_driver = c("oil_price", "none", "none"), unit = c("%", "%", ""),
                        baseline = c(1, 1, NA), target = c(2, 2, NA)),
    result_process = data.frame(result_id = character(0), process_id = character(0), share = numeric(0)),
    concept = data.frame(id = c("C1", "C2", "C3"), name = c("c1", "c2", "c3"),
                         enabler_group = c("infra", "digital", "people"), subgroup = "s",
                         fte_internal = c(0, 1, 0), fte_partner = c(0, 1, 0)),
    enabler = data.frame(id = c("E1", "E2", "E3"), concept_id = c("C1", "C2", "C3"), name = c("e1", "e2", "e3"),
                         start_q = c("2026Q1", "2026Q3", "2026Q1"), end_q = c("2026Q4", "2027Q2", "2026Q2"),
                         capex_musd = c(4, 2, 1), opex_musd_yr = c(1, 0, 0),
                         cost_basis = c("fixed", "fixed", "per_process"), scalability = c(0, 1, 0.5)),
    result_enabler = data.frame(result_id = c("K1", "K1", "K2", "M1"), enabler_id = c("E2", "E3", "E3", "E3"),
                                weight = c(3, 1, 1, 1)),
    enabler_dependency = data.frame(enabler_id = "E2", requires_id = "E1")
  )
}
tiny_data <- function() prepare_data(tiny_tables())
tiny_cfg <- function(...) {
  cfg <- list(oil_price = 75, realization = 1, adoption_years = 1, cost_multiplier = 1,
              fte_cost = 100, partner_premium = 0, discount_rate = 0, horizon_end = 2030,
              resource_multiplier = 1)
  utils::modifyList(cfg, list(...))
}
tiny_model <- function(..., scope = NULL, resources = NULL) {
  d <- tiny_data()
  run_model(d, build_graph(d), tiny_cfg(...), tiny_cfg(), resources, scope)
}
