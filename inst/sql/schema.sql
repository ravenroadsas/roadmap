-- Roadmap data model v3 (portable SQL: DuckDB in development, SQL Server / Postgres later).
-- Statements are separated by ';' and executed one by one by db_init().
-- Logic: investment builds enablers; enablers and the process's target
-- digital maturity (M1-M5) make milestones possible; milestones move
-- metrics up their impact curve; metrics create value.

CREATE TABLE IF NOT EXISTS process (
  id             VARCHAR PRIMARY KEY,
  name           VARCHAR NOT NULL,
  owner          VARCHAR,
  current_level  INTEGER NOT NULL,                 -- 1..5 (M1 manual .. M5 adaptive)
  target_level   INTEGER NOT NULL                  -- base-case target
);

CREATE TABLE IF NOT EXISTS milestone (             -- step change on the way to a maturity level
  id          VARCHAR PRIMARY KEY,
  process_id  VARCHAR NOT NULL REFERENCES process(id),
  name        VARCHAR NOT NULL,
  due         VARCHAR NOT NULL,                    -- YYYY-MM
  level       INTEGER NOT NULL                     -- in scope when process target >= level
);

CREATE TABLE IF NOT EXISTS curve (                 -- % of impact reached at each level
  id           VARCHAR PRIMARY KEY,
  name         VARCHAR NOT NULL,
  m1           DOUBLE NOT NULL,
  m2           DOUBLE NOT NULL,
  m3           DOUBLE NOT NULL,
  m4           DOUBLE NOT NULL,
  m5           DOUBLE NOT NULL,
  description  VARCHAR
);

CREATE TABLE IF NOT EXISTS metric (                -- measured outcome that creates value
  id            VARCHAR PRIMARY KEY,
  process_id    VARCHAR NOT NULL REFERENCES process(id),
  name          VARCHAR NOT NULL,
  unit          VARCHAR,
  baseline      DOUBLE,                            -- today
  target        DOUBLE,                            -- at full impact (M5)
  value_musd    DOUBLE DEFAULT 0,                  -- annual value, current level -> M5
  value_driver  VARCHAR NOT NULL DEFAULT 'none',
  curve_id      VARCHAR NOT NULL REFERENCES curve(id)
);

CREATE TABLE IF NOT EXISTS metric_milestone (      -- milestones that move a metric
  metric_id     VARCHAR NOT NULL REFERENCES metric(id),
  milestone_id  VARCHAR NOT NULL REFERENCES milestone(id),
  PRIMARY KEY (metric_id, milestone_id)
);

CREATE TABLE IF NOT EXISTS concept (               -- group > subgroup > concept > enabler
  id             VARCHAR PRIMARY KEY,
  name           VARCHAR NOT NULL,
  enabler_group  VARCHAR NOT NULL,                 -- people | digital | data | infra
  subgroup       VARCHAR,
  fte_internal   DOUBLE DEFAULT 0,                 -- dedicated internal team, average FTE over the build window
  fte_sme        DOUBLE DEFAULT 0,                 -- part-time SMEs and others, FTE-equivalent
  fte_partner    DOUBLE DEFAULT 0                  -- partners / contractors
);

CREATE TABLE IF NOT EXISTS enabler (
  id             VARCHAR PRIMARY KEY,
  concept_id     VARCHAR NOT NULL REFERENCES concept(id),
  name           VARCHAR NOT NULL,
  level          INTEGER NOT NULL,                 -- maturity level it enables
  start_q        VARCHAR NOT NULL,                 -- YYYYQn
  end_q          VARCHAR NOT NULL,
  capex_musd     DOUBLE DEFAULT 0,
  opex_musd_yr   DOUBLE DEFAULT 0,
  cost_basis     VARCHAR NOT NULL DEFAULT 'fixed', -- fixed | per_process
  scalability    DOUBLE DEFAULT 0                  -- 0 rigid, 1 linear, >1 better than linear
);

CREATE TABLE IF NOT EXISTS milestone_enabler (     -- milestone requires enabler
  milestone_id  VARCHAR NOT NULL REFERENCES milestone(id),
  enabler_id    VARCHAR NOT NULL REFERENCES enabler(id),
  weight        DOUBLE NOT NULL DEFAULT 1,
  PRIMARY KEY (milestone_id, enabler_id)
);

CREATE TABLE IF NOT EXISTS enabler_dependency (
  enabler_id   VARCHAR NOT NULL REFERENCES enabler(id),
  requires_id  VARCHAR NOT NULL REFERENCES enabler(id),
  PRIMARY KEY (enabler_id, requires_id)
);
