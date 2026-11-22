---
name: transformation-roadmap
description: Build or extend a digital transformation roadmap as structured data (processes with digital maturity M1-M5, milestones, metrics with impact curves, concepts, enablers, dependencies) in the roadmap workbook format. Use when asked to plan a transformation, assess a process's digital maturity, turn process interviews or documents into roadmap rows, estimate value and cost of transformation initiatives, identify the enablers (people, digital, data, infrastructure) a milestone needs, or check a roadmap workbook for consistency.
---

# Digital transformation roadmap

You help build a digital transformation roadmap. A roadmap here is not a slide: it is a small, connected data model that a dashboard reads to show **what** is built, **when**, for **what value**, **what depends on what**, and which **digital maturity** targets are worth pursuing. Your job is to reason from the evidence about one business process at a time and express the result as rows in the exact format below, with the reasoning kept in notes.

> **Avoid bias.** Derive every maturity level, milestone, metric, enabler and number from the material you are given about the organisation and its processes. The example at the end shows the *format*, not the content: do not reuse its names, milestones, metrics, values or dates. Do not assume an industry, a technology vendor or a "standard" list of initiatives. If the evidence is thin, say so and ask, rather than filling gaps with generic transformation programmes.

---

## 1. The logic

**Investment builds enablers. Enablers and each process's digital maturity target make milestones possible. Milestones move metrics up their impact curve. Metrics create value.**

```
                 PROCESS (current → target maturity, M1..M5)
                          │
INVESTMENT → ENABLER ─────┴──► MILESTONE ──► METRIC ──impact curve──► VALUE $M/yr
              (level M,          (level M,     (baseline today → target at M5,
               in a concept)      due date)     % of impact reached vs M)
```

| Element | What it is | The question it answers |
|---|---|---|
| **Process** | A business process being transformed, with a **current** and a **target** digital maturity. Its owner (a role) is accountable. | How digital is it today, and how far should it go? |
| **Maturity level** | M1 Manual · M2 Assisted · M3 Integrated · M4 Automated · M5 Adaptive (see 1.2). | What capability is in place? |
| **Milestone** | A step change on the way to a level, with a **level** and a **due date**. Pursued when its process's target is at or above its level. | What must happen, by when, to reach that level? |
| **Enabler** | Something built: a solution, data, infrastructure, or a people/change initiative. Capex, opex, start, go-live, and the **level it enables**. The only element that consumes money. | What do we build, when, for how much? |
| **Concept** | Groups related enablers (group › subgroup › concept › enabler) and carries their **people** (FTE). | Who works on it? |
| **Foundation** | An enabler other enablers need first. | What has to exist first? |
| **Metric** | A measured outcome (baseline today → target at M5) with a **value** ($M/yr from the current level to M5) and an **impact curve**. Moved by one or more milestones. | What improves, and how much is it worth? |
| **Impact curve** | % of a metric's impact reached at each level (M1…M5). Concave when most gain comes early, threshold when it comes only with automation. | How does value respond to maturity? |

### 1.1 What the dashboard computes from your rows

You do not compute these, but your numbers drive them, so keep them consistent:

- **Scope**: milestones at or below each process's target are pursued; the enablers they require, with their foundations, are the investment. `per_process` enablers scale as (processes needing / served) ^ scalability.
- **Ready date** of a milestone = the latest go-live among its required enablers and their prerequisites; **late** if after the end of the due month (allowed: a finding, not an error). A process reaches level L when its milestones up to L are ready.
- **Metric value**: as its linked milestones become ready, the metric climbs its curve from the current level. Each step adds (curve(L) − curve(previous)) / (curve(M5) − curve(current)) of its value, ramped linearly over the adoption time, × realisation × driver factor (price or labour cost vs base).
- **Cost per year** = capex over the build + concept people during the build (partner at a premium) + opex from go-live, × a cost multiplier lever.
- **Acceleration**: duration × r^(−scalability), start fixed; effort × r^(1 − scalability).
- **Frontier**: every combination of maturity targets is evaluated; the efficient frontier shows the combinations with the best NPV for their investment.
- **Level check**: an enabler of a higher level than a milestone that requires it is flagged.

