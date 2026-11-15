---
name: transformation-roadmap
description: Build or extend a digital transformation roadmap as structured data (processes, results, concepts, enablers, dependencies) in the roadmap workbook format. Use when asked to plan a transformation, turn process interviews or documents into roadmap rows, estimate value and cost of transformation initiatives, identify the enablers (people, digital, data, infrastructure) a result needs, or check a roadmap workbook for consistency.
---

# Digital transformation roadmap

You help build a digital transformation roadmap. A roadmap here is not a slide: it is a small, connected data model that a dashboard reads to show **what** is built, **when**, for **what value**, and **what depends on what**. Your job is to reason from the evidence about one business process at a time and express the result as rows in the exact format below, with the reasoning kept in notes.

> **Avoid bias.** Derive every result, enabler and number from the material you are given about the organisation and its processes. The example at the end shows the *format*, not the content: do not reuse its names, results, values or dates. Do not assume an industry, a technology vendor or a "standard" list of initiatives. If the evidence is thin, say so and ask, rather than filling gaps with generic transformation programmes.

---

## 1. The logic

**Enablers make results possible. Results generate value for processes.**

```
CONCEPT ─groups─► ENABLER ──makes possible (weight)──► RESULT ──value $M/yr──► PROCESS(es)
 (FTE)              │ capex, opex, start → go-live        │ due date, optional measure
                    └ requires other enablers (foundations)
```

| Element | What it is | The question it answers |
|---|---|---|
| **Process** | A business process being transformed. Its owner (a role) is accountable for the results it leads. | Where does the value land, who owns it? |
| **Result** | A tangible outcome with a **due date** and a **value** ($M per year once achieved, or 0). Optionally a **measure**: unit, baseline → target. Without a measure it is a step change: achieved or not. | What do we commit to, by when, for what value? |
| **Enabler** | Something built or put in place: a solution, data, infrastructure, or a people/change initiative. It has capex, opex, a start and a go-live. The only element that consumes money. | What do we build, when, for how much? |
| **Concept** | Groups related enablers (group › subgroup › concept › enabler) and carries their **people** (FTE). | Who works on it? |
| **Foundation** | An enabler that other enablers need first. Not listed by the result directly; reached through dependencies. | What has to exist first? |
| **Requirement** | A result requires an enabler, with a relative **weight**. | How much does this enabler contribute to the result? |
| **Dependency** | An enabler needs another to be live before it can go live. | In what order must things be built? |
| **Shared result** | A result split across several processes by share; one lead process stays accountable. | Who else benefits and carries the work? |

### 1.1 What the dashboard computes from your rows

You do not compute these, but your numbers drive them, so keep them consistent:

- **Ready date** of a result = the latest go-live among its required enablers **and all their prerequisites**. If that is after the end of the due month, the result is **late** (shown in red). Late results are allowed: they are a finding, not an error.
- **Late dependency**: a prerequisite that goes live after the enabler that needs it (red arrow). Also allowed, also a finding.
- **Value per year** = `value_musd` × realisation factor × driver factor (e.g. price or labour cost vs base) × adoption ramp (linear from the ready date to full value over the adoption time).
- **Cost per year** = capex spread evenly over the build + concept people during the build (partner staff at a premium) + opex from go-live to the horizon, all × a cost multiplier lever.
- **People**: a concept's FTE are spread over its enablers in proportion to their build duration, so total effort (FTE × build window) is preserved.
- **Cost attribution**: an enabler's cost is split across the results that require it, by weight; foundations pass their cost on to the results built on them.
- **Scope**: selecting a subset of processes counts the value of their results (at their share) and the cost of only the enablers those results need. `per_process` enablers scale with the processes in scope as (in scope / served) ^ scalability.
- **Acceleration**: more resources shorten each enabler as duration × r^(−scalability), start fixed; total effort scales by r^(1 − scalability). The dashboard can back-solve the resources needed for every result to meet its due date.
- **Scenario levers**: adoption time, commodity price, cost multiplier, acceleration. Fixed assumptions (realisation, FTE cost, partner premium, discount rate, horizon) live in the `config` sheet, maintained by the roadmap team.

---

## 2. The four enabler groups

Every enabler belongs to exactly one group, through its concept. A credible roadmap for a result usually touches more than one group; a result that needs only a digital solution is a warning sign.

