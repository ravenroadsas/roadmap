# Digital Transformation Roadmap 2026–2029

Interactive roadmap that links **enablers** (investments) to **processes**, **KPIs** and **value**, with a sensitivity analysis on the main assumptions.

> **Status: mockup for review.** `mockup/index.html` is a self-contained HTML prototype with sample data (oil & gas). Open it in a browser. It shows the UX and the calculation logic before we build the Shiny app.

## What the mockup shows

| Tab | Purpose |
|---|---|
| **Roadmap** | Timeline (Gantt by enabler group, with milestones and dependency arrows) or Value chain view (Infra → Data → People → Digital → Process → KPI). Click a KPI to highlight its direct enablers and the foundations they need, with allocated cost, value, NPV and ROI. Click an enabler to see what it requires and what it unlocks. |
| **Sensitivity** | Sliders for the config assumptions. Shows the annual cost/value profile against the base case, an NPV tornado (each lever at low/high), and value by KPI. |
| **Data model** | The proposed lightweight schema. |

There is a global **Public / Management** switch: `private` KPIs and milestones are hidden in Public mode.

## Lightweight data model

```
process        (id, name, owner, visibility)
kpi            (id, process_id → process, name, unit, baseline, target, target_year,
                value_musd, value_driver [oil_price|labor|none], visibility)
enabler        (id, group [people|digital|data|infra], subcategory, name, start_q, end_q,
                capex_musd, opex_musd_yr, fte_internal, fte_partner, visibility)
enabler_link   (enabler_id → enabler, kpi_id → kpi, weight)      -- enabler → KPI → process
enabler_dependency (enabler_id → enabler, requires_id → enabler) -- DAG of prerequisites
milestone      (id, date, name, enabler_id → enabler, visibility)
config (pin)   (key, value, min, max, low, high, unit)
```

The three resource types map to columns: money (`capex`, `opex`), manpower and expertise (`fte_internal` for capability built or hired internally, `fte_partner` for allies and contractors).

## Calculation logic

- **Enabler cost / year** = capex × (1 + overrun), spread over the enabler's duration + FTE cost during the build (partner FTE × (1 + partner premium)) + opex from go-live to the horizon.
- **KPI ready date** = latest end date across its direct enablers and all their prerequisites.
- **KPI value / year** = `value_musd` × realisation × driver factor (oil price / base or FTE cost / base) × adoption ramp (starts after the adoption lag, linear over the ramp years).
- **Cost allocation**: each direct enabler is split across KPIs by link weight; foundation enablers pass their cost to the KPIs of their dependents, so shared infrastructure is spread rather than double-counted.
- **Portfolio**: NPV at the discount rate, ROI = (value − cost) / cost, payback = first year cumulative net ≥ 0.

## Planned Shiny build (after approval)

- R package (`golem`-style): functions in `R/fct_*.R`, one `mod_<tab>_ui.R` / `mod_<tab>_server.R` per tab, separate `inst/app/www/styles.css`.
- Data access isolated in `R/data_access.R` (duckdb in development, swappable to SQL Server/Postgres later).
- Config on a `pins` board (CSV fallback); secrets only in environment variables.
- `echarts4r` for sensitivity charts. The timeline and dependency graph will be a small htmlwidget or JS module so highlighting runs client-side.
- Pure calculation functions (`cost_profile()`, `value_profile()`, `allocate_cost()`, `portfolio()`) tested with `testthat`.
- Posit Connect: `session$user` / groups decide the Public vs Management view.