### 1.2 Maturity levels

| Level | Key trait | Looks like |
|---|---|---|
| **M1 Manual** | Dependence on human intervention | Manual activities, scattered information, isolated tools; decisions on people's judgement. |
| **M2 Assisted** | Digital support to execution | Tools to execute, record and follow up; decisions stay human; manual steps between systems. |
| **M3 Integrated** | End-to-end integration and traceability | Standard workflows connected end to end; structured, traceable data exchange; integrated performance view. |
| **M4 Automated** | Automation and data-driven decisions | Workflows, rules, algorithms and models execute, validate, detect deviations, recommend or decide; people handle exceptions. |
| **M5 Adaptive** | Anticipation and continuous optimisation | Real-time data, advanced analytics and AI anticipate and adjust execution, learning continuously within set limits. |

Assess the current level on six dimensions — digitalisation of activities, integration and architecture, data management and quality, automation, intelligence and decisions, adaptability and optimisation — and set the level the evidence supports on most of them. Frameworks behind the scale: BPMM (OMG), acatech Industrie 4.0 Maturity Index, CMMI, Deloitte Digital and AI Maturity.

---

## 2. The four enabler groups

Every enabler belongs to exactly one group, through its concept. A credible roadmap for a milestone usually touches more than one group; a milestone that needs only a digital solution is a warning sign. Each enabler also has the **maturity level it enables**; typical levels are given per group.

### `people` — people, change and adoption
Skills and training, change management and adoption, organisation design and new roles, ways of working and standards, governance of decisions.
- Every digital solution needs a people enabler next to it (training, new roles, change), unless an existing one already covers it.
- Often `per_process`: its cost grows with the teams, sites or processes it covers.
- Usually rigid in time: behaviour change cannot be bought faster (scalability 0–0.5).
- Levels: standards and skills M2; integrated teams and process ownership M3; new roles (from doer to supervisor of agents) M4.

### `digital` — digital solutions
Applications and workflows, automation, analytics and AI/ML models, AI agents, robotics, digital twins, remote operations, decision support.
- Should name what humans keep doing and what the solution, agent or robot does.
- Almost always needs `data` foundations; agents and AI need trusted, integrated data first.
- Scalability varies: modular apps and automation scale well (≈ 0.9–1.2); AI in operations is slower (≈ 0.5–0.8) because of testing and trust.
- Levels: digital tools and records M2; standard connected workflows, remote operations M3; rules, models, RPA, agents M4; predictive / prescriptive optimisation and autonomous adjustment M5.

### `data` — data
Data platform, integration of sources, master and reference data, data quality, governance and ownership, semantic models.
- Typically a **foundation** shared by many processes: create it once and reuse it.
- Limited by data availability and owner agreement (scalability ≈ 0.4–0.8).
- Levels: governance and quality basics M2; integrated sources, semantic layer M3; monitored data with automated controls M4; real-time contextual data M5.

### `infra` — infrastructure
Cloud and hosting, networks and connectivity, devices and sensors, operational technology, cybersecurity, real-time data acquisition.
- Usually the deepest foundations, with procurement and installation lead times (scalability ≈ 0.3–0.6; hardware and certification toward the low end).
- Shared across processes; cost is usually `fixed`.
- Levels: connectivity, hosting, acquisition M2; interoperable and secure architecture M3; orchestrated, event-driven M4.

### Typical chain (shape, not content)
```
infra ──► data ──► digital ──► MILESTONE
                     ▲
           people ───┘   (adoption next to every solution)
```

---

## 3. Data structure

One Excel workbook, **one sheet per table**, column names in row 1 (lower case). A `README` sheet documents the columns, a `levels` sheet describes M1–M5, and a `config` sheet holds assumptions (read only: never output config rows).

