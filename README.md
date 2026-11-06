# Digital Transformation Roadmap 2026–2029

Interactive roadmap built on one value chain: **each process has results** (KPIs and milestones, the two kinds of tangible outcome) that generate value; **each result explicitly requires N enablers**; enablers may need other enablers first (foundations). Includes a sensitivity analysis on cost, value and time.

```
PROCESS ──has──► RESULT (KPI | milestone) ──requires (weight)──► ENABLER ──requires──► ENABLER (foundation)
   ▲                 │ due date, value $M/yr                         │ cost, staff, start → go-live
   └──── value ──────┘
```

> **Status:** Shiny app v0.1 built as the R package `dtroadmap` (see below). `mockup/index.html` keeps the approved HTML prototype as the design reference.

## What the app shows

| Tab | Purpose |
|---|---|
| **Overview** | Portfolio summary: headline figures, indicators (cost mix, share spent on foundations, peak spend and manpower, first value, scope, late results, late dependencies), value vs allocated cost per process with owner, KPIs, milestones and late results, cost per enabler split into capex / people / opex, value for money per enabler, spend per year by enabler group, internal vs partner manpower per year. |
| **Roadmap** | Timeline: results lanes per process (KPIs ●, milestones ◆ at their due date; late ones in red with a line to their ready date) above the enabler Gantt with dependency arrows. Value chain: Infra → Data → People → Digital → Results → Processes. Click a result to highlight the enablers it requires and their foundations, with due vs ready date, allocated cost, value, NPV and ROI. Click an enabler to see what it requires and what it unlocks. |
| **Sensitivity** | Sliders for the config assumptions. Shows the annual cost/value profile against the base case, an NPV tornado (each lever at low/high), value by result, and ready vs due date per result. Time box: uniform extra resources, or back-calculate the resources needed for every result to meet its due date (or a common target date). |
| **Data model** | The proposed lightweight schema. |
| **Glossary** | Definitions of every element (process, result, KPI, milestone, value, enabler, foundation and the computed terms), a concept diagram, and a live tree that follows any result from its foundations through its required enablers to its value, with the cost allocated to it at each step. |

Roadmap filters (process, process owner, result type, enabler group, search) drive the timeline, value chain, results list and the headline figures above them. Everything is visible to every user.

## Lightweight data model

```
process            (id, name, owner)
result             (id, process_id → process (lead), kind [kpi|milestone], name, due [YYYY-MM],
                    unit, baseline, target (KPI only), value_musd, value_driver [oil_price|fte_cost|none])
result_process     (result_id → result, process_id → process, share)   -- optional: result shared by several processes
enabler            (id, enabler_group [people|digital|data|infra], subcategory, name, start_q, end_q,
                    capex_musd, opex_musd_yr, fte_internal, fte_partner, scalability)
result_enabler     (result_id → result, enabler_id → enabler, weight)   -- explicit: result requires enabler
enabler_dependency (enabler_id → enabler, requires_id → enabler)        -- DAG of prerequisites (foundations)
config         (key, label, unit, value, min, max, step, low, high, is_pct, in_sensitivity, description)
```

The three resource types map to columns: money (`capex`, `opex`), manpower and expertise (`fte_internal` for capability built or hired internally, `fte_partner` for allies and contractors).

## Input workbook

All roadmap data comes from one Excel file with one sheet per table: `process`, `result`, `result_process` (optional), `enabler`, `result_enabler`, `enabler_dependency`. Column names go in row 1 and column order doesn't matter. A `config` sheet holds the scenario assumptions: base value, slider range and step, low and high for the tornado, % formatting, and whether each one is used in the tornado. A `README` sheet lists every column with its type, whether it's required, and its default. On Posit Connect, a pin can override the config sheet.

- At startup the workbook is validated and loaded into the database, replacing what was there, so the workbook is the source of truth. To reload it, edit it and restart the app.
- Problems stop the app with one message that lists them all, by sheet, column and row: missing sheets or columns, values that aren't numbers, quarters or months, duplicate IDs, unknown references, dependency cycles. Date conflicts are not errors; they are shown in red.
- The Data model tab can export the current data, or an empty template, in the same format. `write_input_excel()` does the same from R. That export is what to give the authoring agent as its catalogue.

## Calculation logic

