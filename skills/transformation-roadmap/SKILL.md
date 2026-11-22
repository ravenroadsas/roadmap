---
name: transformation-roadmap
description: Build, extend, review or refine a digital transformation roadmap as structured data (processes with digital maturity M1-M5, milestones, metrics with impact curves, concepts with internal / part-time / partner people, enablers, dependencies) in the roadmap workbook format read by the roadmap dashboard. Use when asked to plan a transformation, assess a process's digital maturity, turn process interviews or documents into roadmap rows, estimate the value, cost and people of transformation initiatives, identify the enablers (people, digital, data, infrastructure) a milestone needs, check a roadmap workbook, or act on the dashboard's results (late milestones, frontier, resources, audit export).
---

# Digital transformation roadmap

You help build a digital transformation roadmap. A roadmap here is not a slide: it is a small, connected data model that a dashboard reads to show **what** is built, **when**, for **what value**, **what depends on what**, and which **digital maturity** targets are worth pursuing. Your job is to reason from the evidence about one business process at a time and express the result as rows in the exact format below, with the reasoning kept in notes.

> **Avoid bias.** Derive every maturity level, milestone, metric, enabler and number from the material you are given about the organisation and its processes. The example at the end shows the *format*, not the content: do not reuse its names, milestones, metrics, values or dates. Do not assume an industry, a technology vendor or a "standard" list of initiatives. If the evidence is thin, say so and ask, rather than filling gaps with generic transformation programmes.

---

## 0. How to work

Pick the mode that matches the request; ask for what is missing (section 4) before producing rows.

| Mode | When | What you do |
|---|---|---|
| **New roadmap** | No workbook yet | Agree the list of processes, owners and the shared foundations first (one short round), then build process by process. Start the catalogue with the four proposed curves. |
| **Extend** | A workbook exists; a new process or more detail | Work on one process against the current catalogue (the latest exported workbook); reuse its concepts and enablers; output only new or changed rows. |
| **Review** | "Check this workbook" | Run every check in section 7 and the anti-patterns in section 5.2; report problems by sheet, ID and rule, with the fix; do not silently rewrite. |
| **Refine** | Results from the dashboard or its audit export | Read the findings (section 8) and propose changes: dates, levels, links, targets, costs — each with the reason. |

Always: one process at a time, evidence before numbers, every number traceable to a note, placeholders flagged.

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

You do not compute these, but your numbers drive them, so keep them consistent.

| Quantity | Calculation |
|---|---|
| **Targets** | Each process's target, kept between its current level and M5. In the dashboard the user changes targets per process (Scenario view); `target_level` is the base case. |
| **Scope** | A milestone is pursued when `level ≤ target` of its process. Milestones above the target are out (no cost, no value). |
| **Investment** | The enablers the pursued milestones require, plus their foundations (all prerequisites). Each needed enabler costs in full (`fixed`) or × (processes needing it / processes it serves at any level) ^ `scalability` (`per_process`). |
| **Cost per year** | capex spread evenly over the build; people during the build: internal FTE × `fte_cost` + SME FTE × `fte_cost` × `sme_cost_factor` + partner FTE × `fte_cost` × (1 + `partner_premium`) ($k → $M); opex from go-live to the horizon; everything × `cost_multiplier`. |
| **Ready date** | A milestone is ready when its last required enabler or foundation goes live; **late** when after the end of its due month (allowed, shown in red). A process reaches level L when its milestones above the current level and up to L are ready; a level with no milestone is reached with the next one up. |
| **Metric steps** | A metric climbs through the levels of its linked, pursued milestones; it reaches level L when every linked milestone up to L is ready. Each step adds share = (curve(L) − curve(previous)) / (curve(M5) − curve(current)). Staying at the current level gives 0; reaching M5 gives 100%. |
| **Value per year** | `value_musd` × `realization` × driver factor (scenario price or FTE cost ÷ base) × Σ steps (share × adoption ramp). The ramp goes linearly from 0 at the step date to 1 after `adoption_years`, averaged over the quarters of each year. |
| **NPV, ROI, payback** | Net = value − cost per year, from the first enabler start year to `horizon_end`. NPV discounts yearly net by 1 / (1 + `discount_rate`)^(year − start year). ROI = (total value − total cost) / total cost. Payback = first year the cumulative net is ≥ 0. |
| **Acceleration** | Optional: more resources r shorten an enabler to duration × r^(−scalability) (start fixed) and scale its effort by r^(1 − scalability); the app can solve r per enabler so that pursued milestones meet their due dates. |
| **Frontier** | Every combination of targets (each process from current to M5) is evaluated; the efficient frontier shows the best NPV for each investment, or the best ROI for investing at least that much. |
| **Resources** | Cash per year by type, and FTE per year: internal team, SMEs (FTE-equivalent), partners. |
| **Checks** | Late milestones; a prerequisite going live after the enabler that needs it; an enabler whose level is above a milestone that requires it. All shown, none blocking. |