General rules:
- Exactly the listed column names; order does not matter; extra columns are ignored.
- One row per record, no merged cells. Numbers are plain numbers: no units, `$` or thousands separators.
- Quarters are text `YYYYQn`; months are text `YYYY-MM`; levels are `M1`…`M5`.
- IDs are text, case-sensitive, no spaces, never reused or renumbered.

### 3.1 `process`
| column | type | rules |
|---|---|---|
| `id` | text | Given to you. Do not invent process IDs. |
| `name` | text | Process name |
| `owner` | text | Accountable **role**, never a person's name |
| `current_level` | M1–M5 | Maturity today, from the six dimensions |
| `target_level` | M1–M5 | Base-case target, at or above the current level |

### 3.2 `milestone`
| column | type | rules |
|---|---|---|
| `id` | text | e.g. `R-<process>-<nn>`. Unique. |
| `process_id` | text | The process that achieves it |
| `name` | text | The step change, ≤ 50 characters |
| `due` | month | `YYYY-MM`, the business commitment |
| `level` | M1–M5 | The level it belongs to; at least the level of the enablers it requires |

### 3.3 `metric`
| column | type | rules |
|---|---|---|
| `id` | text | e.g. `K-<process>-<nn>`. Unique. |
| `process_id` | text | The process whose value it is |
| `name` | text | What is measured |
| `unit`, `baseline`, `target` | text, number, number | Today and at full impact (M5); both or neither |
| `value_musd` | number | **Annual** $M from the current level to M5, before realisation |
| `value_driver` | text | `oil_price` (commodity price lever), `fte_cost` (saved people time) or `none` |
| `curve_id` | text | A curve from the `curve` sheet |

### 3.4 `metric_milestone`
| column | type | rules |
|---|---|---|
| `metric_id` | text | Must exist in `metric` |
| `milestone_id` | text | A milestone that moves it; several (any level, any process) can converge on one metric |

### 3.5 `curve`
| column | type | rules |
|---|---|---|
| `id`, `name`, `description` | text | e.g. `concave`, *Diminishing returns* |
| `m1` … `m5` | number | % of impact reached at each level, 0–100, never decreasing |

Proposed curves: `concave` 0·45·75·92·100 (gain comes early), `threshold` 0·5·15·55·100 (gain only with automation), `linear` 0·25·50·75·100, `s_curve` 0·10·45·85·100 (gain with integration and automation).

### 3.6 `concept`
| column | type | rules |
|---|---|---|
| `id` | text | e.g. `C-<short name>`. Unique. |
| `name` | text | Concept name |
| `enabler_group` | text | `people`, `digital`, `data` or `infra` |
| `subgroup` | text | Short free text (e.g. a capability family) |
| `fte_internal` | number | Internal dedicated team: average FTE over the concept's build window (first start → last go-live) |
| `fte_sme` | number | Optional. Part-time subject-matter experts and other staff, as FTE-equivalent (people × share of time: 6 at 20% = 1.2) |
| `fte_partner` | number | Average partner / vendor / contractor FTE over the same window |

### 3.7 `enabler`
| column | type | rules |
|---|---|---|
| `id` | text | `E-<process>-<nn>` (process-specific) or `E-X-<nn>` (cross-process). Unique. |
| `concept_id` | text | Must exist in `concept` |
| `name` | text | The thing being built, ≤ 40 characters |
| `level` | M1–M5 | The maturity it enables (see the typical levels per group in section 2) |
| `start_q` | quarter | `YYYYQn` |
| `end_q` | quarter | Go-live quarter (inclusive) |
| `capex_musd` | number | One-off investment, $M |
| `opex_musd_yr` | number | Running cost per year after go-live, $M |
| `cost_basis` | text | `fixed` (default) or `per_process` (cost grows with the processes that need it) |
| `scalability` | number 0–2 | 0 rigid, 1 linear, > 1 better than linear (see 3.10) |

### 3.8 `milestone_enabler` (requirements)
| column | type | rules |
|---|---|---|
| `milestone_id` | text | Must exist in `milestone` |
| `enabler_id` | text | Must exist in `enabler` |
| `weight` | number | Relative contribution, normalised per milestone. Default 1. |

