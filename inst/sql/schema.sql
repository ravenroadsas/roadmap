-- Roadmap data model v2 (portable SQL: DuckDB in development, SQL Server / Postgres later).
-- Statements are separated by ';' and executed one by one by db_init().
-- Logic: enablers make results possible; results generate value for processes.

CREATE TABLE IF NOT EXISTS process (
  id          VARCHAR PRIMARY KEY,
  name        VARCHAR NOT NULL,
  owner       VARCHAR
);

CREATE TABLE IF NOT EXISTS result (                -- one category of tangible result
  id            VARCHAR PRIMARY KEY,
  process_id    VARCHAR NOT NULL REFERENCES process(id),   -- lead process
  name          VARCHAR NOT NULL,
  due           VARCHAR NOT NULL,                  -- YYYY-MM
  value_musd    DOUBLE DEFAULT 0,                  -- annual value once achieved, $M
  value_driver  VARCHAR NOT NULL DEFAULT 'none',   -- config key that scales value, or 'none'
  unit          VARCHAR,                           -- optional measure
  baseline      DOUBLE,
  target        DOUBLE
);

CREATE TABLE IF NOT EXISTS result_process (        -- optional: result shared by several processes
  result_id   VARCHAR NOT NULL REFERENCES result(id),
  process_id  VARCHAR NOT NULL REFERENCES process(id),
  share       DOUBLE NOT NULL DEFAULT 1,
  PRIMARY KEY (result_id, process_id)
);

CREATE TABLE IF NOT EXISTS concept (               -- group > subgroup > concept > enabler
  id             VARCHAR PRIMARY KEY,
  name           VARCHAR NOT NULL,
  enabler_group  VARCHAR NOT NULL,                 -- people | digital | data | infra
  subgroup       VARCHAR,
  fte_internal   DOUBLE DEFAULT 0,                 -- average FTE over the concept's build window
  fte_partner    DOUBLE DEFAULT 0
);

CREATE TABLE IF NOT EXISTS enabler (
  id             VARCHAR PRIMARY KEY,
  concept_id     VARCHAR NOT NULL REFERENCES concept(id),
  name           VARCHAR NOT NULL,
  start_q        VARCHAR NOT NULL,                 -- YYYYQn
  end_q          VARCHAR NOT NULL,
  capex_musd     DOUBLE DEFAULT 0,
  opex_musd_yr   DOUBLE DEFAULT 0,
  cost_basis     VARCHAR NOT NULL DEFAULT 'fixed', -- fixed | per_process
  scalability    DOUBLE DEFAULT 0                  -- 0 rigid, 1 linear, >1 better than linear
);

CREATE TABLE IF NOT EXISTS result_enabler (        -- result requires enabler
  result_id   VARCHAR NOT NULL REFERENCES result(id),
  enabler_id  VARCHAR NOT NULL REFERENCES enabler(id),
  weight      DOUBLE NOT NULL DEFAULT 1,
  PRIMARY KEY (result_id, enabler_id)
);

CREATE TABLE IF NOT EXISTS enabler_dependency (
  enabler_id   VARCHAR NOT NULL REFERENCES enabler(id),
  requires_id  VARCHAR NOT NULL REFERENCES enabler(id),
  PRIMARY KEY (enabler_id, requires_id)
);