### 1.2 Maturity levels

| Level | Key trait | Looks like |
|---|---|---|
| **M1 Manual** | Dependence on human intervention | Manual activities, scattered information, isolated tools; decisions on people's judgement. |
| **M2 Assisted** | Digital support to execution | Tools to execute, record and follow up; decisions stay human; manual steps between systems. |
| **M3 Integrated** | End-to-end integration and traceability | Standard workflows connected end to end; structured, traceable data exchange; integrated performance view. |
| **M4 Automated** | Automation and data-driven decisions | Workflows, rules, algorithms and models execute, validate, detect deviations, recommend or decide; people handle exceptions. |
| **M5 Adaptive** | Anticipation and continuous optimisation | Real-time data, advanced analytics and AI anticipate and adjust execution, learning continuously within set limits. |

### 1.3 Assessing the current level

Score the process on six dimensions, each from M1 to M5, from evidence (interviews, documents, system landscape). Then set `current_level` to the level most dimensions support (the median is a good default). As a sanity rule, do not rate a process more than one level above its data dimension (D3): automation and AI on unreliable data do not hold.

| Dimension | M1 | M2 | M3 | M4 | M5 |
|---|---|---|---|---|---|
| **D1 Digitalisation of activities** | paper, local files; depends on individuals | apps and forms support tasks; re-typing and parallel records remain | standard digital tools in defined flows; owners, states and records traceable end to end | much of the flow runs automatically (workflows, smart forms, rules); people handle exceptions and approvals | execution adjusts to context; sequences optimised continuously within limits |
| **D2 Integration and architecture** | isolated tools; exchange by email or files | tools per activity; partial integration; manual loads and reconciliations | key systems and actors exchange data through standard interfaces; flow visible end to end | systems orchestrated to run processes and events; integrations trigger validations, alerts and actions | flexible, scalable interoperability that adapts to demand and context, resilient and controlled |
| **D3 Data management and quality** | scattered, manual, inconsistent definitions | digitised records, basic controls; duplicates and manual reconciliation | defined data, owners, sources and systematic quality controls; integrated, traceable view | monitored with indicators and automated controls; anomalies detected; recurring analytics | operational and contextual data used in time to anticipate; quality mechanisms learn; lineage and trust sustained |
| **D4 Automation** | tasks, controls, calculations and transfers by hand | macros or scripts for specific tasks | repetitive tasks and hand-offs automated within integrated flows; documented rules | rules, workflows, RPA, algorithms or models run sequences and controls with monitoring | automation adjusts to results and conditions; orchestration optimises resources within safety and authorisation limits |
| **D5 Intelligence and decisions** | experience and manual review | reports and descriptive indicators; retrospective | consistent indicators and integrated views; structured root-cause analysis | advanced analytics or predictive models recommend actions; some routine decisions automated within approved parameters | predictive / prescriptive models and optimisation; scenarios evaluated and actions adjusted continuously, explainable and supervised |
| **D6 Adaptability and optimisation** | reactive, occasional improvement | periodic review; manual improvements | measured with indicators, owners and review routines; formal improvement cycle | continuous monitoring anticipates problems and triggers corrective or preventive actions; effects verified | learns from results and context; adjusts parameters, rules or recommendations continuously and under control |

Questions that separate levels quickly: *How does information move between steps (people, files, interfaces, events)? Who decides, with what data, how fast? What runs without a person? What happens when conditions change?*

### 1.4 Setting the target

The target is the highest level worth reaching given expected value, technical, economic and operational feasibility, and risk — not M5 by default. Give each process milestones for every realistic level above its current one, so the frontier can price each step; the user then chooses targets with the Scenario and Frontier views. Say in the notes which levels you consider unrealistic and why.

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