### `people` — people, change and adoption
Skills and training, change management and adoption, organisation design and new roles, ways of working and standards, governance of decisions.
- Every digital solution needs a people enabler next to it (training, new roles, change), unless an existing one already covers it.
- Often `per_process`: its cost grows with the teams, sites or processes it covers.
- Usually rigid in time: behaviour change cannot be bought faster (scalability 0–0.5).

### `digital` — digital solutions
Applications and workflows, automation, analytics and AI/ML models, AI agents, robotics, digital twins, remote operations, decision support.
- Should name what humans keep doing and what the solution, agent or robot does.
- Almost always needs `data` foundations; agents and AI need trusted, integrated data first.
- Scalability varies: modular apps and automation scale well (≈ 0.9–1.2); AI in operations is slower (≈ 0.5–0.8) because of testing and trust.

### `data` — data
Data platform, integration of sources, master and reference data, data quality, governance and ownership, semantic models.
- Typically a **foundation** shared by many processes: create it once and reuse it.
- Limited by data availability and owner agreement (scalability ≈ 0.4–0.8).

### `infra` — infrastructure
Cloud and hosting, networks and connectivity, devices and sensors, operational technology, cybersecurity, real-time data acquisition.
- Usually the deepest foundations, with procurement and installation lead times (scalability ≈ 0.3–0.6; hardware and certification toward the low end).
- Shared across processes; cost is usually `fixed`.

### Typical chain (shape, not content)
```
infra ──► data ──► digital ──► RESULT
                     ▲
           people ───┘   (adoption next to every solution)
```

---

## 3. Data structure

One Excel workbook, **one sheet per table**, column names in row 1 (lower case). A `README` sheet documents the columns; a `config` sheet holds assumptions (read only: never output config rows).

General rules:
- Exactly the listed column names; order does not matter; extra columns are ignored.
- One row per record, no merged cells. Numbers are plain numbers: no units, `$` or thousands separators.
- Quarters are text `YYYYQn` (e.g. `2027Q3`); months are text `YYYY-MM`.
- IDs are text, case-sensitive, no spaces, never reused or renumbered.
- Optional columns may be empty and take their default.

### 3.1 `process`
| column | type | rules |
|---|---|---|
| `id` | text | Given to you. Do not invent process IDs. |
| `name` | text | Process name |
| `owner` | text | Accountable **role**, never a person's name; spell it the same way everywhere |

### 3.2 `result`
| column | type | rules |
|---|---|---|
| `id` | text | e.g. `R-<process>-<nn>`. Unique. |
| `process_id` | text | The **lead** process (must exist in `process`) |
| `name` | text | The tangible outcome, ≤ 50 characters |
| `due` | month | `YYYY-MM`, the business commitment (not derived from enabler dates) |
| `value_musd` | number | **Annual** value in $M once achieved, before realisation; 0 if no value of its own |
| `value_driver` | text | `oil_price` (value moves with the commodity price lever), `fte_cost` (saved people time), or `none` (fixed saving). Default `none`. |
| `unit` | text | Optional measure unit |
| `baseline` | number | Optional: current value. Give both baseline and target, or neither. |
| `target` | number | Optional: value when achieved. Direction (up or down) is implied by target vs baseline. |

### 3.3 `result_process` (optional: shared results)
| column | type | rules |
|---|---|---|
| `result_id` | text | Must exist in `result` |
| `process_id` | text | A sharing process. **List the lead process too.** |
| `share` | number | Relative share of value and cost, normalised per result (`2,1,1` = 50/25/25). Default 1. |

### 3.4 `concept`
| column | type | rules |
|---|---|---|
| `id` | text | e.g. `C-<short name>`. Unique. |
| `name` | text | Concept name |
| `enabler_group` | text | `people`, `digital`, `data` or `infra` |
| `subgroup` | text | Short free text (e.g. a capability family) |
| `fte_internal` | number | Average internal FTE over the concept's build window (first start → last go-live) |
| `fte_partner` | number | Average partner / vendor / contractor FTE over the same window |

### 3.5 `enabler`
| column | type | rules |
|---|---|---|
| `id` | text | `E-<process>-<nn>` (process-specific) or `E-X-<nn>` (cross-process). Unique. |
| `concept_id` | text | Must exist in `concept` |
| `name` | text | The thing being built, ≤ 40 characters |
| `start_q` | quarter | `YYYYQn` |
| `end_q` | quarter | Go-live quarter (inclusive). An end before the start loads but is flagged. |
| `capex_musd` | number | One-off investment, $M (licences, hardware, vendor implementation) |
| `opex_musd_yr` | number | Running cost per year after go-live, $M |
| `cost_basis` | text | `fixed` (default) or `per_process` (cost grows with the processes served) |
| `scalability` | number 0–2 | 0 rigid, 1 linear, > 1 better than linear (see 3.8). Default 0. |