- **Enabler cost / year** = capex × (1 + overrun), spread over the enabler's (scenario) duration + FTE cost during the build (partner FTE × (1 + partner premium)) + opex from go-live to the horizon.
- **Extra resources**: the scenario lever `resource_multiplier` (r, 1 = plan) puts more resources on every enabler. Each enabler's `scalability` (s) sets the response: duration × r^(−s), with the start date fixed. s = 0 is rigid (no resources added, no change), s = 1 is linear (half the time at the same total cost), s < 1 gives diminishing returns (total cost rises as r^(1−s)), and s > 1 is better than linear (total cost falls). The same capex and people effort are spread over the shorter build, so yearly expenditure is recalculated. Opex starts at the new go-live. The enabler detail panel shows plan vs scenario spend per year.
- **Time target** (Sensitivity → Time): back-calculate the resources each enabler needs so that **every result meets its own due date** (default), or so that every milestone / result / enabler is done by a common target quarter. Start dates are fixed and a duration depends only on its own resources, so the multiplier has a closed form, r = k^(−1/s), where k is the share of the plan duration allowed. A result's deadline applies to its required enablers and all their prerequisites. Enablers that can't make it (rigid, starting after the deadline, needing less than a quarter, or above the resource limit) are listed. The panel shows dates, late results before → after, extra investment, the change in value and NPV, and each accelerated enabler.
- **Late dependencies** (red arrows: a prerequisite going live after the enabler that needs it) are counted on the scenario schedule, not just the plan. The count appears on the timeline, the detail panel, the Overview and the timing panel.
- **Result ready date** = latest (scenario) go-live across its required enablers and all their prerequisites. A result is **late** when that is after the end of its due month.
- **Date issues** (an end before the start, or a prerequisite going live after the enabler that needs it) don't block loading. They're shown in red on the timeline, value chain and detail panel. Missing references and dependency cycles still stop the app at startup.
- **Shared results**: a result belongs to its lead process (`result.process_id`) unless `result_process` lists it; then its value and allocated cost are split across the listed processes by share (normalised). It appears in every sharing process: lanes (dashed outline outside the lead), value chain, process filter, process detail and Overview. With a process filter, the top bar counts each shared result at the selected processes' share.
- **Result value / year** = `value_musd` × realisation × driver factor (oil price / base or FTE cost / base) × adoption ramp (starts after the adoption lag, linear over the ramp years).
- **Cost allocation**: each enabler's cost is split across the results that require it, by weight; foundation enablers pass their cost to the results of their dependents, so shared infrastructure is spread rather than double-counted. A milestone with no value still carries its share of cost.
- **Portfolio**: NPV at the discount rate, ROI = (value − cost) / cost, payback = first year cumulative net ≥ 0.

## Shiny app (R package `dtroadmap`)

```
R/
  data_access.R          all data interaction: Excel input (read, validate, export) and DB (DuckDB in dev, RSQLite fallback, DBI for SQL Server/Postgres later)
  config.R               config from the workbook's config sheet (or a pin on Posit Connect), validated
  fct_graph.R            dependency graph, validation, weights, cost allocation, ready dates
  fct_model.R            cost_profile(), value_profile(), run_model(), portfolio(), tornado()
  fct_payload.R          data sent to the browser canvas
  fct_detail.R           detail panel (result / enabler / process / portfolio)
  fct_charts.R           sensitivity chart data (tested) + echarts4r rendering, summary strip
  fct_overview.R         overview tables and indicators (tested) + charts
  fct_timing.R           timing panel: dates, late dependencies, cost of acceleration
  fct_glossary.R         glossary content and the foundation-to-value tree (layout tested, SVG)
  utils.R                formatting helpers
  mod_overview_*, mod_roadmap_*, mod_sensitivity_*, mod_datamodel_*  (ui / server per tab)
  app_ui.R, app_server.R, run_app.R
inst/app/www/            styles.css, roadmap.js (timeline, value chain, highlighting, client-side)
inst/extdata/            roadmap_input.xlsx (sample data: one sheet per table + config), roadmap_input_template.xlsx
inst/sql/schema.sql      DDL
tests/testthat/          unit tests for every function layer
docs/data_authoring_guide.md  how AI agents must format per-process data
app.R                    Posit Connect entry point
```

### Run

```r
# install.packages(c("shiny", "DBI", "duckdb", "echarts4r", "jsonlite", "readxl", "writexl", "pins", "testthat", "pkgload"))
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

- Data, graph and config load once per R process and are shared by all sessions (`app_context()`).
- The roadmap canvas renders in the browser: clicks, highlighting, hover and view switching never call R. R only sends a new payload when filters, audience or assumptions change.
- Inputs are debounced; the model is vectorised and runs in milliseconds for this size. When the portfolio grows, the cost/value profiles can move to SQL views in DuckDB, or to a plumber API shared with other tools.
