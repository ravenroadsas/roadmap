# Transformation Roadmap 2026–2029 · v3 · digital maturity

**Investment builds enablers. Enablers and each process's digital maturity target make milestones possible. Milestones move metrics up their impact curve. Metrics create value.**

v3 (branch `claude/roadmap-v3-maturity`) builds on v2 (`claude/roadmap-v2`): every process has a current and a target digital maturity, from **M1 Manual** to **M5 Adaptive**. Changing a target changes which milestones are pursued, which enablers must be built, and how much of each metric's impact is reached.

```
                 PROCESSES (current → target M)
                          │
INVESTMENT → ENABLERS ────┴──► MILESTONES ──► METRICS ──impact curve──► VALUE
             (level M,          (level M,     (baseline → target at M5,
              in concepts)       due date)     % of impact vs M)
```

| Level | Name | Key trait |
|---|---|---|
| M1 | Manual | Dependence on human intervention |
| M2 | Assisted | Digital support to execution |
| M3 | Integrated | End-to-end integration and traceability |
| M4 | Automated | Automation and data-driven decisions |
| M5 | Adaptive | Anticipation, adaptability and continuous optimisation |

## Views

| View | What it answers |
|---|---|
| **Roadmap** | What, when, for what value. Chronogram: per process, its maturity over time (a strip from today's level to the target) and its milestones (numbered by level, red when late), above the enablers by group › concept. Value chain: Foundations → Enablers → Milestones → Metrics → Processes. Click anything to see what it depends on. |
| **Scenario** | What if: the **maturity target of each process** (M1–M5), adoption time, oil price, cost multiplier, acceleration. Headline and cumulative net value against the base case; by process, the change in milestones, value, cost and NPV; which enablers come in or drop out. |
| **Frontier** | Which combination of targets is worth pursuing. Every combination is evaluated (each process from its current level to M5) and plotted as investment vs NPV; the efficient frontier holds the combinations with the highest NPV for their investment (ROI in the tooltip and table). Pick one and apply it to the Scenario view. |
| **Method** | How it works: the logic diagram, the M1–M5 levels and how to assess a process, the impact curves, definitions, and the data workbook (download, template). |

## Calculation

- **Scope**: a milestone is pursued when its process's target is at or above the milestone's level. Unticked processes in the Roadmap scope stay at their current level.
- **Investment**: the enablers that the pursued milestones require, with their foundations. `per_process` enablers scale with the processes that need them: (needing / served) ^ scalability.
- **Enabler level**: the maturity an enabler enables. It is checked, not used to add cost: an enabler of a higher level than a milestone that requires it is flagged in the Method view (level checks).
- **Ready date**: a milestone is ready when its last enabler or foundation goes live; late when after the end of its due month. A process reaches level L when its milestones up to L are ready (a level with no milestone of its own is reached with the next one up).
- **Metric value**: a metric climbs its impact curve through the levels of the milestones linked to it. Each step adds (curve(L) − curve(previous)) / (curve(M5) − curve(current)) of `value_musd`, ramped linearly over the adoption time from the date the step is reached, × realisation × driver (oil price or FTE cost vs base). `value_musd` is the annual value of going from the current level to M5.
- **Impact curves** (sheet `curve`, % of impact at M1…M5; editable): *Diminishing returns* 0-45-75-92-100 (production), *Threshold* 0-5-15-55-100 (man-hours), *Linear*, *S-curve* 0-10-45-85-100 (cycle times, NPT).
- **Cost / year**: capex over the build, concept people during the build (partner at a premium), opex from go-live; all × cost multiplier.
- **Acceleration**: duration × r^(−scalability), start fixed; effort × r^(1−scalability). The solver back-calculates r per enabler for the milestones in scope.
- **Frontier**: exact enumeration with the same formulas, on plan resources and the Scenario levers. Costs are precomputed per enabler and switched on by the lowest milestone level that needs them; a metric's value is precomputed for every combination of the few processes whose milestones move it. 65,536 combinations take about half a second.

## Data

One Excel workbook (`ROADMAP_INPUT_XLSX`, default `inst/extdata/roadmap_input.xlsx`), one sheet per table. Levels are written `M1`…`M5` (a plain number is accepted).

```
process            (id, name, owner, current_level, target_level)
milestone          (id, process_id, name, due [YYYY-MM], level)
metric             (id, process_id, name, unit, baseline, target [at M5], value_musd [current → M5],
                    value_driver, curve_id)
metric_milestone   (metric_id, milestone_id)                     -- several milestones can move one metric
curve              (id, name, m1, m2, m3, m4, m5 [% of impact], description)   -- optional: defaults
concept            (id, name, enabler_group [people|digital|data|infra], subgroup, fte_internal, fte_partner)
enabler            (id, concept_id, name, level, start_q, end_q, capex_musd, opex_musd_yr,
                    cost_basis [fixed|per_process], scalability)
milestone_enabler  (milestone_id, enabler_id, weight)            -- milestone requires enabler
enabler_dependency (enabler_id, requires_id)                     -- prerequisites (foundations)
config             (key, label, unit, value, min, max, step, …, is_pct, in_sensitivity = lever, description)
levels             (reference: M1–M5 names and descriptions; not read)
```

Your roadmap `data/roadmap_input_v1.xlsx` is converted to v3. **Amber cells are proposals to validate**:
- process `current_level` (M2 for all) and `target_level` (the highest milestone level);
- enabler `level`, proposed from what each enabler builds (e.g. data governance M2, integrated workflows and ROC M3, agentic AI M4, iROC and scenario optimisation M5);
- results with a measure became **metrics** with a proposed curve (production → diminishing returns, headcount ratios → threshold, cycle times / NPT / CoS → S-curve); `target` and `value_musd` now mean *at M5*;
- each metric's enablers were grouped by level into **milestones** of its process (existing milestones of the same process and level were reused: e.g. *200 wells per engineer* at M4, *250 wells per engineer* at M5); generated milestones are named "*metric: level (Mn)*" and take the metric's due date. The `source` column says where each row comes from.

The sample workbook was converted the same way; its shared result (unplanned downtime) now belongs to its lead process and is moved by the predictive-maintenance milestone of asset maintenance.

## What changed from v2

- **Digital maturity** on processes (current, target), milestones and enablers; the target is a scenario variable.
- **Milestones and metrics are separate again**: milestones are the step changes (level, due date, enablers); metrics carry the value and an **impact curve**. `result`, `result_enabler` and `result_process` are replaced by `milestone`, `metric`, `metric_milestone`, `milestone_enabler` and `curve`.
- **Frontier tab** and **Method** (formerly Model) with the maturity framework.

## Editor

> Not yet updated to the v3 data model (planned after the dashboard iterations); on this branch it still expects v2 workbooks.

A companion app to build and edit the roadmap without touching Excel cell by cell. It works on a **copy**: import, edit, export. It never writes the workbook the roadmap app reads.

| Step | What you do |
|---|---|
| **1 · Start** | Import a workbook (filled template, agent output, previous export), open a copy of the app's current workbook, or start empty. Download the empty template. Import problems are listed but don't block editing. |
| **2 · Items** | Add, edit, duplicate and delete processes, results, concepts and enablers: dates, value, measure, capex, opex, cost basis, scalability, FTE. Renaming an ID updates every reference; deleting removes the item's connections. |
| **3 · Connections** | Drag one box onto another. Enabler → result: the result requires it. Enabler → enabler: the second needs the first (loops are refused, with the path). Result → process: share the result. Enabler → concept: move it. Click a box to focus its links, click a line to set its weight or share, or remove it (Delete). |
| **4 · Check & export** | Problems that would stop the roadmap app, then the headline and warnings (late results, late foundations) from the same model. Download the workbook (README, tables, config). |

Undo (Ctrl+Z) covers every change; the header shows unsaved changes and the browser warns before leaving. Each session has its own copy, so a few editors can work at once; whoever publishes replaces the app's workbook with an export.

```r
shiny::runApp("editor_app.R")                  # local
# Posit Connect: deploy the repository again (app.R) and set ROADMAP_APP=editor
```

## Code

```
R/
  data_access.R      Excel input (read, validate, export) and database
  config.R           config sheet (levers and fixed assumptions)
  fct_graph.R        dependency graph, metric links, validation, date and level checks
  fct_model.R        concepts → enabler FTE, schedule, maturity scope, metric curves, cost, value, solver
  fct_frontier.R     enumeration of maturity targets, efficient frontier, chart
  fct_payload.R      data for the browser canvas
  fct_detail.R       detail panel
  fct_views.R        headline figures, SVG charts, logic diagram, levels and curves
  fct_timing.R       scenario vs base
  mod_roadmap_*, mod_scenario_*, mod_frontier_*, mod_model_*   one ui / server pair per view
  run_editor.R       editor app: shell, shared state, undo
  editor_data.R      editor operations: items, connections, board payload, import
  fct_editor_views.R editor lists, relations, link descriptions, model check
  mod_edit_start_*, mod_edit_items_*, mod_edit_board_*, mod_edit_export_*   editor steps
inst/app/www/        styles.css, roadmap.js (chronogram, value chain, client-side), frontier.js
inst/editor/www/     editor.css, editor.js (drag-to-connect board)
app.R, editor_app.R  launch files (roadmap app, editor)
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
| `ROADMAP_APP` | `editor` makes `app.R` serve the editor (second Connect deployment) | roadmap app |

On Posit Connect the signed-in user is shown in the header; there is no access split inside the app (control access with the Connect content settings).

### Performance

Data, graph and config load once per R process and are shared by sessions. The canvas renders in the browser (clicks, highlighting, hover and view switching never call R); R sends a new payload only when the scope, the search or the scenario (levers, maturity targets) changes. The frontier is cached per set of levers.
