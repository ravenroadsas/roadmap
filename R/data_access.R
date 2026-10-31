# All database interaction lives in this file.
# Development: DuckDB (file or in-memory), seeded from inst/extdata/*.csv.
# Enterprise: swap db_connect() for an odbc / RPostgres connection; the rest
# uses plain DBI + portable SQL, so callers do not change.

ROADMAP_TABLES <- c("process", "kpi", "enabler", "enabler_link",
                    "enabler_dependency", "milestone")

#' Open a database connection
#'
#' Uses DuckDB when available, otherwise RSQLite (same DBI interface).
#' The path comes from the `ROADMAP_DB_PATH` environment variable; empty
#' means an in-memory database.
#' @param path database file path or ":memory:".
#' @param driver "duckdb", "sqlite" or "auto".
db_connect <- function(path = Sys.getenv("ROADMAP_DB_PATH", ":memory:"),
                       driver = Sys.getenv("ROADMAP_DB_DRIVER", "auto")) {
  if (identical(path, "")) path <- ":memory:"
  if (driver == "auto") {
    driver <- if (requireNamespace("duckdb", quietly = TRUE)) "duckdb" else "sqlite"
  }
  switch(driver,
    duckdb = DBI::dbConnect(duckdb::duckdb(), dbdir = path),
    sqlite = DBI::dbConnect(RSQLite::SQLite(), dbname = path),
    stop("Unknown database driver: ", driver)
  )
}

db_disconnect <- function(con) {
  if (inherits(con, "duckdb_connection")) {
    DBI::dbDisconnect(con, shutdown = TRUE)
  } else {
    DBI::dbDisconnect(con)
  }
}

#' Split a SQL script into statements (drops comments and blanks)
sql_statements <- function(path) {
  txt <- readLines(path, warn = FALSE, encoding = "UTF-8")
  txt <- sub("--.*$", "", txt)
  stmts <- strsplit(paste(txt, collapse = "\n"), ";", fixed = TRUE)[[1]]
  stmts <- trimws(stmts)
  stmts[nzchar(stmts)]
}

#' Create the schema and seed empty tables from CSV files
#' @param con DBI connection.
#' @param seed_dir folder with one `<table>.csv` per table.
db_init <- function(con, seed_dir = app_sys("extdata")) {
  for (s in sql_statements(app_sys("sql", "schema.sql"))) DBI::dbExecute(con, s)
  db_migrate(con)
  for (tbl in ROADMAP_TABLES) {
    n <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
    f <- file.path(seed_dir, paste0(tbl, ".csv"))
    if (n == 0 && file.exists(f)) {
      df <- utils::read.csv(f, stringsAsFactors = FALSE, encoding = "UTF-8",
                            check.names = FALSE)
      DBI::dbAppendTable(con, tbl, df)
    }
  }
  invisible(con)
}

#' Add columns introduced after a database file was created
db_migrate <- function(con) {
  # scalability replaces the short-lived compressibility column (different
  # meaning, so values are not carried over: 0 = rigid until filled in)
  if (!"scalability" %in% DBI::dbListFields(con, "enabler")) {
    DBI::dbExecute(con, "ALTER TABLE enabler ADD COLUMN scalability DOUBLE DEFAULT 0")
  }
  invisible(con)
}

#' Read every roadmap table into a named list of data frames
db_read_all <- function(con) {
  out <- lapply(ROADMAP_TABLES, function(t) {
    DBI::dbGetQuery(con, paste0("SELECT * FROM ", t, " ORDER BY 1"))
  })
  names(out) <- ROADMAP_TABLES
  # keep the enabler order defined in the source (group, then start)
  grp_order <- c("people", "digital", "data", "infra")
  e <- out$enabler
  out$enabler <- e[order(match(e$enabler_group, grp_order), e$start_q, e$id), ]
  rownames(out$enabler) <- NULL
  out
}

#' Table metadata for the data-model tab: columns and row counts
db_table_info <- function(con) {
  lapply(stats::setNames(ROADMAP_TABLES, ROADMAP_TABLES), function(t) {
    list(
      fields = DBI::dbListFields(con, t),
      rows = DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", t))$n
    )
  })
}

#' Connect, initialise and load all data in one step
load_roadmap_data <- function(path = Sys.getenv("ROADMAP_DB_PATH", ":memory:")) {
  con <- db_connect(path)
  on.exit(db_disconnect(con))
  db_init(con)
  data <- db_read_all(con)
  attr(data, "table_info") <- db_table_info(con)
  data
}

app_sys <- function(...) {
  p <- system.file(..., package = "dtroadmap")
  if (!nzchar(p)) p <- file.path(dev_root(), "inst", ...)  # sourced / load_all
  p
}

dev_root <- function() getOption("dtroadmap.root", ".")
