# Digital Transformation Roadmap 2026–2029

Interactive roadmap that links **enablers** (investments) to **processes**, **KPIs** and **value**, with a sensitivity analysis on the main assumptions.

> **Status:** Shiny app v0.1 built as the R package `dtroadmap` (see below). `mockup/index.html` keeps the approved HTML prototype as the design reference.

## What the app shows

| Tab | Purpose |
|---|---|
| **Overview** | Portfolio summary: headline figures, indicators (cost mix, share spent on foundations, peak spend and manpower, first value, date issues), value vs allocated cost per process with owner, cost per enabler split into capex / people / opex, value for money per enabler, spend per year by enabler group, internal vs partner manpower per year. |
| **Roadmap** | Timeline (Gantt by enabler group, with milestones and dependency arrows) or Value chain view (Infra → Data → People → Digital → Process → KPI). Click a KPI to highlight its direct enablers and the foundations they need, with allocated cost, value, NPV and ROI. Click an enabler to see what it requires and what it unlocks. |
| **Sensitivity** | Sliders for the config assumptions. Shows the annual cost/value profile against the base case, an NPV tornado (each lever at low/high), and value by KPI. |
| **Data model** | The proposed lightweight schema. |

Roadmap filters (process, process owner, enabler group, search) drive the timeline, value chain, KPI list and the headline figures above them. Everything is visible to every user.

## Lightweight data model

```
process        (id, name, owner)
kpi            (id, process_id → process, name, unit, baseline, target, target_year,
                value_musd, value_driver [oil_price|labor|none])
enabler        (id, group [people|digital|data|infra], subcategory, name, start_q, end_q,
                capex_musd, opex_musd_yr, fte_internal, fte_partner)
enabler_link   (enabler_id → enabler, kpi_id → kpi, weight)      -- enabler → KPI → process
enabler_dependency (enabler_id → enabler, requires_id → enabler) -- DAG of prerequisites
milestone      (id, date, name, enabler_id → enabler)
config (pin)   (key, value, min, max, low, high, unit)
```

The three resource types map to columns: money (`capex`, `opex`), manpower and expertise (`fte_internal` for capability built or hired internally, `fte_partner` for allies and contractors).

## Calculation logic

- **Enabler cost / year** = capex × (1 + overrun), spread over the enabler's (scenario) duration + FTE cost during the build (partner FTE × (1 + partner premium)) + opex from go-live to the horizon.
- **Extra resources**: the scenario lever `resource_multiplier` (r, 1 = plan) puts more resources on every enabler. Each enabler's `scalability` (s) sets the response: duration × r^(−s), with the start date fixed. s = 0 is rigid (no resources added, no change), s = 1 is linear (half the time at the same total cost), s < 1 gives diminishing returns (total cost rises as r^(1−s)), and s > 1 is better than linear (total cost falls). The same capex and people effort are spread over the shorter build, so yearly expenditure is recalculated. Opex starts at the new go-live. The enabler detail panel shows plan vs scenario spend per year.
- **KPI ready date** = latest (scenario) end date across its direct enablers and all their prerequisites.
- **Date issues** (an end before the start, or a prerequisite going live after the enabler that needs it) don't block loading. They're shown in red on the timeline, value chain and detail panel. Missing references and dependency cycles still stop the app at startup.
- **KPI value / year** = `value_musd` × realisation × driver factor (oil price / base or FTE cost / base) × adoption ramp (starts after the adoption lag, linear over the ramp years).
- **Cost allocation**: each direct enabler is split across KPIs by link weight; foundation enablers pass their cost to the KPIs of their dependents, so shared infrastructure is spread rather than double-counted.
- **Portfolio**: NPV at the discount rate, ROI = (value − cost) / cost, payback = first year cumulative net ≥ 0.

## Shiny app (R package `dtroadmap`)

```
R/
  data_access.R          all DB interaction (DuckDB in dev, RSQLite fallback, DBI for SQL Server/Postgres later)
  config.R               config from a pin (ROADMAP_PINS_BOARD) or inst/extdata/config.csv
  fct_graph.R            dependency graph, validation, weights, cost allocation, ready dates
  fct_model.R            cost_profile(), value_profile(), run_model(), portfolio(), tornado()
  fct_payload.R          data sent to the browser canvas
  fct_detail.R           detail panel (KPI / enabler / process / portfolio)
  fct_charts.R           sensitivity chart data (tested) + echarts4r rendering, summary strip
  fct_overview.R         overview tables and indicators (tested) + charts
  utils.R                formatting helpers
  mod_overview_*, mod_roadmap_*, mod_sensitivity_*, mod_datamodel_*  (ui / server per tab)
  app_ui.R, app_server.R, run_app.R
inst/app/www/            styles.css, roadmap.js (timeline, value chain, highlighting, client-side)
inst/extdata/            seed CSVs, one per table + config.csv
inst/sql/schema.sql      DDL
tests/testthat/          unit tests for every function layer
docs/data_authoring_guide.md  how AI agents must format per-process data
app.R                    Posit Connect entry point
```

### Run

```r
# install.packages(c("shiny", "DBI", "duckdb", "echarts4r", "jsonlite", "pins", "testthat", "pkgload"))
pkgload::load_all(); run_app()        # or: shiny::runApp()
devtools::test()
```

### Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `ROADMAP_DB_PATH` | DuckDB file; seeded from CSV on first run | in-memory |
| `ROADMAP_DB_DRIVER` | `duckdb`, `sqlite` or `auto` | `auto` |
| `ROADMAP_PINS_BOARD` | `connect` or `folder` to read config from a pin | CSV |
| `ROADMAP_PINS_PATH` | folder for a folder board | |

On Posit Connect the signed-in user is shown in the header; there is no access split inside the app (control access with the Connect content settings).

### Performance

- Data, graph and config load once per R process and are shared by all sessions (`app_context()`).
- The roadmap canvas renders in the browser: clicks, highlighting, hover and view switching never call R. R only sends a new payload when filters, audience or assumptions change.
- Inputs are debounced; the model is vectorised and runs in milliseconds for this size. When the portfolio grows, the cost/value profiles can move to SQL views in DuckDB, or to a plumber API shared with other tools.
