# All data interaction lives in this file.
# Input: an Excel workbook with one sheet per table (ROADMAP_INPUT_XLSX,
# default inst/extdata/roadmap_input.xlsx). It is the source of truth: at
# startup it is validated and loaded into the database, replacing its content.
# Development: DuckDB (file or in-memory).
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

#' Create the schema (tables are filled by db_import())
db_init <- function(con) {
  for (s in sql_statements(app_sys("sql", "schema.sql"))) DBI::dbExecute(con, s)
  db_migrate(con)
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

#' Replace the content of every roadmap table
#' @param tables named list of data frames (from read_input_excel()).
db_import <- function(con, tables) {
  DBI::dbWithTransaction(con, {
    for (t in rev(ROADMAP_TABLES)) DBI::dbExecute(con, paste("DELETE FROM", t))
    for (t in ROADMAP_TABLES) if (nrow(tables[[t]])) DBI::dbAppendTable(con, t, tables[[t]])
  })
  invisible(con)
}

# ---- Excel input --------------------------------------------------------

#' Columns of each input sheet: type, required, default, description
INPUT_SPEC <- list(
  process = list(
    id = list("chr", TRUE, NA, "Process ID, e.g. P2"),
    name = list("chr", TRUE, NA, "Process name"),
    owner = list("chr", TRUE, NA, "Accountable role (used as a filter)")),
  kpi = list(
    id = list("chr", TRUE, NA, "KPI ID, e.g. K-P2-01"),
    process_id = list("chr", TRUE, NA, "Process ID"),
    name = list("chr", TRUE, NA, "What is measured"),
    unit = list("chr", FALSE, "", "Unit of baseline and target (%, $M, days...)"),
    baseline = list("num", TRUE, NA, "Current value"),
    target = list("num", TRUE, NA, "Value at full adoption"),
    target_year = list("int", FALSE, NA, "Year the target is expected"),
    value_musd = list("num", TRUE, NA, "Annual value at target, $M"),
    value_driver = list("chr", FALSE, "none", "oil_price, fte_cost or none")),
  enabler = list(
    id = list("chr", TRUE, NA, "Enabler ID, e.g. E-P2-01 or E-X-01"),
    enabler_group = list("chr", TRUE, NA, "people, digital, data or infra"),
    subcategory = list("chr", FALSE, "", "Free text"),
    name = list("chr", TRUE, NA, "What is built"),
    start_q = list("quarter", TRUE, NA, "Start quarter, YYYYQn"),
    end_q = list("quarter", TRUE, NA, "Go-live quarter, YYYYQn"),
    capex_musd = list("num", FALSE, 0, "One-off investment, $M"),
    opex_musd_yr = list("num", FALSE, 0, "Running cost per year after go-live, $M"),
    fte_internal = list("num", FALSE, 0, "Average internal FTE during the build"),
    fte_partner = list("num", FALSE, 0, "Average partner / contractor FTE during the build"),
    scalability = list("num", FALSE, 0, "0 rigid, 1 linear, >1 better than linear")),
  enabler_link = list(
    enabler_id = list("chr", TRUE, NA, "Enabler ID"),
    kpi_id = list("chr", TRUE, NA, "KPI ID"),
    weight = list("num", FALSE, 1, "Relative contribution to the KPI")),
  enabler_dependency = list(
    enabler_id = list("chr", TRUE, NA, "Enabler that needs something"),
    requires_id = list("chr", TRUE, NA, "Enabler it needs")),
  milestone = list(
    id = list("chr", TRUE, NA, "Milestone ID, e.g. M-P2-01"),
    milestone_date = list("month", TRUE, NA, "YYYY-MM"),
    name = list("chr", TRUE, NA, "Observable outcome"),
    enabler_id = list("chr", TRUE, NA, "Enabler that delivers it"))
)
INPUT_KEYS <- list(process = "id", kpi = "id", enabler = "id",
                   enabler_link = c("enabler_id", "kpi_id"),
                   enabler_dependency = c("enabler_id", "requires_id"), milestone = "id")

input_path <- function() {
  p <- Sys.getenv("ROADMAP_INPUT_XLSX", "")
  if (nzchar(p)) p else app_sys("extdata", "roadmap_input.xlsx")
}

#' Coerce one input column; returns list(value, bad_rows)
coerce_col <- function(x, type) {
  blank <- is.na(x) | trimws(as.character(x)) == ""
  if (type %in% c("num", "int")) {
    v <- if (is.numeric(x)) x else suppressWarnings(as.numeric(gsub(",", ".", trimws(x), fixed = TRUE)))
    if (type == "int") v <- round(v)
    return(list(v, which(!blank & is.na(v))))
  }
  if (type == "month") {                      # accepts 2027-3, 2027-03, 2027-03-01
    v <- trimws(as.character(x))
    ok <- !blank & grepl("^\\d{4}-\\d{1,2}(-\\d{1,2})?$", v)
    v[ok] <- sprintf("%s-%02d", substr(v[ok], 1, 4), as.integer(sub("^\\d{4}-(\\d{1,2}).*$", "\\1", v[ok])))
    return(list(v, which(!blank & !grepl("^\\d{4}-(0[1-9]|1[0-2])$", v))))
  }
  v <- trimws(as.character(x))
  if (type == "quarter") {
    v <- toupper(gsub("\\s|-", "", v))
    return(list(v, which(!blank & !grepl("^\\d{4}Q[1-4]$", v))))
  }
  list(v, integer(0))
}

#' Read and validate the input workbook
#'
#' One sheet per table, named like the table, header in the first row.
#' Column order does not matter; extra columns and sheets are ignored;
#' fully empty rows are dropped; optional columns get their default.
#' Stops with one message listing every problem found.
#' @return named list of data frames, one per table.
read_input_excel <- function(path = input_path()) {
  if (!file.exists(path)) stop("Input workbook not found: ", path)
  sheets <- readxl::excel_sheets(path)
  probs <- character(0)
  out <- list()
  for (t in ROADMAP_TABLES) {
    spec <- INPUT_SPEC[[t]]
    if (!t %in% sheets) {
      probs <- c(probs, sprintf("sheet '%s' is missing", t))
      next
    }
    df <- as.data.frame(readxl::read_excel(path, sheet = t, col_types = "list", .name_repair = "minimal"))
    names(df) <- tolower(trimws(names(df)))
    df[] <- lapply(df, function(col) {
      vapply(col, function(v) if (is.null(v) || length(v) == 0) NA_character_ else
        if (inherits(v, c("POSIXt", "Date"))) format(v, "%Y-%m-%d") else as.character(v), "")
    })
    if (nrow(df)) df <- df[rowSums(!is.na(df) & trimws(as.matrix(df)) != "") > 0, , drop = FALSE]
    res <- data.frame(row.names = seq_len(nrow(df)))
    for (col in names(spec)) {
      sp <- spec[[col]]
      if (!col %in% names(df)) {
        if (sp[[2]]) probs <- c(probs, sprintf("sheet '%s': column '%s' is missing", t, col))
        res[[col]] <- rep(sp[[3]], nrow(df))
        next
      }
      cc <- coerce_col(df[[col]], sp[[1]])
      v <- cc[[1]]
      if (length(cc[[2]])) {
        what <- c(num = "number", int = "whole number", quarter = "quarter (YYYYQn)",
                  month = "month (YYYY-MM)")[[sp[[1]]]]
        probs <- c(probs, sprintf("sheet '%s', column '%s', row %s: '%s' is not a %s", t, col,
                                  cc[[2]] + 1, df[[col]][cc[[2]]], what))
      }
      empty <- is.na(v) | (is.character(v) & v == "")
      if (sp[[2]] && any(empty)) {
        probs <- c(probs, sprintf("sheet '%s', column '%s': empty in row(s) %s", t, col,
                                  paste(which(empty) + 1, collapse = ", ")))
      } else if (!is.na(sp[[3]])) {
        v[empty] <- sp[[3]]
      }
      res[[col]] <- v
    }
    key <- do.call(paste, c(res[INPUT_KEYS[[t]]], sep = " / "))
    dup <- unique(key[duplicated(key)])
    if (length(dup)) probs <- c(probs, sprintf("sheet '%s': duplicate %s", t, paste(dup, collapse = ", ")))
    rownames(res) <- NULL
    out[[t]] <- res
  }
  if (!length(probs)) {
    empty <- c("process", "kpi", "enabler", "enabler_link")
    empty <- empty[vapply(out[empty], nrow, 1L) == 0]
    probs <- c(probs, sprintf("sheet '%s' has no rows", empty))
  }
  if (!length(probs)) {
    probs <- c(probs,
      sprintf("enabler %s: enabler_group '%s' must be people, digital, data or infra",
              out$enabler$id, out$enabler$enabler_group)[!out$enabler$enabler_group %in% GROUPS$id],
      graph_validate(out))
  }
  if (length(probs)) stop("Problems in ", basename(path), ":\n- ", paste(probs, collapse = "\n- "), call. = FALSE)
  out
}

#' Write roadmap tables to a workbook in the input format
#'
#' Use it to give the current catalogue to the authoring agent, or to
#' start a new input file. Adds a 'README' sheet describing every column.
#' @param data list of tables (db_read_all() / load_roadmap_data()), or
#'   NULL for an empty template.
write_input_excel <- function(path, data = NULL) {
  sheets <- lapply(stats::setNames(ROADMAP_TABLES, ROADMAP_TABLES), function(t) {
    cols <- names(INPUT_SPEC[[t]])
    if (is.null(data)) {
      df <- as.data.frame(stats::setNames(replicate(length(cols), character(0), simplify = FALSE), cols))
    } else {
      df <- data[[t]][, cols, drop = FALSE]
    }
    rownames(df) <- NULL
    df
  })
  readme <- do.call(rbind, lapply(ROADMAP_TABLES, function(t) {
    sp <- INPUT_SPEC[[t]]
    data.frame(sheet = t, column = names(sp),
               type = vapply(sp, function(x) x[[1]], ""),
               required = ifelse(vapply(sp, function(x) x[[2]], TRUE), "yes", "no"),
               default = vapply(sp, function(x) if (is.na(x[[3]])) "" else as.character(x[[3]]), ""),
               description = vapply(sp, function(x) x[[4]], ""), stringsAsFactors = FALSE)
  }))
  writexl::write_xlsx(c(list(README = readme), sheets), path)
  invisible(path)
}

#' Load the input workbook into the database and read it back
#' @param path database path (ROADMAP_DB_PATH; empty = in-memory).
#' @param input input workbook (ROADMAP_INPUT_XLSX; default packaged file).
load_roadmap_data <- function(path = Sys.getenv("ROADMAP_DB_PATH", ":memory:"),
                              input = input_path()) {
  tables <- read_input_excel(input)
  con <- db_connect(path)
  on.exit(db_disconnect(con))
  db_init(con)
  db_import(con, tables)
  data <- db_read_all(con)
  attr(data, "table_info") <- db_table_info(con)
  attr(data, "input") <- list(path = input, modified = file.mtime(input))
  data
}

app_sys <- function(...) {
  p <- system.file(..., package = "dtroadmap")
  if (!nzchar(p)) p <- file.path(dev_root(), "inst", ...)  # sourced / load_all
  p
}

dev_root <- function() getOption("dtroadmap.root", ".")