One Excel workbook, **one sheet per table**, column names in row 1 (lower case). Sheets: `process`, `milestone`, `metric`, `metric_milestone`, `curve` (optional: the four proposed curves are used if it is missing), `concept`, `enabler`, `milestone_enabler`, `enabler_dependency`, plus `config` (assumptions, read only: never output config rows), and the reference sheets `README` (every column) and `levels` (M1–M5), which the app does not read.

General rules:
- Exactly the listed column names; order does not matter; extra columns are ignored.
- One row per record, no merged cells. Numbers are plain numbers: no units, `$` or thousands separators.
- Quarters are text `YYYYQn`; months are text `YYYY-MM`; levels are `M1`…`M5`.
- IDs are text, case-sensitive, no spaces, never reused or renumbered.
- Levels may be written `M3`, `m3` or `3`. Months accept `2027-3`. Fully empty rows are skipped.
- A `source` column (where each row comes from) is recommended on every sheet: the app ignores it, reviewers rely on it. Mark placeholder values clearly (the convention is an amber cell fill) and say so in the notes.

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
| `value_musd` | number | **Annual** $M from the current level to M5 at full adoption, before realisation; 0 if none |
| `value_driver` | text | `oil_price` (value moves with the commodity price lever), `fte_cost` (saved people time, moves with the loaded FTE cost) or `none` (fixed saving). Default `none`. |
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

Proposed curves (shipped in the template):

| id | M1·M2·M3·M4·M5 | use when |
|---|---|---|
| `concave` | 0·45·75·92·100 | most of the gain comes with the first steps (digitising, assisting); each further level adds less. Typical: production, availability, losses. |
| `threshold` | 0·5·15·55·100 | little gain until work is automated; then large. Typical: man-hours saved, headcount ratios, throughput per person. |
| `linear` | 0·25·50·75·100 | each level adds the same; use when there is no evidence for a shape. |
| `s_curve` | 0·10·45·85·100 | gain concentrates on integration (M3) and automation (M4). Typical: cycle times, non-productive time, decision quality. |

A new curve is allowed when none fits: add a `curve` row (values 0–100, never decreasing, `m5` normally 100) and justify it in the notes.

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

People rules: someone fully on the project is `fte_internal`; someone who keeps their job and gives part of their time is `fte_sme` (people × share of time); external people time is `fte_partner`. The app spreads a concept's FTE over its enablers in proportion to their build duration (enabler FTE = concept FTE × window / Σ durations), so total effort (FTE × window) is kept. Vendor implementation paid as a contract goes in `capex_musd`, not in `fte_partner` — never both.

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

### 3.11 `config` sheet (read only)

Set by the roadmap team; never output rows. Know what each key does:

| key | role | meaning |
|---|---|---|
| `adoption_years` | lever | time from a step being reached to its full value (linear ramp) |
| `oil_price` | lever | commodity price; scales metrics with `value_driver = oil_price` (scenario ÷ base) |
| `cost_multiplier` | lever | scales every cost (capex, people, opex) |
| `resource_multiplier` | lever | extra resources on every scalable enabler (acceleration) |
| `realization` | fixed | share of the target value actually achieved |
| `fte_cost` | fixed | loaded cost per FTE, $k per year; also scales metrics with `value_driver = fte_cost` |
| `partner_premium` | fixed | partner cost above internal FTE |
| `sme_cost_factor` | fixed, optional | share of part-time SME time charged (1 = at the FTE cost, 0 = absorbed by the business; default 1) |
| `discount_rate` | fixed | rate for NPV |
| `horizon_end` | fixed | last year counted in cost and value |

If a metric needs a driver that does not exist (e.g. a different commodity), use `none` and propose the key in the notes.

---

## 4. What to ask for

Before producing rows for a process, make sure you have (or ask for) the following. Missing items become explicit assumptions with low confidence, never silent defaults.

