# Roadmap data authoring guide (for AI agents)

You are helping build a digital transformation roadmap for 2026–2029. The company is moving its processes to an integrated system of **humans, AI agents and robots**. You work through the business processes **one at a time**, and you are the only agent writing this data. Your job is to turn what you learn about a process into rows for the roadmap workbook, in the exact format below.

For each process you will be given:
- the process ID and name, and whatever source material is available (interviews, documents, data)
- the **current catalogue**: the latest workbook, exported from the app (Data model tab → "Download the current data as Excel"), with the results, enablers and dependencies already in it, including those from processes you have already done

Your output is loaded straight into a database and a dashboard. Rows in the wrong format get rejected. Follow the format exactly, and keep your reasoning in the notes section (see [Output format](#4-output-format)), never in the data rows.

---

## 1. How the model works

```
PROCESS ──has──► RESULT (KPI or milestone) ──requires (weight)──► ENABLER ──requires──► ENABLER (foundation)
   ▲                 │ due date                                       │ start, go-live
   └──── value ──────┘ $M/yr when achieved                             └ money, internal and partner staff
```

- A **process** is a business process being transformed. It owns a set of results; achieving them is how the process generates value.
- A **result** is a tangible outcome of a process, with a **due date**. There are two kinds, with the same rules:
  - a **KPI** is measured: baseline → target in its own unit (days, %, bbl/employee);
  - a **milestone** is achieved or not: an observable step change (e.g. 250 wells per engineer).
- Each result **explicitly requires N enablers**, each with a weight (how much of the result that enabler accounts for).
- An **enabler** is something we invest in: a digital solution, data, infrastructure, or a people / change initiative. It costs money, internal staff and partner staff, and has a start and a go-live date.
- An enabler can **require other enablers** to be live first. Those prerequisites are the **foundations** of the result.
- A result has **value** (`value_musd`, $M per year once achieved), or 0 for a purely enabling milestone. Value is counted once: if a milestone is a step on the way to a KPI, put the value on the KPI.

### 1.1 Glossary

A result is ready when its required enablers **and all their prerequisites** are live. If that is after its due date, the result is **late** (red in the app). Read the trees from the value down to the foundations. Both come from the current data; the app's Glossary tab draws the same trees for any result.

KPI example: late, because it requires iROC (20%), which goes live a year after the due date.

```
VALUE  $8.4M/yr at full adoption → Operación de taladros
└── KPI  Drilling & operations non-productive time · 15% → 8% · due 2028-12 · ready 2029Q4
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

Milestone example: on time, no value of its own (the value sits on the KPI *Deferred production*).

```
VALUE  none (enabling milestone) → Gestión de Mantenimiento
└── MILESTONE  Downtime < 2% · due 2028-06 · ready 2028Q2
    └── 100%  Sistema de gestión de trabajos e intervenciones  [required · digital · live 2028Q2]
        └── requires  System of records  [foundation · digital · live 2027Q2]
            └── requires  Integrated data sources  [foundation · data · live 2027Q2]
                └── requires  Data governance  [foundation · data · live 2026Q4]
```

An enabler is **required** by a result when the result lists it, and a **foundation** of that result when it is only a prerequisite of a required enabler. The same enabler can play both roles across results: *Sistema de gestión de trabajos* is required by *Downtime < 2%* and a foundation of iROC.

| Element | What it is | Question it answers | Where it lives |
|---|---|---|---|
| **Process** | The business process being transformed; owns results. | Where does the value land, who owns it? | sheet `process` |
| **Result** | A tangible outcome of a process with a due date: KPI or milestone. | What do we commit to, by when? | sheet `result` |
| **KPI** | A result that is measured: baseline → target. | How much better does the process get? | `result.kind = kpi` |
| **Milestone** | A result that is achieved or not: an observable step change. | What step can management check? | `result.kind = milestone` |
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

The roadmap data lives in one **Excel workbook** with **one sheet per table**: `process`, `result`, `result_process` (optional), `enabler`, `result_enabler`, `enabler_dependency`. The column names are in row 1. A `config` sheet holds the scenario assumptions; it's maintained by the roadmap team, so never output rows for it. A `README` sheet describes every column. The app reads the workbook at startup and stops with a list of problems (sheet, column, row) if anything is wrong.

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

### 2.2 `result` (KPIs and milestones)

| column | type | rules |
|---|---|---|
| `id` | text | `K-<process>-<nn>` for a KPI, `M-<process>-<nn>` for a milestone, e.g. `K-P04-01`, `M-P04-02`. Unique. |
| `process_id` | text | Must be a process `id`: the **lead** process, whose owner is accountable for the result. If other processes share it, list them in `result_process` (2.3). |
| `kind` | text | `kpi` or `milestone` |
| `name` | text | KPI: what is measured. Milestone: the observable outcome. Max 50 characters. |
| `due` | month | `YYYY-MM`, when the result should be achieved (KPI: when the target is due) |
| `unit` | text | KPI only. Unit of baseline and target: `days`, `%`, `$/boe`, `bbl/employee·yr`, `$M`, `count`… Use `%` and `$M` exactly as written. |
| `baseline` | number | KPI only, **required** for KPIs: current value in `unit` |
| `target` | number | KPI only, **required** for KPIs: value at full adoption |
| `value_musd` | number | **Annual** value in **$ millions** once achieved, before any realisation haircut. 0 or empty for a purely enabling milestone. |
| `value_driver` | text | A config key that scales the value: `oil_price`, `fte_cost`, or `none` (see 2.7) |

Rules:
- Use 2 to 6 results per process: the KPIs that show the process improved, and the milestones that mark the step changes management will check.
- Prefer outcome KPIs (cycle time, cost per unit, downtime, NPT, throughput per employee) to activity KPIs (number of dashboards, users trained).
- Whether the target is above or below the baseline tells the app which direction counts as an improvement. Make sure it points the right way.
- Estimate `value_musd` as Δ(target − baseline) × volume × unit value and show the calculation in the notes.
- **Count value once.** If a milestone is a step towards a KPI (e.g. *250 wells per engineer* towards *employees per 100 wells*), put the value on the KPI and 0 on the milestone, or split it explicitly and say so in the notes.
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

### 2.4 `enabler`

| column | type | rules |
|---|---|---|
| `id` | text | `E-<process>-<nn>` for process-specific enablers. `E-X-<nn>` for cross-process foundations (see 3.2). |
| `enabler_group` | text | One of: `people`, `digital`, `data`, `infra` |
| `subcategory` | text | Free text, short. Reuse existing ones when they fit (list below). |
| `name` | text | Max 40 characters, describes the thing being built, e.g. `Predictive maintenance platform` |
| `start_q` | text | `YYYYQn`, e.g. `2027Q1`, from 2026Q1 to 2029Q4 |
| `end_q` | text | `YYYYQn`, the quarter the enabler goes live (inclusive: `2027Q1`–`2027Q1` is one quarter). Should not be before `start_q`; if it is, the row still loads, is shown in red, and is costed as one quarter long. |
| `capex_musd` | number | One-off investment in $M (licences, hardware, implementation by vendors) |
| `opex_musd_yr` | number | Running cost per year after go-live, in $M |
| `fte_internal` | number | Average internal people (FTE) working on the build: expertise or manpower that is **built or hired internally** |
| `fte_partner` | number | Average FTE from **allies, vendors and contractors** during the build |
| `scalability` | number 0–2 | How the duration responds to **more resources**: 0 rigid, 1 linear, >1 better than linear. See 2.4.1. |

Enabler groups and typical subcategories:

| group | meaning | subcategories in use |
|---|---|---|
| `people` | People, change management and adoption | Training & skills, Change management, Organisation design |
| `digital` | Digital solutions: apps, AI/ML, AI agents, automation, robotics, twins | Field apps, Automation, AI / ML, AI agents, Digital twin, Robotics |
| `data` | Data platforms, integration, governance, master data | Platform, Governance, Integration |
| `infra` | Infrastructure: cloud, network, OT, security, devices | Cloud, Network, Security |

Rules:
- Every digital solution needs at least one `people` enabler on the same process (training, change or new roles), unless an existing one already covers it. Transformation without adoption is not counted.
- Agentic and robotic enablers should state in the notes what the agent or robot does and what humans keep doing.
- Don't put the same money in two places: `capex_musd` covers vendor implementation, and `fte_partner` covers people time from partners. Keep them separate and estimate each.
- Builds usually take 2 to 8 quarters. Anything longer than 8 quarters should be split into phases, with each phase as its own enabler linked by a dependency.

#### 2.4.1 Scalability

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

### 2.5 `result_enabler` (which enablers each result requires)

| column | type | rules |
|---|---|---|
| `result_id` | text | Must be a result `id` |
| `enabler_id` | text | Must be an enabler `id` |
| `weight` | number | Relative contribution, 0 to 1. Weights are **normalised per result**, so only the ratios between the enablers of the same result matter. Prefer weights that add up to 1 per result. Default 1. |

Rules:
- Every result needs at least one row here. A milestone usually requires one or two enablers; a KPI often several.
- List the enablers the result **directly** needs. Don't list their prerequisites again: dependencies (2.6) bring them in, and they count as foundations automatically, including in the ready date.
- Every required enabler sets the ready date. A small contribution (say 10%) from a late enabler still makes the whole result late. If the result can be achieved without it, don't list it, or create a separate result for the later step.
- An enabler may be required by results of other processes.

### 2.6 `enabler_dependency`

| column | type | rules |
|---|---|---|
| `enabler_id` | text | The enabler that needs something |
| `requires_id` | text | The enabler it needs |

Rules:
- The `requires_id` enabler's `end_q` should be on or before the dependent enabler's `end_q`. They may overlap in time; the arrow then shows "can't finish before". If the information you have puts a prerequisite later, keep the real dates. The app loads them and shows the conflict in red. Explain it in the notes.
- No cycles: A needs B and B needs A is invalid, and so is any longer loop.
- List only direct prerequisites. If A needs B and B needs C, don't also add A needs C.

### 2.7 `config` sheet (read only)

You don't change the config sheet. Use only these keys as `value_driver`:

| key | meaning | use as driver when the value… |
|---|---|---|
| `oil_price` | Brent price, $/bbl (base 75) | comes from extra or protected production |
| `fte_cost` | Loaded cost per FTE, $k/yr (base 140) | comes from saved people time |
| `none` | no scaling | is a fixed saving (contracts, inventory, fines avoided) |

The other keys are scenario levers, not drivers: `realization`, `adoption_delay`, `ramp_years`, `capex_overrun`, `partner_premium`, `discount_rate`, `horizon_end`, `resource_multiplier`. If a result needs a driver that doesn't exist (e.g. gas price), use `none`, and propose the new key in the notes.

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
id,process_id,kind,name,due,unit,baseline,target,value_musd,value_driver
...
```

## Sheet: result_process (only for shared results)
```csv
result_id,process_id,share
...
```

## Sheet: enabler
```csv
id,enabler_group,subcategory,name,start_q,end_q,capex_musd,opex_musd_yr,fte_internal,fte_partner,scalability
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
- **Results**: why these KPIs and milestones, and how the milestones relate to the KPIs (value counted once).
- **Value estimates**: one line per result with value, showing the calculation behind `value_musd`.
- **Cost estimates**: the basis for each enabler's capex, opex and FTE figures.
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
- [ ] `kind` is `kpi` or `milestone`; every KPI has `unit`, `baseline` and `target`; every result has a `due` month.
- [ ] Every result requires at least one enabler. Every new enabler is required by a result, or is a prerequisite of an enabler that is.
- [ ] Value is counted once across a process's KPIs and milestones. A shared result lists its lead process in `result_process`, and the shares are explained.
- [ ] Dates use `YYYYQn` (enablers) or `YYYY-MM` (results), within 2026–2030.
- [ ] There are no dependency cycles. Late results and date conflicts are allowed, but each one is explained in the notes.
- [ ] Every enabler has a `scalability`, and values outside the typical ranges or above 1 are explained.
- [ ] `value_driver` is `oil_price`, `fte_cost` or `none`.
- [ ] Each digital enabler has a people or adoption enabler next to it.
- [ ] Every number can be traced to a line in the notes.

---

## 6. Worked example (Gestión de Mantenimiento, excerpt)

```csv
id,process_id,kind,name,due,unit,baseline,target,value_musd,value_driver
K-P08-01,P08,kpi,Deferred production,2029-12,% of potential,6,2,30,oil_price
M-P08-01,P08,milestone,Downtime < 2%,2028-06,,,,0,none
```

```csv
id,enabler_group,subcategory,name,start_q,end_q,capex_musd,opex_musd_yr,fte_internal,fte_partner,scalability
E-X-08,digital,Work management,Sistema de gestión de trabajos e intervenciones,2027Q3,2028Q2,3.5,0.5,2,4,0.8
```

```csv
result_id,enabler_id,weight
K-P08-01,E-X-08,0.5
K-P08-01,E-X-09,0.4
K-P08-01,E-X-06,0.1
M-P08-01,E-X-08,1
```

```csv
enabler_id,requires_id
E-X-08,E-X-11
```

Notes excerpt:
- K-P08-01 value: (6% − 2%) of 20,000 bbl/d potential × 365 × $75 margin share ≈ $30M/yr (placeholder, to validate).
- M-P08-01 is the step on the way to K-P08-01, so its value is 0: the KPI carries it.
- K-P08-01 requires iROC (E-X-09, live 2029Q4), so it is only ready in 2029Q4; due 2029-12, on time.
- E-X-08 scalability 0.8: configuration and data migration can run in parallel by asset, but field roll-out follows crew rotations.
