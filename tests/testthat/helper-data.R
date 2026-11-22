# Shared fixtures.
sample_data <- function() {
  skip_if_not(requireNamespace("RSQLite", quietly = TRUE) || requireNamespace("duckdb", quietly = TRUE))
  load_roadmap_data(":memory:")
}
sample_cfg <- function() config_read(board_type = "")

# Minimal v3 roadmap.
# P1: M2 today, target M4. P2: M1 today, target M3.
# Enablers: E1 infra M2 (foundation of E2), E2 digital M3, E3 people M2 (per process), E4 digital M4.
# Milestones: S3 (P1, M3) <- E2 (w3), E3 (w1); S4 (P1, M4) <- E4; T2 (P2, M2) <- E3; T3 (P2, M3) <- E2.
# Metrics: K1 (P1, $10M, oil, linear, 1 -> 2) <- S3, S4; K2 (P2, $4M, concave) <- T2, T3.
# Ready: E1 2027.0, E2 2027.5, E3 2026.5, E4 2028.0 -> S3 2027.5, S4 2028.0, T2 2026.5, T3 2027.5.
tiny_tables <- function() {
  list(
    process = data.frame(id = c("P1", "P2"), name = c("A", "B"), owner = c("Ops lead", "CFO"),
                         current_level = c(2, 1), target_level = c(4, 3)),
    milestone = data.frame(id = c("S3", "S4", "T2", "T3"), process_id = c("P1", "P1", "P2", "P2"),
                           name = c("s3", "s4", "t2", "t3"), due = c("2027-12", "2028-06", "2026-12", "2027-12"),
                           level = c(3, 4, 2, 3)),
    metric = data.frame(id = c("K1", "K2"), process_id = c("P1", "P2"), name = c("k1", "k2"), unit = c("%", ""),
                        baseline = c(1, NA), target = c(2, NA), value_musd = c(10, 4),
                        value_driver = c("oil_price", "none"), curve_id = c("linear", "concave")),
    metric_milestone = data.frame(metric_id = c("K1", "K1", "K2", "K2"), milestone_id = c("S3", "S4", "T2", "T3")),
    curve = DEFAULT_CURVES,
    concept = data.frame(id = c("C1", "C2", "C3"), name = c("c1", "c2", "c3"),
                         enabler_group = c("infra", "digital", "people"), subgroup = "s",
                         fte_internal = c(0, 1, 0), fte_partner = c(0, 1, 0)),
    enabler = data.frame(id = c("E1", "E2", "E3", "E4"), concept_id = c("C1", "C2", "C3", "C2"),
                         name = c("e1", "e2", "e3", "e4"), level = c(2, 3, 2, 4),
                         start_q = c("2026Q1", "2026Q3", "2026Q1", "2027Q1"), end_q = c("2026Q4", "2027Q2", "2026Q2", "2027Q4"),
                         capex_musd = c(4, 2, 1, 3), opex_musd_yr = c(1, 0, 0, 0),
                         cost_basis = c("fixed", "fixed", "per_process", "fixed"), scalability = c(0, 1, 0.5, 1)),
    milestone_enabler = data.frame(milestone_id = c("S3", "S3", "S4", "T2", "T3"),
                                   enabler_id = c("E2", "E3", "E4", "E3", "E2"), weight = c(3, 1, 1, 1, 1)),
    enabler_dependency = data.frame(enabler_id = "E2", requires_id = "E1")
  )
}
tiny_data <- function(t = tiny_tables()) prepare_data(t)
tiny_cfg <- function(...) {
  cfg <- list(oil_price = 75, realization = 1, adoption_years = 1, cost_multiplier = 1,
              fte_cost = 100, partner_premium = 0, discount_rate = 0, horizon_end = 2030,
              resource_multiplier = 1)
  utils::modifyList(cfg, list(...))
}
tiny_model <- function(..., targets = NULL, scope = NULL, resources = NULL, t = tiny_tables()) {
  d <- prepare_data(t)
  run_model(d, build_graph(d), tiny_cfg(...), tiny_cfg(), resources, targets, scope)
}