- **Process**: purpose, main steps, owner role, sites or teams covered, volumes (cases, assets, orders, units… per year).
- **People and cost today**: who does the work, how many FTE or hours, loaded cost, overtime, contractors.
- **Systems and data**: tools used per step, how data moves (files, re-typing, interfaces), data quality issues, real-time sources.
- **Performance**: the measures management follows, with today's values (baselines), and the best achievable values (benchmarks, best periods, targets).
- **Pain points and losses**: where time, cost, risk or production is lost, with an order of magnitude.
- **Unit values**: price or margin per unit, cost per hour, cost of downtime, cost of capital — whatever turns the measures into money.
- **Constraints**: regulation, safety, contracts, procurement lead times, union or organisational limits, budget windows.
- **Existing initiatives**: projects already running or approved (to reuse as enablers or foundations, not duplicate).
- **Ambition**: what management expects, by when.

---

## 5. How to build the roadmap

Work **one process at a time**, always against the current catalogue so shared items are reused, not duplicated.

1. **Understand the process** from the material given: how the work is done, where time, cost and risk go, and how humans, software, agents and machines would split the work at each level.
2. **Assess the current level** with the rubric (1.3), and propose a **target** (1.4).
3. **Define the metrics** (1–4 per process): measured outcomes with baseline today and target at M5. Value each (5.1). **Count value once.** Choose the impact curve that matches how the metric responds to maturity.
4. **Define milestones per level**, from the level above the current one up to what is realistic (usually M5). Each is an observable step change with a due date; one to three per level.
5. **Link milestones to metrics**: which milestones move which metric (several can converge on one; a milestone can move several metrics). A milestone that moves no metric must still be needed (e.g. a compliance step) — say why.
6. **Find the enablers per milestone**, group by group: the *digital* solution, the *data* it needs, the *infra* under that data, and the *people* change that makes it stick. Set each enabler's level; it must not exceed the level of a milestone that requires it. List only direct requirements; reach deeper foundations through dependencies.
7. **Reuse before creating**: search the catalogue for an existing enabler or concept. New cross-process foundations get `E-X-<nn>`, written once.
8. **Group into concepts and plan people** (internal team, SMEs, partners); schedule, cost, cost basis and scalability (5.1), each traceable to a note.
9. **Check the chain** for each level: from value down to the deepest foundation. Keep real dates even if a milestone is late, and explain the gap.
10. **Write the output** (section 6) and run the checklist (section 7).

### 5.1 Estimating

- **Value of a metric** (annual, current level → M5, at full adoption): Δ(target − baseline) × volume × unit value. Typical forms:
  - production or availability: Δ% × potential volume × days × margin or price (driver `oil_price` when it follows the commodity price);
  - time saved: Δ hours per case × cases × loaded hourly cost (driver `fte_cost`), or Δ FTE × loaded FTE cost;
  - cost avoided: Δ cost per unit × units (driver `none`);
  - working capital: Δ capital × cost of capital (driver `none`).
  Show the inputs in the notes. If the value of a metric is already counted in another, set 0 on one of them.
- **Capex**: vendor quotes, comparable projects, or bottom-up (licences + hardware + implementation). **Opex**: licences, support, cloud and hosting, maintenance per year after go-live.
- **People**: think in roles × share of time × duration, then express as average FTE over the concept's window: dedicated team (`fte_internal`), part-time experts (`fte_sme`), partners (`fte_partner`).
- **Durations**: builds usually take 2 to 8 quarters; split anything longer into phases linked by a dependency. Prerequisites go live on or before what needs them.
- **Due dates**: the business commitment, not the enabler dates; let the dashboard show lateness.
- **Cost basis**: `per_process` only when cost really grows with the processes covered (training per team, roll-out per site).
- **Confidence**: give high / medium / low per number in the notes; low-confidence numbers are placeholders.

### 5.2 Anti-patterns
- Copying a generic "transformation programme" instead of deriving enablers from the process evidence.
- Assigning levels by technology hype: an AI tool on scattered data does not make a process M4.
- A milestone that is really an activity ("deploy tool X"): milestones are step changes; tools are enablers.
- Enablers of a higher level than the milestones that need them; milestones at or below the current level.
- Digital enablers with no data foundation or no people/adoption enabler.
- The same benefit counted in two metrics; the same cost in capex and partner FTE; the same person in two FTE columns.
- A metric with no milestone, or a curve chosen without a reason.
- Listing foundations directly on milestones (they come through dependencies).
- Adjusting due dates to hide lateness; inventing process IDs; reusing an ID for something else.

---

## 6. Output format

Output **only new or changed rows**, never the whole workbook. Changed rows repeat the full row with the same ID and replace it.