### 3.6 `result_enabler` (requirements)
| column | type | rules |
|---|---|---|
| `result_id` | text | Must exist in `result` |
| `enabler_id` | text | Must exist in `enabler` |
| `weight` | number | Relative contribution, normalised per result; prefer weights summing to 1. Default 1. |

### 3.7 `enabler_dependency` (foundations)
| column | type | rules |
|---|---|---|
| `enabler_id` | text | The enabler that needs something |
| `requires_id` | text | The enabler it needs first |

No cycles (A needs B needs A, or longer loops). Only direct prerequisites: if A needs B and B needs C, do not add A needs C.

### 3.8 Scalability guide
`duration with more resources = plan duration × r^(−s)`, start fixed; total effort × r^(1 − s).

| s | meaning | double the resources → |
|---|---|---|
| 0 | Rigid (regulation, lead times, behaviour change) | same duration, same cost |
| 0.3–0.7 | Diminishing returns (coordination, learning, sequential steps) | 19–38% shorter, cost +23% to +62% |
| 1 | Linear (work splits cleanly) | half the time, same cost |
| 1.1–1.5 | Better than linear (independent packages, economies of scale). Rare: justify. | 53–65% shorter, cost −7% to −29% |

For `per_process` enablers, scalability also sets how cost shrinks when fewer processes are in scope.

---

## 4. How to build the roadmap

Work **one process at a time**, and always against the current catalogue (the latest exported workbook) so shared items are reused, not duplicated.

1. **Understand the process.** From the material given: how the work is done today, where time, cost and risk go, and how humans, software, agents and machines should split the work afterwards. Note the evidence for each pain point.
2. **Define 2–6 results.** Mix measured improvements (with baseline → target) and the step changes management will check. Each must be observable and owned by the process. Set `due` from the business commitment.
3. **Value each result.** `value_musd ≈ Δ(target − baseline) × volume × unit value`, per year, at full adoption. Show the calculation in the notes. **Count value once**: if one result is a step toward another, put the value on one of them (0 on the other) or split it explicitly.
4. **Find the enablers per result**, group by group: which *digital* solution delivers it, which *data* it needs, which *infra* that data needs, and which *people* change makes it stick. List only what the result **directly** needs in `result_enabler`; reach deeper foundations through `enabler_dependency`.
5. **Reuse before creating.** Search the catalogue for an existing enabler or concept that covers the need. Reuse its ID. New cross-process foundations get `E-X-<nn>`, written once.
6. **Group into concepts and plan people.** Put related enablers under one concept; estimate average internal and partner FTE over the concept's build window. Do not double count: vendor implementation goes in capex, partner people time in `fte_partner`.
7. **Schedule and cost.** Builds usually take 2–8 quarters; split anything longer into phases linked by a dependency. Prerequisites should go live on or before what needs them. Estimate capex, opex, cost basis and scalability, each traceable to a note.
8. **Check the chain.** For each result, walk from value down to the deepest foundation: is anything missing, circular, or obviously late? Keep real dates even if they make a result late, and explain the gap.
9. **Write the output** (section 5) and run the checklist (section 6).

### Anti-patterns
- Copying a generic "transformation programme" instead of deriving enablers from the process evidence.
- A result that is really an activity ("deploy tool X"): results are outcomes; tools are enablers.
- Digital enablers with no data foundation or no people/adoption enabler.
- The same benefit counted in two results, or the same cost in capex and partner FTE.
- Listing foundations directly on the result (inflates weights and hides the chain).
- Adjusting due dates to hide lateness.
- Inventing process IDs, or reusing an ID for a different item.

---

## 5. Output format

Output **only new or changed rows**, never the whole workbook. Changed rows repeat the full row with the same ID.

- If you can create files: an `.xlsx` with the same sheet names and columns; omit sheets with no rows.
- Otherwise: one CSV block per sheet, titled with the sheet name; quote text containing commas.

Then the **notes**, in Markdown:

- **Process summary** — 3–5 lines: today, and the human / digital / agent / machine split afterwards.
- **Results** — why these, which carry a measure, how step changes relate to measured improvements.
- **Value estimates** — one line per valued result with the calculation.
- **Cost estimates** — basis for each capex, opex, concept FTE and every `per_process` choice.
- **Scalability** — any value outside the typical range, and every value above 1, justified.
- **Assumptions and sources** — what was given, what was assumed, confidence (high / medium / low).
- **Reused and new shared enablers** — IDs reused from the catalogue; new `E-X` rows and who else will use them.
- **Changed rows** — existing IDs output again, what changed and why.
- **Late results and date conflicts** — each one, and why the dates are still right.
- **Open questions** — for the process owner.

---

## 6. Checklist

- [ ] Column names exactly as listed; numbers without units or symbols; dates as `YYYYQn` / `YYYY-MM`.
- [ ] Every reference (`process_id`, `result_id`, `enabler_id`, `requires_id`, `concept_id`) points to a row in the output or the catalogue.
- [ ] Every result has a due month and at least one required enabler; a measure has both baseline and target.
- [ ] Every new enabler is required by a result or is a prerequisite of one that is; it has a concept, a cost basis and a scalability.
- [ ] Every digital enabler has data foundations and a people/adoption enabler next to it.
- [ ] Value counted once; shared results list the lead process in `result_process` with explained shares.
- [ ] No dependency cycles; only direct prerequisites listed.
- [ ] `value_driver` is `oil_price`, `fte_cost` or `none`; `enabler_group` is `people`, `digital`, `data` or `infra`; `cost_basis` is `fixed` or `per_process`.
- [ ] Every number traces to a line in the notes; nothing was taken from the example below.

---

## 7. Example (format only — fictitious)

An abstract process to show how the sheets connect. Names, values and dates are placeholders: **do not reuse them**.

```csv
# process
id,name,owner
P01,Process A,Head of Process A
```

```csv
# result
id,process_id,name,due,value_musd,value_driver,unit,baseline,target
R-P01-01,P01,Cycle time of the core activity,2028-06,2.0,fte_cost,days,20,8
R-P01-02,P01,Single source of truth in use,2027-12,0,none,,,
```

```csv
# concept
id,name,enabler_group,subgroup,fte_internal,fte_partner
C-ADOPT,Adoption programme,people,Change management,1,0.5
C-FLOW,Workflow solution,digital,Workflows,2,3
C-DATA,Data integration,data,Integration,1.5,2
C-CLOUD,Hosting,infra,Cloud,0.5,1
```

```csv
# enabler
id,concept_id,name,start_q,end_q,capex_musd,opex_musd_yr,cost_basis,scalability
E-X-01,C-CLOUD,Hosting environment,2026Q3,2027Q1,1.0,0.3,fixed,0.9
E-X-02,C-DATA,Integrated source data,2026Q4,2027Q4,1.5,0.4,fixed,0.6
E-P01-01,C-FLOW,Workflow and decision support,2027Q2,2028Q1,2.5,0.5,fixed,0.8
E-P01-02,C-ADOPT,Training and new roles,2027Q4,2028Q2,0.4,0,per_process,0.3
```

```csv
# result_enabler
result_id,enabler_id,weight
R-P01-01,E-P01-01,0.7
R-P01-01,E-P01-02,0.3
R-P01-02,E-X-02,1
```

```csv
# enabler_dependency
enabler_id,requires_id
E-P01-01,E-X-02
E-X-02,E-X-01
```

What the dashboard derives:
```
VALUE  $2.0M/yr at full adoption (scaled by FTE cost) → Process A
└── RESULT  Cycle time of the core activity · 20 → 8 days · due 2028-06 · ready 2028Q2 (on time)
    ├── 70%  Workflow and decision support  [required · digital · live 2028Q1]
    │   └── requires  Integrated source data  [foundation · data · live 2027Q4]
    │       └── requires  Hosting environment  [foundation · infra · live 2027Q1]
    └── 30%  Training and new roles  [required · people · live 2028Q2]
```

Notes excerpt (pattern to follow):
- R-P01-01 value: (20 − 8) days saved × N cases/yr × hours per case-day × loaded hourly cost ≈ $2.0M/yr — show the actual inputs you were given.
- R-P01-02 is a step toward R-P01-01, so its value is 0.
- E-P01-02 is `per_process`: training scales with the teams covered; scalability 0.3 because learning takes time.
- E-X-02 is a cross-process foundation: other processes are expected to reuse it.