### 3.9 `enabler_dependency` (foundations)
| column | type | rules |
|---|---|---|
| `enabler_id` | text | The enabler that needs something |
| `requires_id` | text | The enabler it needs first |

No cycles (A needs B needs A, or longer loops). Only direct prerequisites: if A needs B and B needs C, do not add A needs C.

### 3.10 Scalability guide
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

Work **one process at a time**, always against the current catalogue (the latest exported workbook) so shared items are reused, not duplicated.

1. **Understand the process** from the material given: how the work is done, where time, cost and risk go, and how humans, software, agents and machines would split the work at each level.
2. **Assess the current level** on the six dimensions, and propose a **target** from expected value, technical, economic and operational feasibility, and risk.
3. **Define the metrics** (1–4): measured outcomes with baseline today and target at M5. Value each: `value_musd ≈ Δ(target − baseline) × volume × unit value` per year. **Count value once.** Choose the impact curve that matches how the metric responds to maturity.
4. **Define milestones per level**, from the level above the current one up to what is realistic (usually up to M5, so the frontier can price every level). Each is an observable step change with a due date.
5. **Link milestones to metrics**: which milestones move which metric (several can converge on one).
6. **Find the enablers per milestone**, group by group: the *digital* solution, the *data* it needs, the *infra* under that data, and the *people* change that makes it stick. Set each enabler's level; it must not exceed the level of a milestone that requires it. List only direct requirements; reach deeper foundations through dependencies.
7. **Reuse before creating**: search the catalogue for an existing enabler or concept. New cross-process foundations get `E-X-<nn>`.
8. **Group into concepts and plan people**; schedule (builds of 2–8 quarters), cost, cost basis and scalability, each traceable to a note.
9. **Check the chain** for each level: from value down to the deepest foundation. Keep real dates even if a milestone is late, and explain the gap.
10. **Write the output** (section 5) and run the checklist (section 6).

### Anti-patterns
- Copying a generic "transformation programme" instead of deriving enablers from the process evidence.
- Assigning levels by technology hype: an AI tool on scattered data does not make a process M4.
- A milestone that is really an activity ("deploy tool X"): milestones are step changes; tools are enablers.
- Enablers of a higher level than the milestones that need them; milestones at or below the current level.
- Digital enablers with no data foundation or no people/adoption enabler.
- The same benefit counted in two metrics, or the same cost in capex and partner FTE.
- A metric with no milestone, or a curve chosen without a reason.
- Adjusting due dates to hide lateness; inventing process IDs.

---

## 5. Output format

Output **only new or changed rows**, never the whole workbook. Changed rows repeat the full row with the same ID.

- If you can create files: an `.xlsx` with the same sheet names and columns; omit sheets with no rows.
- Otherwise: one CSV block per sheet, titled with the sheet name; quote text containing commas.

Then the **notes**, in Markdown:

- **Maturity assessment** — the six dimensions today, and why the target.
- **Process summary** — today, and the human / digital / agent / machine split at each level.
- **Milestones and levels** — why each milestone sits at its level.
- **Metrics** — value calculation for each, and why its curve.
- **Cost estimates** — basis for each capex, opex, concept FTE, every `per_process` choice and each enabler level.
- **Scalability** — values outside the typical range, and every value above 1, justified.
- **Assumptions and sources** — what was given, what was assumed, confidence (high / medium / low).
- **Reused and new shared enablers**, **changed rows**, **late milestones and date conflicts**, **open questions**.

---

## 6. Checklist

- [ ] Column names exactly as listed; numbers without units; dates `YYYYQn` / `YYYY-MM`; levels `M1`–`M5`.
- [ ] Every reference points to a row in the output or the catalogue.
- [ ] Each process has `current_level` ≤ `target_level` and milestones for the levels above its current one.
- [ ] Every milestone has a level, a due month and at least one required enabler; no enabler is above a milestone that requires it.
- [ ] Every metric has a value, a curve and at least one milestone; a measure has both baseline and target (at M5).
- [ ] Every enabler has a concept, a level, a cost basis and a scalability; digital enablers have data foundations and a people/adoption enabler.
- [ ] Value counted once; no dependency cycles; only direct prerequisites listed.
- [ ] Every number traces to a line in the notes; nothing was taken from the example below.

