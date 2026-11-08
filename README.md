# Transformation Roadmap 2026–2029 · v2

**Enablers make results possible. Results generate value for processes.**

v2 keeps the principles of v1 (branch `claude/transformation-roadmap-dashboard-hpay54`) and reduces the interface to the essential: three views, four levers, one result category.

```
CONCEPT ─groups─► ENABLER ──makes possible (weight)──► RESULT ──value $M/yr──► PROCESS(es)
 (FTE)              │ capex, opex, start → go-live        │ due date, optional measure
                    └ requires other enablers (foundations)
```

## Views

| View | What it answers |
|---|---|
| **Roadmap** | What, when, for what value, in the chosen **scope** (the processes being transformed). Headline: investment, value, NPV, when all results are ready. Chronogram: results per process (size = value, red = late) above the enablers by group › concept. Value chain: Foundations → Enablers → Results → Processes. Click anything to see what it depends on. |
| **Scenario** | What if: adoption time, oil price, cost multiplier, and acceleration (plan, more resources, every result by a target date, or every result by its due date). One chart of cumulative net value against the base case, and what acceleration costs. |
| **Model** | How it works: the chain, eight definitions, and the data workbook (download, template). |

## What changed from v1

- **One result category.** KPI and milestone are merged: every result has a due date and a value; a *measure* (unit, baseline → target) is optional. A result without a measure is a step change, achieved or not.
- **Concepts.** Enablers are classified group › subgroup › **concept** › enabler. People are planned on the concept (`fte_internal`, `fte_partner` over its build window) and spread over its enablers in proportion to their build duration, so total effort is kept.
- **Scope instead of filters.** Selecting processes asks "what if we transform only these": value counts the results they hold (at their share, for shared results); investment counts only the enablers those results need.
- **Cost basis.** `fixed` enablers cost the same whatever the scope. `per_process` enablers (e.g. change-management sessions) scale with the processes in scope: cost × (processes in scope / processes served) ^ scalability.
- **Four levers.** Adoption time (ready → full value), Brent price, cost multiplier (capex, people and opex), acceleration. Realisation, FTE cost, partner premium, discount rate and horizon are fixed assumptions in the config sheet.
- **No chart library.** Charts are plain SVG; `echarts4r` is no longer a dependency.

## Data

One Excel workbook (`ROADMAP_INPUT_XLSX`, default `inst/extdata/roadmap_input.xlsx`), one sheet per table:

```
process            (id, name, owner)
result             (id, process_id → lead process, name, due [YYYY-MM], value_musd, value_driver,
                    unit, baseline, target)                       -- measure optional
result_process     (result_id, process_id, share)                -- optional: shared results
concept            (id, name, enabler_group [people|digital|data|infra], subgroup, fte_internal, fte_partner)
enabler            (id, concept_id, name, start_q, end_q, capex_musd, opex_musd_yr,
                    cost_basis [fixed|per_process], scalability)
result_enabler     (result_id, enabler_id, weight)               -- result requires enabler
enabler_dependency (enabler_id, requires_id)                     -- prerequisites (foundations)
config             (key, label, unit, value, min, max, step, …, is_pct, in_sensitivity = lever, description)
```

Your roadmap is `data/roadmap_input_v1.xlsx`, converted to this format: 11 concepts proposed from the enabler map, FTE moved from enablers to concepts with the same total effort, role change and integrated teams set to `per_process`. Amber cells are placeholders; the `source` column says where each row comes from.

## Calculation

- **Ready date** of a result: the latest go-live across its required enablers and their prerequisites. **Late** when after the end of its due month.
- **Value / year**: `value_musd` × realisation × driver (oil price or FTE cost vs base) × adoption ramp (linear from ready to full over the adoption time).
- **Cost / year**: capex over the build, concept people during the build (partner at a premium), opex from go-live; all × cost multiplier.
- **Acceleration**: duration × r^(−scalability), start fixed; effort × r^(1−scalability). The solver back-calculates r per enabler for a target date or for each result's due date, and lists what can't make it.
- **Attributed cost** (detail panels): each enabler's cost split across the results that require it by weight; foundations pass theirs on.

## Code

```
R/
  data_access.R      Excel input (read, validate, export) and database
  config.R           config sheet (levers and fixed assumptions)
  fct_graph.R        dependency graph, shares, validation, date checks
  fct_model.R        concepts → enabler FTE, schedule, cost, value, scope, solver
  fct_payload.R      data for the browser canvas
  fct_detail.R       detail panel
  fct_views.R        headline figures, SVG chart, concept diagram
  fct_timing.R       scenario vs base
  mod_roadmap_*, mod_scenario_*, mod_model_*   one ui / server pair per view
inst/app/www/        styles.css, roadmap.js (chronogram, value chain, client-side)
docs/data_authoring_guide.md   how the authoring agent formats the data
```

### Run

```r
# install.packages(c("shiny", "DBI", "duckdb", "jsonlite", "readxl", "writexl", "pins", "testthat", "pkgload"))
pkgload::load_all(); run_app()        # or: shiny::runApp()
devtools::test()
```

### Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `ROADMAP_INPUT_XLSX` | Input workbook, one sheet per table | `inst/extdata/roadmap_input.xlsx` |
| `ROADMAP_DB_PATH` | DuckDB file (reloaded from the workbook at every start) | in-memory |
| `ROADMAP_DB_DRIVER` | `duckdb`, `sqlite` or `auto` | `auto` |
| `ROADMAP_PINS_BOARD` | `connect` or `folder` to read the config from a pin instead of the config sheet | config sheet |
| `ROADMAP_PINS_PATH` | folder for a folder board | |

On Posit Connect the signed-in user is shown in the header; there is no access split inside the app (control access with the Connect content settings).

### Performance

Data, graph and config load once per R process and are shared by sessions. The canvas renders in the browser (clicks, highlighting, hover and view switching never call R); R sends a new payload only when the scope, the search or the scenario changes.
