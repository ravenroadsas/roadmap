# Roadmap data authoring guide (for AI agents)

You are helping build a digital transformation roadmap for 2026–2029. The company is moving its processes to an integrated system of **humans, AI agents and robots**. You work through the business processes **one at a time**, and you are the only agent writing this data. Your job is to turn what you learn about a process into rows for the roadmap workbook, in the exact format below.

For each process you will be given:
- the process ID and name, and whatever source material is available (interviews, documents, data)
- the **current catalogue**: the latest workbook, exported from the app (Method tab → "download workbook"), with the milestones, metrics, enablers and dependencies already in it, including those from processes you have already done

Your output is loaded straight into a database and a dashboard. Rows in the wrong format get rejected. Follow the format exactly, and keep your reasoning in the notes section (see [Output format](#4-output-format)), never in the data rows.

---

## 1. How the model works

**Investment builds enablers. Enablers and each process's digital maturity target make milestones possible. Milestones move metrics up their impact curve. Metrics create value.**

```
                 PROCESS (current → target maturity, M1..M5)
                          │
INVESTMENT → ENABLER ─────┴──► MILESTONE ──► METRIC ──impact curve──► VALUE $M/yr
 (concept FTE,  (level M,         (level M,     (baseline today → target at M5,
  capex, opex)   dates, cost)      due date)      % of impact reached vs M)
```

- A **process** has a **current** digital maturity and a **target** (the base case; the dashboard lets the user change it to run scenarios).
- A **milestone** is a step change on the way to a level. It belongs to one process and has a **level** and a **due date**. It is pursued when its process's target is at or above its level. It **requires** enablers (with weights).
- An **enabler** is something built: a digital solution, data, infrastructure or a people / change initiative, with capex, opex, dates and the **level it enables**. It belongs to a **concept** (group › subgroup › concept › enabler); **people (FTE) are planned on the concept**. An enabler can **require other enablers** first (foundations). It is paid for only when a pursued milestone needs it.
- A **metric** is a measured outcome of a process (baseline today, target at M5) with a **value** (`value_musd`, $M per year for going from the current level to M5) and an **impact curve**: the % of the impact reached at each level. One or more **milestones move a metric** (`metric_milestone`).

### 1.1 What the dashboard calculates (you don't, but your numbers drive it)

- **Scope**: milestones at or below each process's target; the enablers they require, with their foundations, are the investment.
- **Ready date** of a milestone: the latest go-live across its required enablers and their prerequisites; **late** when after its due month (red). A process reaches level L when its milestones up to L are ready.
- **Metric value**: as its linked milestones become ready, the metric climbs its curve from the current level. Each step adds (curve(L) − curve(previous)) / (curve(M5) − curve(current)) of `value_musd`, ramped over the adoption time, × realisation × driver (oil price or FTE cost).
- **Cost per year**: capex spread over the build; people cost during the build, partner staff at a premium; opex from go-live to the horizon.
- **Frontier**: every combination of targets is evaluated to find the ones with the best NPV for their investment.

### 1.2 Maturity levels

| Level | Name | Key trait | Looks like |
|---|---|---|---|
| M1 | Manual | Dependence on human intervention | Manual activities, scattered information, isolated tools; decisions rely on people's judgement. |
| M2 | Assisted | Digital support to execution | Digital tools to execute, record and follow up; decisions stay human; manual steps between systems. |
| M3 | Integrated | End-to-end integration and traceability | Standard workflows connected end to end; structured, traceable data exchange; integrated view of performance. |
| M4 | Automated | Automation and data-driven decisions | Workflows, rules, algorithms and models execute, validate, detect deviations and recommend or decide; people handle exceptions. |
| M5 | Adaptive | Anticipation and continuous optimisation | Real-time data, advanced analytics and AI anticipate and adjust execution, with continuous learning and autonomy within set limits. |

Assess a process's current level on six dimensions: digitalisation of activities, integration and architecture, data management and quality, automation, intelligence and decisions, adaptability and optimisation.

---

## 2. Tables and field rules

The roadmap data lives in one **Excel workbook** with **one sheet per table**: `process`, `milestone`, `metric`, `metric_milestone`, `curve`, `concept`, `enabler`, `milestone_enabler`, `enabler_dependency`. The column names are in row 1. A `config` sheet holds the scenario assumptions; it's maintained by the roadmap team, so never output rows for it. A `README` sheet describes every column; a `levels` sheet describes M1–M5 (reference only). The app reads the workbook at startup and stops with a list of problems (sheet, column, row) if anything is wrong.

Rules for every sheet:
- Use exactly the column names listed below, in lower case. Column order doesn't matter. Extra columns are ignored, so don't put information there that should be in the notes.
- One row per record and no merged cells. Fully empty rows are skipped.
- Numbers must be real numbers, with no units, `$` signs or thousands separators.
- Quarters are text like `2027Q3`, and months are text like `2027-03`.
- Optional columns may be left empty; they get their default (see the `README` sheet).
- Maturity levels are written `M1` to `M5` (a plain `3` is also accepted).

### 2.1 `process`

| column | type | rules |
|---|---|---|
| `id` | text | Given to you. Don't invent process IDs. |
| `name` | text | Process name |
| `owner` | text | Accountable **role**, never a person's name. Spell the same role the same way everywhere. |
| `current_level` | M1–M5 | Maturity today, from the six dimensions above. Explain the assessment in the notes. |
| `target_level` | M1–M5 | Base-case target, at or above `current_level`: the highest level worth reaching given value, feasibility and risk. |

Output a process row to set or change its levels (or when asked to create or rename it).

Current processes:

| id | name |
|---|---|
| P01 | Evaluación de recursos y reservas |
| P02 | Interpretación y caracterización |
| P03 | Identificación de oportunidades de nuevos pozos y WO |
| P04 | Surveillance de yacimiento |
| P05 | Surveillance de producción / Optimización de la producción / gestión ALS |
| P06 | Operación de taladros |
| P07 | Confiabilidad eléctrica |
| P08 | Gestión de Mantenimiento |

### 2.2 `milestone`

| column | type | rules |
|---|---|---|
| `id` | text | `R-<process>-<nn>`, e.g. `R-P04-01`. Unique. |
| `process_id` | text | The process that achieves it (accountable owner). |
| `name` | text | The step change, max 50 characters: *Remote operations centre live*, *250 wells per engineer*. |
| `due` | month | `YYYY-MM`, the business commitment (not derived from enabler dates). |
| `level` | M1–M5 | The maturity level the milestone belongs to. It is pursued only when the process target is at or above it. |

Rules:
- Give each process milestones for **each level between its current level and M5** that is realistic, so the dashboard can show what each extra level costs and earns. A level without milestones is reached together with the next one up.
- A milestone's level is at least the level of the enablers it requires (the dashboard flags the opposite).
- Milestones at or below the current level add cost and no impact: avoid them.

### 2.3 `metric`

| column | type | rules |
|---|---|---|
| `id` | text | `K-<process>-<nn>`. Unique. |
| `process_id` | text | The process whose value it is. |
| `name` | text | What is measured: *Deferred production*, *Employees per 100 wells*. |
| `unit`, `baseline`, `target` | text, number, number | Measure: value today and at full impact (**M5**). Give both or neither. |
| `value_musd` | number | **Annual** value in $M of going from the current level to M5, before any realisation haircut. |
| `value_driver` | text | `oil_price`, `fte_cost` or `none` (see 2.10). |
| `curve_id` | text | An impact curve from the `curve` sheet (2.5). |

Rules:
- Estimate `value_musd` as Δ(target − baseline) × volume × unit value and show the calculation in the notes.
- **Count value once**: two metrics must not measure the same benefit.

### 2.4 `metric_milestone` (which milestones move each metric)

| column | type | rules |
|---|---|---|
| `metric_id` | text | Must be a metric `id` |
| `milestone_id` | text | A milestone that moves the metric up its curve. Several milestones (of any level, even of other processes) can move one metric. |

Every metric needs at least one milestone. The metric reaches level L when every linked milestone up to L is ready; link milestones at each level that changes the metric.

### 2.5 `curve` (impact curves)

| column | type | rules |
|---|---|---|
| `id`, `name` | text | e.g. `concave`, *Diminishing returns* |
| `m1` … `m5` | number | % of the metric's impact reached at each level, 0–100, never decreasing (`m5` normally 100) |
| `description` | text | When to use it |

The workbook ships with four proposals; choose the one that matches how the metric responds to maturity, or propose a new curve in the notes:

| id | M1–M5 | use for |
|---|---|---|
| `concave` | 0 · 45 · 75 · 92 · 100 | most gain comes early: production, deferred production |
| `threshold` | 0 · 5 · 15 · 55 · 100 | little gain until automated: man-hours saved, headcount ratios |
| `linear` | 0 · 25 · 50 · 75 · 100 | each level adds the same |
| `s_curve` | 0 · 10 · 45 · 85 · 100 | gain concentrates on integration and automation: cycle times, NPT, chance of success |

### 2.6 `concept` (group › subgroup › concept)

A concept groups the enablers that belong together, and carries their people.

| column | type | rules |
|---|---|---|
| `id` | text | `C-<short name>`, e.g. `C-ROC`. Unique. |
| `name` | text | e.g. `Remote operations` |
| `enabler_group` | text | One of: `people`, `digital`, `data`, `infra` |
| `subgroup` | text | Free text, short, e.g. `Remote operations`, `AI / ML`, `Governance` |
| `fte_internal` | number | Average internal FTE working on the concept over its build window (first enabler start to last go-live): expertise or manpower **built or hired internally** |
| `fte_partner` | number | Average FTE from **allies, vendors and contractors** over the same window |

The app spreads a concept's FTE over its enablers in proportion to their build duration, so total effort (FTE × window) is kept.

| group | meaning | subgroups in use |
|---|---|---|
| `people` | People, change management and adoption | Training & skills, Change management, Organisation design, Standards |
| `digital` | Digital solutions: apps, AI/ML, AI agents, automation, robotics, twins, remote operations | AI / ML, AI agents, Workflows, Remote operations, Work management, Modelling & planning |
| `data` | Data platforms, integration, governance, master data | Platform, Governance, Integration |
| `infra` | Infrastructure: cloud, network, OT, security, real-time data | Cloud, Network, Security, Real-time data |

### 2.7 `enabler`

| column | type | rules |
|---|---|---|
| `id` | text | `E-<process>-<nn>` for process-specific enablers, `E-X-<nn>` for cross-process ones (see 3.2) |
| `concept_id` | text | Must be a concept `id` |
| `name` | text | Max 40 characters, the thing being built, e.g. `Predictive maintenance platform` |
| `level` | M1–M5 | The maturity it **enables** (see 1.2): e.g. data governance M2, integrated workflows M3, agentic AI M4, real-time optimisation M5. It must not be above the level of any milestone that requires it. |
| `start_q` | text | `YYYYQn`, e.g. `2027Q1` |
| `end_q` | text | `YYYYQn`, the quarter it goes live (inclusive). If it is before `start_q` the row still loads, is shown in red, and is costed as one quarter long. |
| `capex_musd` | number | One-off investment in $M (licences, hardware, vendor implementation) |
| `opex_musd_yr` | number | Running cost per year after go-live, in $M |
| `cost_basis` | text | `fixed` (default): the same cost whatever the processes in scope. `per_process`: cost grows with the processes it serves, such as training or change sessions per team. |
| `scalability` | number 0–2 | 0 rigid, 1 linear, above 1 better than linear. Used for time (more resources) and for a per-process cost (see 2.5.1). |

Rules:
- Every digital solution needs a `people` enabler next to it (training, change or new roles), unless an existing one already covers it.
- Agentic and robotic enablers should state in the notes what the agent or robot does and what humans keep doing.
- Don't put the same money in two places: `capex_musd` covers vendor implementation, and the concept's `fte_partner` covers people time from partners.
- Builds usually take 2 to 8 quarters. Anything longer should be split into phases linked by a dependency.
- Use `per_process` only when the cost really grows with the number of processes (teams, sites, people) it covers. When only some processes need it (their targets are below the milestones that require it), the app scales its cost as (processes needing it / processes served) ^ scalability.

#### 2.7.1 Scalability

`scalability` (s) describes what happens to the duration when more resources (people and budget) are put on the enabler. The start date never moves; only the end moves.

```
duration with extra resources = plan duration × (resource multiplier)^(−s)
```

| s | meaning | double the resources → |
|---|---|---|
| 0 | **Rigid.** More resources don't help (fixed lead times, regulation, behaviour change). No resources are added. | same duration, same cost |
| 0.3–0.7 | **Diminishing returns.** Coordination, learning curves, sequential steps. | 19–38% shorter, total build cost +23% to +62% |
| 1 | **Linear.** Work splits cleanly across people. | half the time, same total cost |
| 1.1–1.5 | **Better than linear.** Many independent work packages, vendor capacity, or economies of scale. Rare. | 53–65% shorter, total build cost −7% to −29% |

Total build cost (capex and people effort) scales by (resource multiplier)^(1 − s). A duration never goes below one quarter.

The app's Sensitivity tab has an **Extra resources** lever (1× = plan, 2× = double). It applies the formula above to every enabler, spreads the same work over the shorter build, and recalculates the yearly expenditure. You only provide `s`.

Typical values:

| kind of enabler | scalability | why |
|---|---|---|
| Cloud setup, mobile/field apps, RPA and automation | 0.9–1.2 | parallel teams and modular work |
| Data platform, data integration, AI/ML, digital twins | 0.6–0.8 | limited by data availability and testing cycles |
| AI agents in operations | 0.5–0.7 | trust building and supervised running |
| OT security, governance, master data | 0.4–0.6 | depends on many owners agreeing |
| Hardware, networks, robots, drones | 0.3–0.4 | procurement lead times, site access, certification |
| Organisation design, training | 0.3–0.5 | people need time to learn |
| Change management, adoption programmes | 0–0.1 | behaviour change can't be bought faster |
| Regulatory or contractual steps | 0 | fixed external timelines |

Explain any value outside these ranges, and any value above 1, in the notes.

### 2.8 `milestone_enabler` (which enablers each milestone requires)

| column | type | rules |
|---|---|---|
| `milestone_id` | text | Must be a milestone `id` |
| `enabler_id` | text | Must be an enabler `id` |
| `weight` | number | Relative contribution, normalised per milestone. Default 1. |

Rules:
- Every milestone needs at least one row here.
- List the enablers the milestone **directly** needs; their prerequisites come in through dependencies.
- Every required enabler sets the ready date: a small contribution from a late enabler still makes the milestone late.

### 2.9 `enabler_dependency`

| column | type | rules |
|---|---|---|
| `enabler_id` | text | The enabler that needs something |
| `requires_id` | text | The enabler it needs |

Rules:
- The `requires_id` enabler's `end_q` should be on or before the dependent enabler's `end_q`. They may overlap in time; the arrow then shows "can't finish before". If the information you have puts a prerequisite later, keep the real dates. The app loads them and shows the conflict in red. Explain it in the notes.
- No cycles: A needs B and B needs A is invalid, and so is any longer loop.
- List only direct prerequisites. If A needs B and B needs C, don't also add A needs C.

### 2.10 `config` sheet (read only)

You don't change the config sheet. Use only these keys as a metric's `value_driver`:

| key | meaning | use as driver when the value… |
|---|---|---|
| `oil_price` | Brent price, $/bbl (base 75) | comes from extra or protected production |
| `fte_cost` | Loaded cost per FTE, $k/yr (base 140) | comes from saved people time |
| `none` | no scaling | is a fixed saving (contracts, inventory, fines avoided) |

The other keys are not drivers: the levers `adoption_years`, `cost_multiplier`, `resource_multiplier`, and the fixed assumptions `realization`, `partner_premium`, `discount_rate`, `horizon_end`. If a metric needs a driver that doesn't exist (e.g. gas price), use `none`, and propose the new key in the notes.

---

## 3. IDs and shared enablers

### 3.1 ID rules
- IDs are text, case-sensitive, with no spaces.
- Use the prefixes above with a two-digit counter that starts at `01` for each process (`K-P04-01` metrics, `R-P04-01` milestones, `E-P04-01`, `E-X-01`).
- Never reuse or renumber an existing ID. If an item is dropped, leave its number unused.

### 3.2 Shared foundations
Infrastructure and data foundations (cloud, connectivity, data platform, master data, OT cybersecurity, digital academy) are usually shared by many processes.

1. You will be given the **current enabler catalogue**. Before creating an enabler, check whether an existing one already covers it. If it does, **reuse its ID** in `milestone_enabler` and `enabler_dependency`, and don't output the enabler row again.
2. A new foundation that other processes will also need gets an `E-X-<nn>` ID. Output its row once, from the first process that needs it, and reuse it afterwards.
3. If an existing enabler needs a different cost, date or scalability because of what you learned, output the full row again with the new values (same ID) and say what changed in the notes under **Changed rows**.

---

## 4. Output format

Your deliverable has two parts.

**A. The rows.** Include only **new or changed rows**, never the whole database. Changed rows replace the existing row with the same ID.
- If you can create files, return an `.xlsx` workbook with the same sheet names and columns as the input file. Leave out sheets that have no rows.
- Otherwise, return one CSV block per sheet, titled with the sheet name. Use a header row and comma separators, and quote any text that contains a comma.

**B. The notes**, in Markdown:

- **Maturity assessment**: current level on the six dimensions, and why the target.
- **Process summary**: how the process works today and how humans, agents and robots split the work at each level.
- **Milestones**: what each level means for this process, and why each milestone sits at its level.
- **Metrics**: value calculation (`value_musd`), and why the curve.
- **Cost estimates**: basis for each enabler's capex and opex, each concept's FTE, every `per_process` cost basis, and each enabler's level.
- **Assumptions and sources**, **reused enablers**, **new shared enablers**, **changed rows**, **late milestones and date conflicts**, **open questions**.

## 5. Checklist before you answer

- [ ] Each sheet uses exactly the listed column names; numbers have no units or symbols; levels are `M1`–`M5`.
- [ ] Every reference points to a row in your output or in the catalogue.
- [ ] Each process has `current_level` ≤ `target_level`, and milestones for the levels between its current level and what is realistic.
- [ ] Every milestone has a level, a due month and at least one required enabler; no enabler is above the level of a milestone that requires it.
- [ ] Every metric has a curve, a value estimate and at least one milestone; a measure has both baseline and target (at M5).
- [ ] Value is counted once across metrics.
- [ ] No dependency cycles; late milestones and date conflicts are explained.
- [ ] Every enabler has a `scalability`, a `cost_basis` and a `level`.
- [ ] Each digital enabler has a people or adoption enabler next to it.
- [ ] Every number can be traced to a line in the notes.

## 6. Worked example (illustrative)

A process at M2 with a target of M4, one metric moved by an M3 and an M4 milestone:

```csv
# process
id,name,owner,current_level,target_level
P08,Gestión de Mantenimiento,Gerencia de Mantenimiento y Confiabilidad,M2,M4
```

```csv
# milestone
id,process_id,name,due,level
R-P08-01,P08,Work orders managed end to end in one system,2028-06,M3
R-P08-02,P08,Predictive maintenance on critical equipment,2029-06,M4
```

```csv
# metric
id,process_id,name,unit,baseline,target,value_musd,value_driver,curve_id
K-P08-01,P08,Deferred production,% of potential,6,2,30,oil_price,concave
```

```csv
# metric_milestone
metric_id,milestone_id
K-P08-01,R-P08-01
K-P08-01,R-P08-02
```

```csv
# milestone_enabler
milestone_id,enabler_id,weight
R-P08-01,E-X-08,1
R-P08-02,E-X-09,0.7
R-P08-02,E-X-20,0.3
```

With the `concave` curve, R-P08-01 (M3) brings (75 − 45) / (100 − 45) = 55% of the $30M once ready, and R-P08-02 (M4) another 31%; reaching M5 would need a further milestone for the last 15%.
