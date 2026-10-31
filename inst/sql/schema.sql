-- Roadmap data model (portable SQL: DuckDB in development, SQL Server / Postgres later).
-- Statements are separated by ';' and executed one by one by db_init().

CREATE TABLE IF NOT EXISTS process (
  id          VARCHAR PRIMARY KEY,
  name        VARCHAR NOT NULL,
  owner       VARCHAR,
  visibility  VARCHAR NOT NULL DEFAULT 'public'   -- public | private
);

CREATE TABLE IF NOT EXISTS kpi (
  id            VARCHAR PRIMARY KEY,
  process_id    VARCHAR NOT NULL REFERENCES process(id),
  name          VARCHAR NOT NULL,
  unit          VARCHAR,
  baseline      DOUBLE,
  target        DOUBLE,
  target_year   INTEGER,
  value_musd    DOUBLE,                            -- annual value at full target, $M
  value_driver  VARCHAR NOT NULL DEFAULT 'none',   -- config key that scales value, or 'none'
  visibility    VARCHAR NOT NULL DEFAULT 'public'
);

CREATE TABLE IF NOT EXISTS enabler (
  id             VARCHAR PRIMARY KEY,
  enabler_group  VARCHAR NOT NULL,                 -- people | digital | data | infra
  subcategory    VARCHAR,
  name           VARCHAR NOT NULL,
  start_q        VARCHAR NOT NULL,                 -- YYYYQn
  end_q          VARCHAR NOT NULL,
  capex_musd     DOUBLE DEFAULT 0,
  opex_musd_yr   DOUBLE DEFAULT 0,
  fte_internal   DOUBLE DEFAULT 0,                 -- expertise / manpower built internally
  fte_partner    DOUBLE DEFAULT 0,                 -- allies and contractors
  compressibility DOUBLE DEFAULT 0,                -- max share of duration that more resources can cut (0-0.9)
  visibility     VARCHAR NOT NULL DEFAULT 'public'
);

CREATE TABLE IF NOT EXISTS enabler_link (
  enabler_id  VARCHAR NOT NULL REFERENCES enabler(id),
  kpi_id      VARCHAR NOT NULL REFERENCES kpi(id),
  weight      DOUBLE NOT NULL DEFAULT 1,
  PRIMARY KEY (enabler_id, kpi_id)
);

CREATE TABLE IF NOT EXISTS enabler_dependency (
  enabler_id   VARCHAR NOT NULL REFERENCES enabler(id),
  requires_id  VARCHAR NOT NULL REFERENCES enabler(id),
  PRIMARY KEY (enabler_id, requires_id)
);

CREATE TABLE IF NOT EXISTS milestone (
  id              VARCHAR PRIMARY KEY,
  milestone_date  VARCHAR NOT NULL,                -- YYYY-MM
  name            VARCHAR NOT NULL,
  enabler_id      VARCHAR REFERENCES enabler(id),
  visibility      VARCHAR NOT NULL DEFAULT 'public'
);