- If you can create files: an `.xlsx` with the same sheet names and columns; omit sheets with no rows; add a `source` column.
- Otherwise: one CSV block per sheet, titled with the sheet name; quote text containing commas.

Then the **notes**, in Markdown:

- **Maturity assessment** — the six dimensions today (score and evidence), and why the target.
- **Process summary** — today, and the human / digital / agent / machine split at each level.
- **Milestones and levels** — why each milestone sits at its level; levels judged unrealistic.
- **Metrics** — value calculation for each, its driver, and why its curve.
- **Cost and people estimates** — basis for each capex, opex, concept FTE (internal, SME, partner), every `per_process` choice and each enabler level.
- **Scalability** — values outside the typical range, and every value above 1, justified.
- **Assumptions and sources** — what was given, what was assumed, confidence (high / medium / low), placeholders.
- **Reused and new shared enablers**, **changed rows**, **late milestones and date conflicts**, **open questions** for the process owner.

---

## 7. Checks

The app refuses a workbook with any **blocking** problem and lists them all (sheet, column, row). **Warnings** load and are shown in red. Check both before answering.

**Blocking**
- A required sheet or column is missing; a required value is empty; a duplicate ID or duplicate link.
- A value of the wrong type: number, quarter `YYYYQn`, month `YYYY-MM`, level `M1`–`M5`.
- `current_level` above `target_level`.
- A metric with only one of baseline / target; a `value_driver` other than `oil_price`, `fte_cost`, `none`; an unknown `curve_id`.
- A curve with values outside 0–100 or decreasing.
- `enabler_group` not in `people`, `digital`, `data`, `infra`; `cost_basis` not `fixed` or `per_process`.
- A reference to an unknown process, milestone, metric, concept or enabler.
- A milestone that requires no enabler; a metric moved by no milestone.
- A dependency cycle.
- An empty `process`, `milestone`, `metric`, `metric_milestone`, `concept`, `enabler` or `milestone_enabler` sheet.

**Warnings (allowed, explain them)**
- A milestone ready after its due month.
- A prerequisite going live after the enabler that needs it; an enabler ending before it starts.
- An enabler whose level is above a milestone that requires it.

**Checklist**
- [ ] Column names exactly as listed; numbers without units; dates `YYYYQn` / `YYYY-MM`; levels `M1`–`M5`.
- [ ] Every reference points to a row in the output or the catalogue.
- [ ] Each process has `current_level` ≤ `target_level` and milestones for the realistic levels above its current one.
- [ ] Every milestone has a level, a due month and at least one required enabler; no enabler is above a milestone that requires it.
- [ ] Every metric has a value, a driver, a curve and at least one milestone; a measure has both baseline and target (at M5).
- [ ] Every enabler has a concept, a level, a cost basis and a scalability; digital enablers have data foundations and a people/adoption enabler.
- [ ] Value counted once; no person or cost counted twice; no dependency cycles; only direct prerequisites listed.
- [ ] Every number traces to a line in the notes; placeholders are flagged; nothing was taken from the example below.

---

## 8. Reading the results and refining

The dashboard has five views; the user may paste results or send the audit export (Scenario → export detail, an Excel with About, Cashflow, Assumptions, Targets, Value_by_metric, Value_steps, Value_by_year, Cost_by_enabler, Cost_by_year, Milestones, Resources).

| Finding | Where | What to propose |
|---|---|---|
| Late milestone | Roadmap (red), Milestones sheet | check the critical enabler; start it earlier, split it, accelerate it (scalability), or confirm the due date is a stretch and say so |
| Late dependency | Roadmap (red arrow) | move the prerequisite earlier or the dependent later; check the dependency is real |
| Level warning | Method (level checks) | lower the enabler's level, raise the milestone's, or split the enabler |
| A level that costs more than it returns | Frontier, Scenario by process | question its value estimate and curve, its costs, or recommend a lower target |
| Base case below the frontier | Frontier | point to the frontier portfolio with similar investment and higher NPV, and the targets that differ |
| Peaks in cash or people | Resources | shift start dates of non-critical enablers, rebalance internal team vs partners |
| A metric with little value reached | Scenario, Value_by_metric | check its curve and which milestones move it; a missing link is common |
| An enabler needed by one milestone only and expensive | Cost_by_enabler | challenge whether it is needed at that level, or whether it serves other processes |

---

## 9. Example (format only — fictitious)

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
