# Roadmap data authoring guide (for AI agents)

You are helping build a digital transformation roadmap for 2026–2029. The company is moving its processes to an integrated system of **humans, AI agents and robots**. You work through the business processes **one at a time**, and you are the only agent writing this data. Your job is to turn what you learn about a process into rows for the roadmap workbook, in the exact format below.

For each process you will be given:
- the process ID and name, and whatever source material is available (interviews, documents, data)
- the **current catalogue**: the latest workbook, exported from the app (Data model tab → "Download the current data as Excel"), with the results, enablers and dependencies already in it, including those from processes you have already done

Your output is loaded straight into a database and a dashboard. Rows in the wrong format get rejected. Follow the format exactly, and keep your reasoning in the notes section (see [Output format](#4-output-format)), never in the data rows.

---

## 1. How the model works

**Enablers make results possible. Results generate value for processes.**

```
CONCEPT ─groups─► ENABLER ──makes possible (weight)──► RESULT ──value $M/yr──► PROCESS(es)
 (FTE)              │ capex, opex, start → go-live        │ due date, optional measure
                    └ requires other enablers (foundations)
```

- A **process** is a business process being transformed. Its owner is accountable for the results it leads.
- A **result** is one category of tangible outcome, with a **due date** and a **value** (`value_musd`, $M per year once achieved, or 0). It may carry a **measure** (unit, baseline → target); without one it is a step change that is achieved or not. A result can be shared by several processes.
- Each result **explicitly requires N enablers**, each with a weight.
- An **enabler** is something we build: a digital solution, data, infrastructure or a people / change initiative. It has capex, opex and dates. It belongs to a **concept**: group › subgroup › concept › enabler. **People (FTE) are planned on the concept**, not on each enabler.
- An enabler can **require other enablers** to be live first: those prerequisites are the **foundations** of the result.
- Each enabler has a **cost basis**: `fixed` (same cost whatever the scope) or `per_process` (cost grows with the number of processes it serves, e.g. change-management sessions).

### 1.1 Glossary

A result is ready when its required enablers **and all their prerequisites** are live. If that is after its due date, the result is **late** (red in the app). Read the trees from the value down to the foundations. Both come from the current data; the app's Glossary tab draws the same trees for any result.

Example with a measure: late, because it requires iROC (20%), which goes live a year after the due date.

```
VALUE  $8.4M/yr at full adoption → Operación de taladros
└── RESULT  Drilling & operations non-productive time · 15% → 8% · due 2028-12 · ready 2029Q4
    ├── 50%  ROC  [required · digital · live 2027Q3]
    │   └── requires  WITSML upgrade  [foundation · infra · live 2026Q4]
    ├── 30%  Sistema de gestión de trabajos e intervenciones  [required · digital · live 2028Q2]
    │   └── requires  System of records  [foundation · digital · live 2027Q2]
    │       └── requires  Integrated data sources  [foundation · data · live 2027Q2]
    │           └── requires  Data governance  [foundation · data · live 2026Q4]
    └── 20%  iROC  [required · digital · live 2029Q4]
        ├── requires  Agentic AI  [foundation · digital · live 2028Q4]
        │   ├── requires  WF estandarizado  [foundation · digital · live 2027Q4]
        │   │   ├── requires  Integrated workflows  [foundation · digital · live 2027Q4]
        │   │   │   ├── requires  System of records  (see above)
        │   │   │   └── requires  Semantic layer  [foundation · data · live 2027Q3]
        │   │   │       └── requires  Integrated data sources  (see above)
        │   │   └── requires  Digital criteria  [foundation · people · live 2026Q2]
        │   ├── requires  Knowledge graph  [foundation · data · live 2027Q4]
        │   │   └── requires  Semantic layer  (see above)
        │   └── requires  Semantic layer  (see above)
        ├── requires  ROC  (see above)
        └── requires  Sistema de gestión de trabajos e intervenciones  (see above)
```

Example without a measure: on time, no value of its own (the value sits on *Deferred production*).

```
VALUE  none of its own → Gestión de Mantenimiento
└── RESULT  Downtime < 2% · due 2028-06 · ready 2028Q2
    └── 100%  Sistema de gestión de trabajos e intervenciones  [required · digital · live 2028Q2]
        └── requires  System of records  [foundation · digital · live 2027Q2]
            └── requires  Integrated data sources  [foundation · data · live 2027Q2]
                └── requires  Data governance  [foundation · data · live 2026Q4]
```

An enabler is **required** by a result when the result lists it, and a **foundation** of that result when it is only a prerequisite of a required enabler. The same enabler can play both roles across results: *Sistema de gestión de trabajos* is required by *Downtime < 2%* and a foundation of iROC.

| Element | What it is | Question it answers | Where it lives |
|---|---|---|---|
| **Process** | The business process being transformed; owns results. | Where does the value land, who owns it? | sheet `process` |
| **Result** | A tangible outcome of a process with a due date, a value, and optionally a measure (baseline → target). | What do we commit to, by when, for what value? | sheet `result` |
| **Concept** | The level between subgroup and enabler; carries the people (FTE) of its enablers. | Who works on it? | sheet `concept` |
| **Cost basis** | `fixed`, or `per_process`: cost grows with the processes the enabler serves. | Does it cost more for more processes? | `enabler.cost_basis` |
| **Value** | $M per year once a result is achieved. The only place money comes in. | What is the result worth? | `result.value_musd` |
| **Enabler** | Something we invest in and build. The only element that consumes money and staff. | What do we build, when, for how much? | sheet `enabler` |
| **Foundation** | A prerequisite of a required enabler. Its cost is shared by everything built on it. | What has to exist first? | derived from `enabler_dependency` |
| **Shared result** | A result split across several processes by share; the lead process is accountable. | | sheet `result_process` |
| **Requirement (weight)** | A result requires an enabler, by this much relative to its other required enablers. | | sheet `result_enabler` |
| **Dependency** | One enabler needs another to be live before it can go live. | | sheet `enabler_dependency` |
| **Due date vs ready date** | When the result should be achieved vs when its enablers make it possible. | | `result.due` / computed |
| **Late result** | Ready after its due date (red). | | computed |
| **Late dependency** | A prerequisite that goes live after the enabler that needs it (red arrow). | | computed |
| **Allocated cost** | The share of enabler cost charged to a result or process, including foundations. | | computed |
| **Scalability** | How an enabler's duration responds to more resources (0 rigid, 1 linear). | | `enabler.scalability` |
| **Config / scenario** | The assumptions the app uses for cost and value. | | sheet `config` |

The dashboard calculates the following. You don't compute any of it, but your numbers drive it:
- **Ready date** of a result: the latest go-live across its required enablers and their prerequisites. Late results are flagged.
- **Value per year**: `value_musd` × the share of the target achieved × the driver factor × the adoption ramp after the ready date.
- **Cost per year**: capex spread evenly over the build; people cost during the build, partner staff at a premium; opex from go-live to the horizon.
- **Cost allocation**: an enabler's cost is split across the results that require it, by weight; foundations pass their cost on to the results of the enablers built on them.
- **Time scenarios**: more resources shorten enablers according to their `scalability`; the app can back-calculate the resources needed for every result to meet its due date.
- **Date conflicts**: a prerequisite that goes live after the enabler needing it, or an end before the start, loads anyway and is shown in red.

---

## 2. Tables and field rules

The roadmap data lives in one **Excel workbook** with **one sheet per table**: `process`, `result`, `result_process` (optional), `concept`, `enabler`, `result_enabler`, `enabler_dependency`. The column names are in row 1. A `config` sheet holds the scenario assumptions; it's maintained by the roadmap team, so never output rows for it. A `README` sheet describes every column. The app reads the workbook at startup and stops with a list of problems (sheet, column, row) if anything is wrong.

Rules for every sheet:
- Use exactly the column names listed below, in lower case. Column order doesn't matter. Extra columns are ignored, so don't put information there that should be in the notes.
- One row per record and no merged cells. Fully empty rows are skipped.
- Numbers must be real numbers, with no units, `$` signs or thousands separators.
- Quarters are text like `2027Q3`, and months are text like `2027-03`.
- Optional columns may be left empty; they get their default (see the `README` sheet).

### 2.1 `process`

| column | type | rules |
|---|---|---|
| `id` | text | Given to you. Don't invent process IDs. |
| `name` | text | Process name |
| `owner` | text | Accountable **role**, never a person's name. The app filters by owner, so spell the same role the same way everywhere. |

You normally output **no** process rows. Only output one if you were asked to create or rename the process.

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

### 2.2 `result`

| column | type | rules |
|---|---|---|
| `id` | text | `R-<process>-<nn>`, e.g. `R-P04-01`. Unique. Existing IDs (`K-…`, `M-…`) stay as they are. |
| `process_id` | text | Must be a process `id`: the **lead** process, whose owner is accountable. If other processes share it, list them in `result_process` (2.3). |
| `name` | text | The tangible result, max 50 characters: *Employees per 100 wells*, *250 wells per engineer*. |
| `due` | month | `YYYY-MM`, when the result should be achieved |
| `value_musd` | number | **Annual** value in **$ millions** once achieved, before any realisation haircut. 0 or empty if the result has no value of its own. |
| `value_driver` | text | A config key that scales the value: `oil_price`, `fte_cost`, or `none` (see 2.8) |
| `unit` | text | Optional measure: unit of baseline and target (`days`, `%`, `bbl/employee·yr`, `$M`…) |
| `baseline` | number | Optional measure: current value. Give both baseline and target, or neither. |
| `target` | number | Optional measure: value when the result is achieved |

Rules:
- Use 2 to 6 results per process: the measured improvements, and the step changes management will check.
- When a result has a measure, whether the target is above or below the baseline tells the direction of improvement.
- Estimate `value_musd` as Δ(target − baseline) × volume × unit value and show the calculation in the notes.
- **Count value once.** If one result is a step towards another (e.g. *250 wells per engineer* towards *employees per 100 wells*), put the value on one of them and 0 on the other, or split it explicitly and say so in the notes.
- Set `due` from the business commitment, not from the enabler dates. If the enablers make it late, the app shows it; explain the gap in the notes.

### 2.3 `result_process` (optional: results shared by several processes)

Use this sheet only when one result is genuinely shared: several processes contribute to it and each should see it, and its value and cost, in its own figures. Results not listed here belong 100% to their lead process.

| column | type | rules |
|---|---|---|
| `result_id` | text | Must be a result `id` |
| `process_id` | text | A process that shares the result. **List the lead process too.** |
| `share` | number | Relative share of the result's value and cost for this process. Normalised per result, so `2, 1, 1` means 50% / 25% / 25%. Default 1 (equal split). |

Rules:
- Only share a result when the processes really achieve it together. If each process finishes its own part at its own date, create one result per process instead.
- Base the shares on who carries the work or the benefit, and explain them in the notes.
- A shared result appears in each sharing process's lane on the timeline. In every process except the lead it is drawn with a dashed outline.

Example: *250 wells per engineer* led by reservoir surveillance, shared with production surveillance and drilling.

```csv
result_id,process_id,share
M-X-04,P04,0.4
M-X-04,P05,0.4
M-X-04,P06,0.2
```

### 2.4 `concept` (group › subgroup › concept)

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

### 2.5 `enabler`

| column | type | rules |
|---|---|---|
| `id` | text | `E-<process>-<nn>` for process-specific enablers, `E-X-<nn>` for cross-process ones (see 3.2) |
| `concept_id` | text | Must be a concept `id` |
| `name` | text | Max 40 characters, the thing being built, e.g. `Predictive maintenance platform` |
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
- Use `per_process` only when the cost really grows with the number of processes (teams, sites, people) it covers. When only some processes are in scope, the app scales its cost as (processes in scope / processes served) ^ scalability.

#### 2.5.1 Scalability

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

### 2.6 `result_enabler` (which enablers each result requires)

| column | type | rules |
|---|---|---|
| `result_id` | text | Must be a result `id` |
| `enabler_id` | text | Must be an enabler `id` |
| `weight` | number | Relative contribution, 0 to 1. Weights are **normalised per result**, so only the ratios between the enablers of the same result matter. Prefer weights that add up to 1 per result. Default 1. |

Rules:
- Every result needs at least one row here: a step change usually requires one or two enablers, a measured improvement often several.
- List the enablers the result **directly** needs. Don't list their prerequisites again: dependencies (2.7) bring them in, and they count as foundations automatically, including in the ready date.
- Every required enabler sets the ready date. A small contribution (say 10%) from a late enabler still makes the whole result late. If the result can be achieved without it, don't list it, or create a separate result for the later step.
- An enabler may be required by results of other processes.

### 2.7 `enabler_dependency`

| column | type | rules |
|---|---|---|
| `enabler_id` | text | The enabler that needs something |
| `requires_id` | text | The enabler it needs |

Rules:
- The `requires_id` enabler's `end_q` should be on or before the dependent enabler's `end_q`. They may overlap in time; the arrow then shows "can't finish before". If the information you have puts a prerequisite later, keep the real dates. The app loads them and shows the conflict in red. Explain it in the notes.
- No cycles: A needs B and B needs A is invalid, and so is any longer loop.
- List only direct prerequisites. If A needs B and B needs C, don't also add A needs C.

### 2.8 `config` sheet (read only)

You don't change the config sheet. Use only these keys as `value_driver`:

| key | meaning | use as driver when the value… |
|---|---|---|
| `oil_price` | Brent price, $/bbl (base 75) | comes from extra or protected production |
| `fte_cost` | Loaded cost per FTE, $k/yr (base 140) | comes from saved people time |
| `none` | no scaling | is a fixed saving (contracts, inventory, fines avoided) |

The other keys are not drivers: the levers `adoption_years`, `cost_multiplier`, `resource_multiplier`, and the fixed assumptions `realization`, `partner_premium`, `discount_rate`, `horizon_end`. If a result needs a driver that doesn't exist (e.g. gas price), use `none`, and propose the new key in the notes.

---

## 3. IDs and shared enablers

### 3.1 ID rules
- IDs are text, case-sensitive, with no spaces.
- Use the prefixes above with a two-digit counter that starts at `01` for each process (`K-P04-01`, `M-P04-01`, `E-P04-01`, `E-X-01`).
- Never reuse or renumber an existing ID. If an item is dropped, leave its number unused.

### 3.2 Shared foundations
Infrastructure and data foundations (cloud, connectivity, data platform, master data, OT cybersecurity, digital academy) are usually shared by many processes.

1. You will be given the **current enabler catalogue**. Before creating an enabler, check whether an existing one already covers it. If it does, **reuse its ID** in `result_enabler` and `enabler_dependency`, and don't output the enabler row again.
2. A new foundation that other processes will also need gets an `E-X-<nn>` ID. Output its row once, from the first process that needs it, and reuse it afterwards.
3. If an existing enabler needs a different cost, date or scalability because of what you learned, output the full row again with the new values (same ID) and say what changed in the notes under **Changed rows**.

---

## 4. Output format

Your deliverable has two parts.

**A. The rows.** Include only **new or changed rows**, never the whole database. These are appended to the matching sheets of the workbook, and changed rows replace the existing row with the same ID.
- If you can create files, return an `.xlsx` workbook with the same sheet names and columns as the input file. Leave out sheets that have no rows.
- Otherwise, return one CSV block per sheet, titled with the sheet name, so the rows can be pasted into that sheet. Use a header row and comma separators, and quote any text that contains a comma.

**B. The notes**, in Markdown.

````markdown
# Process <id> – <name>

## Sheet: result
```csv
id,process_id,name,due,value_musd,value_driver,unit,baseline,target
...
```

## Sheet: result_process (only for shared results)
```csv
result_id,process_id,share
...
```

## Sheet: concept (new concepts only)
```csv
id,name,enabler_group,subgroup,fte_internal,fte_partner
...
```

## Sheet: enabler
```csv
id,concept_id,name,start_q,end_q,capex_musd,opex_musd_yr,cost_basis,scalability
...
```

## Sheet: result_enabler
```csv
result_id,enabler_id,weight
...
```

## Sheet: enabler_dependency
```csv
enabler_id,requires_id
...
```

## Notes
- **Process summary**: 3–5 lines on how the process works today and how humans, agents and robots split the work afterwards.
- **Results**: why these results, which carry a measure, and how step changes relate to measured improvements (value counted once).
- **Value estimates**: one line per result with value, showing the calculation behind `value_musd`.
- **Cost estimates**: the basis for each enabler's capex and opex, each concept's FTE, and every `per_process` cost basis.
- **Assumptions and sources**: what you were told, what you assumed, and how confident you are (high / medium / low).
- **Reused enablers**: the IDs from the catalogue you required.
- **New shared enablers**: any `E-X-nn` rows and which other processes will likely use them.
- **Changed rows**: existing IDs you output again, with what changed and why.
- **Late results and date conflicts**: any result whose enablers go live after its due date, and any prerequisite that goes live after the enabler that needs it, with why the dates are still correct.
- **Open questions**: for the process owner.
````

## 5. Checklist before you answer

- [ ] Each sheet uses exactly the listed column names. Numbers have no units, `$` signs or thousands separators.
- [ ] Every `process_id`, `result_id`, `enabler_id` and `requires_id` points to a row in your output or in the catalogue you were given.
- [ ] Every result has a `due` month; a measure has both `baseline` and `target`; every enabler has a `concept_id` and a `cost_basis`.
- [ ] Every result requires at least one enabler. Every new enabler is required by a result, or is a prerequisite of an enabler that is.
- [ ] Value is counted once across a process's results. A shared result lists its lead process in `result_process`, and the shares are explained.
- [ ] Dates use `YYYYQn` (enablers) or `YYYY-MM` (results), within 2026–2030.
- [ ] There are no dependency cycles. Late results and date conflicts are allowed, but each one is explained in the notes.
- [ ] Every enabler has a `scalability`, and values outside the typical ranges or above 1 are explained.
- [ ] `value_driver` is `oil_price`, `fte_cost` or `none`.
- [ ] Each digital enabler has a people or adoption enabler next to it.
- [ ] Every number can be traced to a line in the notes.

---

## 6. Worked example (Gestión de Mantenimiento, excerpt)

```csv
id,process_id,name,due,value_musd,value_driver,unit,baseline,target
K-P08-01,P08,Deferred production,2029-12,30,oil_price,% of potential,6,2
R-P08-02,P08,Downtime < 2%,2028-06,0,none,,,
```

```csv
id,name,enabler_group,subgroup,fte_internal,fte_partner
C-WORK,Work management,digital,Work management,2,3.5
```

```csv
id,concept_id,name,start_q,end_q,capex_musd,opex_musd_yr,cost_basis,scalability
E-X-08,C-WORK,Sistema de gestión de trabajos e intervenciones,2027Q3,2028Q2,3.5,0.5,fixed,0.8
```

```csv
result_id,enabler_id,weight
K-P08-01,E-X-08,0.5
K-P08-01,E-X-09,0.4
K-P08-01,E-X-06,0.1
R-P08-02,E-X-08,1
```

```csv
enabler_id,requires_id
E-X-08,E-X-11
```

Notes excerpt:
- K-P08-01 value: (6% − 2%) of 20,000 bbl/d potential × 365 × $75 margin share ≈ $30M/yr (placeholder, to validate).
- R-P08-02 is a step on the way to K-P08-01, so its value is 0.
- C-WORK FTE: 2 internal and 3.5 partner on average from 2026Q3 to 2028Q2 for the system of records and the work management system together.
- E-X-08 scalability 0.8: configuration and data migration run in parallel by asset, but field roll-out follows crew rotations.