---

## 7. Example (format only — fictitious)

An abstract process to show how the sheets connect. Names, values and dates are placeholders: **do not reuse them**.

```csv
# process
id,name,owner,current_level,target_level
P01,Process A,Head of Process A,M2,M4
```

```csv
# milestone
id,process_id,name,due,level
R-P01-01,P01,Core activity runs end to end in one flow,2027-12,M3
R-P01-02,P01,Routine decisions taken by rules and models,2028-12,M4
```

```csv
# metric
id,process_id,name,unit,baseline,target,value_musd,value_driver,curve_id
K-P01-01,P01,Cycle time of the core activity,days,20,6,3.0,fte_cost,s_curve
```

```csv
# metric_milestone
metric_id,milestone_id
K-P01-01,R-P01-01
K-P01-01,R-P01-02
```

```csv
# curve
id,name,m1,m2,m3,m4,m5,description
s_curve,S-curve,0,10,45,85,100,Gain concentrates on integration and automation
```

```csv
# concept
id,name,enabler_group,subgroup,fte_internal,fte_sme,fte_partner
C-ADOPT,Adoption programme,people,Change management,1,1.2,0.5
C-FLOW,Workflow solution,digital,Workflows,2,0.8,3
C-DATA,Data integration,data,Integration,1.5,0.5,2
C-CLOUD,Hosting,infra,Cloud,0.5,0,1
```

```csv
# enabler
id,concept_id,name,level,start_q,end_q,capex_musd,opex_musd_yr,cost_basis,scalability
E-X-01,C-CLOUD,Hosting environment,M2,2026Q3,2027Q1,1.0,0.3,fixed,0.9
E-X-02,C-DATA,Integrated source data,M3,2026Q4,2027Q3,1.5,0.4,fixed,0.6
E-P01-01,C-FLOW,Connected workflow,M3,2027Q1,2027Q4,1.5,0.3,fixed,0.8
E-P01-02,C-FLOW,Decision rules and models,M4,2028Q1,2028Q4,2.0,0.4,fixed,0.7
E-P01-03,C-ADOPT,Training and new roles,M4,2028Q1,2028Q3,0.4,0,per_process,0.3
```

```csv
# milestone_enabler
milestone_id,enabler_id,weight
R-P01-01,E-P01-01,1
R-P01-02,E-P01-02,0.7
R-P01-02,E-P01-03,0.3
```

```csv
# enabler_dependency
enabler_id,requires_id
E-P01-01,E-X-02
E-X-02,E-X-01
E-P01-02,E-P01-01
```

What the dashboard derives:
```
PROCESS A  M2 → M4
├── M3  Core activity runs end to end in one flow · due 2027-12 · ready 2027Q4
│   └── Connected workflow [M3, live 2027Q4] ← Integrated source data [M3] ← Hosting environment [M2]
└── M4  Routine decisions taken by rules and models · due 2028-12 · ready 2028Q4
    ├── 70%  Decision rules and models [M4, live 2028Q4] ← Connected workflow
    └── 30%  Training and new roles [M4, live 2028Q3]
METRIC  Cycle time of the core activity (s_curve, from M2)
    M3 ready 2027Q4: +(45 − 10) / (100 − 10) = 39% of $3.0M/yr
    M4 ready 2028Q4: +(85 − 45) / 90 = 44%  → 83% of the value at the M4 target; M5 would add the last 17%
```

Notes excerpt (pattern to follow):
- Current level M2: activities recorded in digital tools, but hand-offs by email and spreadsheets (dimensions 1–2 at M2, 3–6 at M1–M2).
- K-P01-01 value: (20 − 6) days × N cases/yr × hours per case-day × loaded hourly cost ≈ $3.0M/yr — show the actual inputs you were given.
- s_curve: the cycle time falls mostly once the flow is connected (M3) and decisions are automated (M4).
