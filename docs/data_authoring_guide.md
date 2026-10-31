# Roadmap data authoring guide (for AI agents)

You are helping build a digital transformation roadmap for 2026–2029. The company is moving its processes to an integrated system of **humans, AI agents and robots**. You work through the business processes **one at a time**, and you are the only agent writing this data. Your job is to turn what you learn about that process into rows for the roadmap database, in the exact format below.

Your output is loaded straight into a database and a dashboard. Rows in the wrong format get rejected. Follow the format exactly, and keep your reasoning in the notes section (see [Output format](#output-format)), never in the data rows.

---

## 1. How the model works

```
investment ──► ENABLER ──(weight)──► KPI ──► PROCESS
                  │                    │
           requires other         value in $M/yr
             enablers
```

- A **process** is a business process being transformed, such as Asset maintenance.
- A **KPI** is a measurable result on **one** process, with a baseline, a target and a dollar value when the target is reached.
- An **enabler** is something we invest in: a solution, a dataset, infrastructure, or a people or change initiative. Enablers cost money, expertise and manpower. They don't create value directly. They make better processes possible.
- An **enabler link** says that an enabler helps move a KPI, with a relative weight.
- An **enabler dependency** says that one enabler can't finish before another one is ready. For example, predictive maintenance needs OT/IoT data integration.
- A **milestone** is a visible checkpoint delivered by one enabler.

The dashboard calculates the following. You don't compute any of it, but your numbers drive it:
- **Acceleration scenarios**: each enabler can be shortened by up to its `compressibility`, at a cost premium that grows faster than the time saved.
- **Cost per year**: capex is spread over the build period. People cost is counted during the build, with partner staff at a premium. Opex runs from go-live to the end of the horizon.
- **KPI ready date**: the latest end date across the KPI's enablers and all of their prerequisites.
- **Value per year**: `value_musd` × the share of the target achieved × the driver factor × the adoption ramp after the ready date.
- **Cost allocation**: an enabler's cost is split across KPIs by link weight. Foundation enablers pass their cost on to the KPIs of the enablers built on them.

---

## 2. Tables and field rules

All files are UTF-8 CSV with a header row and comma separators. Use a dot as the decimal point and no thousands separators. Quote any text that contains a comma. Use exactly the columns listed, in the same order. Don't add columns.

### 2.1 `process`

| column | type | rules |
|---|---|---|
| `id` | text | Given to you. Don't invent process IDs. |
| `name` | text | Short name, e.g. `Asset maintenance` |
| `owner` | text | Accountable **role**, never a person's name, e.g. `Head of Maintenance` |
| `visibility` | `public` \| `private` | Almost always `public` |

You normally output **no** process rows. Only output one if you were asked to create or rename the process.

Current processes:

| id | name |
|---|---|
| P1 | Production operations |
| P2 | Asset maintenance |
| P3 | Drilling & well planning |
| P4 | Supply chain & procurement |
| P5 | HSE & compliance |
| P6 | Finance & reporting |

### 2.2 `kpi`

| column | type | rules |
|---|---|---|
| `id` | text | `K-<process>-<nn>`, e.g. `K-P2-01`. Unique. |
| `process_id` | text | Must be a process `id` |
| `name` | text | What is measured, max 45 characters, e.g. `Work-order turnaround` |
| `unit` | text | Unit of baseline and target: `days`, `%`, `$/boe`, `bbl/FTE·yr`, `$M`, `h`, `count`… Use `%` and `$M` exactly as written (the app formats them specially). |
| `baseline` | number | Current value (2025/2026), in `unit` |
| `target` | number | Value expected when the roadmap is fully adopted, in `unit` |
| `target_year` | integer | 2026–2030 |
| `value_musd` | number | **Annual** value in **$ millions** when the target is reached, before any realisation haircut. Can be 0 for KPIs with no value (e.g. pure compliance KPIs), but then explain why in the notes. |
| `value_driver` | text | A config key that scales the value: `oil_price`, `fte_cost`, or `none` (see 2.7) |
| `visibility` | `public` \| `private` | See [section 4](#4-visibility-public-vs-private) |

Rules:
- Use 2 to 6 KPIs per process. Prefer outcome KPIs (turnaround, cost per unit, downtime, safety, throughput per employee) to activity KPIs (number of dashboards, users trained).
- Whether the target is above or below the baseline tells the app which direction counts as an improvement. Make sure it points the right way.
- Estimate `value_musd` as Δ(target − baseline) × volume × unit value. Show this calculation in the notes. Don't count the same benefit twice across KPIs: if one KPI's value is part of another's, count it only once.

### 2.3 `enabler`

| column | type | rules |
|---|---|---|
| `id` | text | `E-<process>-<nn>` for process-specific enablers. `E-X-<nn>` for cross-process foundations (see 3.2). |
| `enabler_group` | text | One of: `people`, `digital`, `data`, `infra` |
| `subcategory` | text | Free text, short. Reuse existing ones when they fit (list below). |
| `name` | text | Max 40 characters, describes the thing being built, e.g. `Predictive maintenance platform` |
| `start_q` | text | `YYYYQn`, e.g. `2027Q1`, from 2026Q1 to 2029Q4 |
| `end_q` | text | `YYYYQn`, the quarter the enabler goes live. Must not be before `start_q`. |
| `capex_musd` | number | One-off investment in $M (licences, hardware, implementation by vendors) |
| `opex_musd_yr` | number | Running cost per year after go-live, in $M |
| `fte_internal` | number | Average internal people (FTE) working on the build: expertise or manpower that is **built or hired internally** |
| `fte_partner` | number | Average FTE from **allies, vendors and contractors** during the build |
| `compressibility` | number 0–0.9 | Largest share of the duration that **more resources** could cut. See 2.3.1. |
| `visibility` | `public` \| `private` | Usually `public` |

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

#### 2.3.1 Compressibility

`compressibility` answers one question: *with unlimited budget and people, how much shorter could this enabler realistically be?* `0.3` means at most 30% shorter.

The app's Sensitivity tab has an **Acceleration** lever. It uses a share of every enabler's compressibility at once and adds a cost premium that grows faster than the time saved, because more people bring more coordination overhead. So you don't need to model the cost of speeding up. Only give the limit.

Typical values:

| kind of enabler | compressibility | why |
|---|---|---|
| Software configuration, cloud setup, automation (RPA) | 0.35–0.45 | parallel teams and more vendors help |
| AI/ML models, digital twins, data integration | 0.25–0.35 | limited by data availability and testing cycles |
| AI agents in operations | 0.2–0.3 | limited by trust building and supervised running |
| Hardware, networks, robots, drones | 0.15–0.25 | procurement lead times, site access, certification |
| Organisation design, training | 0.15–0.3 | people need time to learn |
| Change management, adoption programmes | 0–0.1 | behaviour change cannot be bought faster |
| Regulatory or contractual steps | 0 | fixed external timelines |

Explain any value outside these ranges in the notes.

### 2.4 `enabler_link`

| column | type | rules |
|---|---|---|
| `enabler_id` | text | Must be an enabler `id` |
| `kpi_id` | text | Must be a KPI `id` |
| `weight` | number | Relative contribution, 0 to 1. Weights are **normalised per KPI**, so only the ratios between enablers on the same KPI matter. Prefer weights that add up to 1 per KPI. |

Rules:
- Every KPI needs at least one link.
- Link only the enablers that **directly** move the KPI. Don't link foundations such as cloud or networks just because they are needed. Use a dependency for that (2.5). Foundations get their share of cost automatically.
- An enabler may link to KPIs of other processes, but only when it clearly moves them.

### 2.5 `enabler_dependency`

| column | type | rules |
|---|---|---|
| `enabler_id` | text | The enabler that needs something |
| `requires_id` | text | The enabler it needs |

Rules:
- The `requires_id` enabler's `end_q` should be on or before the dependent enabler's `end_q`. They may overlap in time; the arrow then shows "can't finish before". If the information you have puts a prerequisite later, keep the real dates. The app loads them and shows the conflict in red. Explain it in the notes.
- No cycles: A needs B and B needs A is invalid, and so is any longer loop.
- List only direct prerequisites. If A needs B and B needs C, don't also add A needs C.

### 2.6 `milestone`

| column | type | rules |
|---|---|---|
| `id` | text | `M-<process>-<nn>` |
| `milestone_date` | text | `YYYY-MM` |
| `name` | text | Observable outcome, max 50 characters, e.g. `Predictive maintenance on critical pumps` |
| `enabler_id` | text | The enabler that delivers it |
| `visibility` | `public` \| `private` | |

Use 1 to 3 milestones per process. A milestone is something a manager can check happened, not a project phase like "design complete".

### 2.7 `config` (read only)

Agents don't change the config. Use only these keys as `value_driver`:

| key | meaning | use as driver when the value… |
|---|---|---|
| `oil_price` | Brent price, $/bbl (base 75) | comes from extra or protected production |
| `fte_cost` | Loaded cost per FTE, $k/yr (base 140) | comes from saved people time |
| `none` | no scaling | is a fixed saving (contracts, inventory, fines avoided) |

The other keys are scenario levers, not drivers: `realization`, `adoption_delay`, `ramp_years`, `capex_overrun`, `partner_premium`, `discount_rate`, `horizon_end`. If a KPI needs a driver that doesn't exist (e.g. gas price), use `none`, and propose the new key in the notes.

---

## 3. IDs and shared enablers

### 3.1 ID rules
- IDs are text, case-sensitive, with no spaces.
- Use the prefixes above with a two-digit counter that starts at `01` for each process.
- Never reuse or renumber an existing ID. If an item is dropped, leave its number unused.

### 3.2 Shared foundations
Infrastructure and data foundations (cloud, connectivity, data platform, master data, OT cybersecurity, digital academy) are usually shared by many processes.

1. You will be given the **current enabler catalogue**. Before creating an enabler, check whether an existing one already covers it. If it does, **reuse its ID** in your links and dependencies, and don't output the enabler row again.
2. A new foundation that other processes will also need gets an `E-X-<nn>` ID. Output its row once, from the first process that needs it, and reuse it afterwards.
3. If an existing enabler needs a different cost, date or compressibility because of what you learned, output the full row again with the new values (same ID) and say what changed in the notes under **Changed rows**.

---

## 4. Visibility: public vs private

The dashboard has a public view and a management view. Rows with `visibility = private` are hidden from the public view.

Mark a row **private** when it reveals:
- headcount or FTE reduction, role elimination, or the redeployment of named teams
- labour cost savings that could be read as job cuts
- commercially sensitive targets: production quotas, unit costs, margins, working capital
- anything about contract renegotiation or specific vendors

Keep it **public** when it describes service, safety, speed, quality or environmental results, or the capabilities being built.

When in doubt, choose `private` and explain why in the notes. For example, "barrels per employee" is usually public, but a KPI like "maintenance FTE per asset" is private.

---

## 5. Output format

Reply with exactly these sections, in this order. Include only **new or changed rows**, never the whole database. Leave out a table section if it has no rows.

````markdown
# Process <id> – <name>

## kpi.csv
```csv
id,process_id,name,unit,baseline,target,target_year,value_musd,value_driver,visibility
...
```

## enabler.csv
```csv
id,enabler_group,subcategory,name,start_q,end_q,capex_musd,opex_musd_yr,fte_internal,fte_partner,compressibility,visibility
...
```

## enabler_link.csv
```csv
enabler_id,kpi_id,weight
...
```

## enabler_dependency.csv
```csv
enabler_id,requires_id
...
```

## milestone.csv
```csv
id,milestone_date,name,enabler_id,visibility
...
```

## Notes
- **Process summary**: 3–5 lines on how the process works today and how humans, agents and robots split the work afterwards.
- **Value estimates**: one line per KPI showing the calculation behind `value_musd`.
- **Cost estimates**: the basis for each enabler's capex, opex and FTE figures.
- **Assumptions and sources**: what you were told, what you assumed, and how confident you are (high / medium / low).
- **Reused enablers**: the IDs from the catalogue you linked to.
- **New shared enablers**: any `E-X-nn` rows and which other processes will likely use them.
- **Changed rows**: existing IDs you output again, with what changed and why.
- **Date conflicts**: any prerequisite that goes live after the enabler that needs it, and why the dates are still correct.
- **Open questions**: for the process owner.
````

---

## 6. Checklist before you answer

- [ ] Every column is present, in order, with no extra columns. Numbers have no units, `$` signs or thousands separators.
- [ ] Every `process_id`, `enabler_id`, `kpi_id` and `requires_id` points to a row in your output or in the catalogue you were given.
- [ ] Every KPI has at least one link. Every new enabler has at least one link or is required by an enabler that has one.
- [ ] Dates use `YYYYQn` (enablers) or `YYYY-MM` (milestones), within 2026–2029.
- [ ] There are no dependency cycles. Date conflicts (a prerequisite ending later, or an end before the start) are allowed, but each one is explained under **Date conflicts**.
- [ ] Every enabler has a `compressibility`, and values outside the typical ranges are explained.
- [ ] `value_driver` is `oil_price`, `fte_cost` or `none`.
- [ ] Sensitive rows are `private`.
- [ ] Each digital enabler has a people or adoption enabler next to it.
- [ ] Every number can be traced to a line in the notes.

---

## 7. Worked example (Asset maintenance, excerpt)

```csv
id,process_id,name,unit,baseline,target,target_year,value_musd,value_driver,visibility
K-P2-01,P2,Work-order turnaround,days,18,7,2028,6.4,fte_cost,public
K-P2-02,P2,Maintenance cost per boe,$/boe,3.9,3.1,2029,11.2,none,private
```

```csv
id,enabler_group,subcategory,name,start_q,end_q,capex_musd,opex_musd_yr,fte_internal,fte_partner,compressibility,visibility
E-P2-01,digital,AI / ML,Predictive maintenance platform,2027Q1,2028Q2,6,1,3,5,0.3,public
E-P2-02,people,Training & skills,Reliability engineers upskilling,2027Q2,2028Q2,0.3,0.05,1,1,0.2,public
```

```csv
enabler_id,kpi_id,weight
E-P2-01,K-P2-01,0.6
E-P2-02,K-P2-01,0.4
E-P2-01,K-P2-02,1
```

```csv
enabler_id,requires_id
E-P2-01,E-X-03
E-P2-01,E-X-05
```

```csv
id,milestone_date,name,enabler_id,visibility
M-P2-01,2028-06,Predictive maintenance on critical equipment,E-P2-01,public
```

Notes excerpt:
- K-P2-02 value: (3.9 − 3.1) $/boe × 14 M boe/yr = $11.2M/yr. It is private because the saving comes partly from contractor reductions.
- E-P2-01 depends on the shared data platform (E-X-03) and OT/IoT integration (E-X-05) from the catalogue.
