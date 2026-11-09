# All data interaction lives in this file.
# Input: an Excel workbook with one sheet per table plus a 'config' sheet
# (process, result, result_process, concept, enabler, result_enabler,
# enabler_dependency, config)
# (ROADMAP_INPUT_XLSX, default inst/extdata/roadmap_input.xlsx). It is the source of truth: at
# startup it is validated and loaded into the database, replacing its content.
# Development: DuckDB (file or in-memory).
# Enterprise: swap db_connect() for an odbc / RPostgres connection; the rest
# uses plain DBI + portable SQL, so callers do not change.

ROADMAP_TABLES <- c("process", "result", "result_process", "concept", "enabler",
                    "result_enabler", "enabler_dependency")
# sheets that may be left out of the workbook (read as empty)
OPTIONAL_SHEETS <- "result_process"

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

#' Hook for columns added after a database file was created (none in v2)
db_migrate <- function(con) invisible(con)

#' Read every roadmap table into a named list of data frames
db_read_all <- function(con) {
  out <- lapply(ROADMAP_TABLES, function(t) {
    DBI::dbGetQuery(con, paste0("SELECT * FROM ", t, " ORDER BY 1"))
  })
  names(out) <- ROADMAP_TABLES
  prepare_data(out)
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
  result = list(
    id = list("chr", TRUE, NA, "Result ID, e.g. R-P04-01"),
    process_id = list("chr", TRUE, NA, "Lead process (accountable owner)"),
    name = list("chr", TRUE, NA, "The tangible result, e.g. 250 wells per engineer"),
    due = list("month", TRUE, NA, "Due date, YYYY-MM"),
    value_musd = list("num", FALSE, 0, "Annual value once achieved, $M (0 if none)"),
    value_driver = list("chr", FALSE, "none", "oil_price, fte_cost or none"),
    unit = list("chr", FALSE, "", "Optional measure: unit of baseline and target"),
    baseline = list("num", FALSE, NA, "Optional measure: current value"),
    target = list("num", FALSE, NA, "Optional measure: value when achieved")),
  concept = list(
    id = list("chr", TRUE, NA, "Concept ID, e.g. C-ROC"),
    name = list("chr", TRUE, NA, "Concept name, e.g. Remote operations"),
    enabler_group = list("chr", TRUE, NA, "people, digital, data or infra"),
    subgroup = list("chr", FALSE, "", "Free text, e.g. Automation"),
    fte_internal = list("num", FALSE, 0, "Average internal FTE on the concept over its build window"),
    fte_partner = list("num", FALSE, 0, "Average partner / contractor FTE over its build window")),
  enabler = list(
    id = list("chr", TRUE, NA, "Enabler ID, e.g. E-X-01"),
    concept_id = list("chr", TRUE, NA, "Concept the enabler belongs to"),
    name = list("chr", TRUE, NA, "What is built"),
    start_q = list("quarter", TRUE, NA, "Start quarter, YYYYQn"),
    end_q = list("quarter", TRUE, NA, "Go-live quarter, YYYYQn"),
    capex_musd = list("num", FALSE, 0, "One-off investment, $M"),
    opex_musd_yr = list("num", FALSE, 0, "Running cost per year after go-live, $M"),
    cost_basis = list("chr", FALSE, "fixed", "fixed, or per_process (scales with the processes in scope)"),
    scalability = list("num", FALSE, 0, "0 rigid, 1 linear, >1 better than linear (time and per-process cost)")),
  result_process = list(
    result_id = list("chr", TRUE, NA, "Result shared by several processes (optional sheet)"),
    process_id = list("chr", TRUE, NA, "A process that shares it; list the lead process too"),
    share = list("num", FALSE, 1, "Relative share of the result's value and cost (normalised per result)")),
  result_enabler = list(
    result_id = list("chr", TRUE, NA, "Result ID"),
    enabler_id = list("chr", TRUE, NA, "Enabler the result requires"),
    weight = list("num", FALSE, 1, "Relative contribution of the enabler to the result")),
  enabler_dependency = list(
    enabler_id = list("chr", TRUE, NA, "Enabler that needs something"),
    requires_id = list("chr", TRUE, NA, "Enabler it needs"))
)
INPUT_KEYS <- list(process = "id", result = "id", result_process = c("result_id", "process_id"),
                   concept = "id", enabler = "id",
                   result_enabler = c("result_id", "enabler_id"),
                   enabler_dependency = c("enabler_id", "requires_id"))

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
#' Stops with one message listing every problem found (strict), or returns
#' what could be read with the problems in attribute "problems" (lenient,
#' used by the editor to load a workbook that still needs fixing).
#' @param strict stop on problems (TRUE) or return them (FALSE).
#' @return named list of data frames, one per table.
read_input_excel <- function(path = input_path(), strict = TRUE) {
  if (!file.exists(path)) stop("Input workbook not found: ", path)
  sheets <- readxl::excel_sheets(path)
  probs <- character(0)
  out <- list()
  for (t in ROADMAP_TABLES) {
    spec <- INPUT_SPEC[[t]]
    if (!t %in% sheets && !t %in% OPTIONAL_SHEETS) {
      probs <- c(probs, sprintf("sheet '%s' is missing", t))
      if (strict) next
    }
    df <- if (t %in% sheets) {
      as.data.frame(readxl::read_excel(path, sheet = t, col_types = "list", .name_repair = "minimal"))
    } else {
      as.data.frame(stats::setNames(replicate(length(spec), character(0), simplify = FALSE), names(spec)))
    }
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
  if (strict && length(probs)) {
    stop("Problems in ", basename(path), ":\n- ", paste(probs, collapse = "\n- "), call. = FALSE)
  }
  if (!is.null(out$enabler)) out$enabler$cost_basis <- tolower(out$enabler$cost_basis)
  probs <- c(probs, validate_tables(out, basic = FALSE))
  if (strict && length(probs)) {
    stop("Problems in ", basename(path), ":\n- ", paste(probs, collapse = "\n- "), call. = FALSE)
  }
  attr(out, "problems") <- probs
  out
}

#' Check a set of tables in memory
#'
#' Content rules shared by the import and the editor: sheets that must
#' have rows, allowed values, measures, references and dependency cycles.
#' @param basic also check required fields and duplicate keys (the import
#'   reports those itself, with row numbers).
#' @return character vector of problems (empty when valid).
validate_tables <- function(t, basic = TRUE) {
  probs <- character(0)
  if (basic) for (n in names(INPUT_SPEC)) {
    df <- t[[n]]
    if (is.null(df) || !nrow(df)) next
    for (col in names(INPUT_SPEC[[n]])) {
      if (!INPUT_SPEC[[n]][[col]][[2]]) next
      v <- df[[col]]
      bad <- is.null(v) | is.na(v) | trimws(as.character(v)) == ""
      if (any(bad)) probs <- c(probs, sprintf("%s: %s is empty for %s", n, col,
        paste(if ("id" %in% names(df)) ifelse(is.na(df$id[bad]) | df$id[bad] == "", "(no id)", df$id[bad]) else which(bad),
              collapse = ", ")))
    }
    key <- do.call(paste, c(df[INPUT_KEYS[[n]]], sep = " / "))
    dup <- unique(key[duplicated(key)])
    if (length(dup)) probs <- c(probs, sprintf("%s: duplicate %s", n, paste(dup, collapse = ", ")))
  }
  empty <- c("process", "result", "concept", "enabler", "result_enabler")
  empty <- empty[vapply(empty, function(n) is.null(t[[n]]) || nrow(t[[n]]) == 0, TRUE)]
  probs <- c(probs, sprintf("sheet '%s' has no rows", empty))
  if (length(empty)) return(probs)
  r <- t$result
  half <- xor(is.na(r$baseline), is.na(r$target))
  c(probs,
    sprintf("result %s: a measure needs both baseline and target", r$id)[half],
    sprintf("result %s: value_driver '%s' must be oil_price, fte_cost or none", r$id, r$value_driver)[
      !r$value_driver %in% c("oil_price", "fte_cost", "none")],
    sprintf("concept %s: enabler_group '%s' must be people, digital, data or infra",
            t$concept$id, t$concept$enabler_group)[!t$concept$enabler_group %in% GROUPS$id],
    sprintf("enabler %s: cost_basis '%s' must be fixed or per_process",
            t$enabler$id, t$enabler$cost_basis)[!t$enabler$cost_basis %in% c("fixed", "per_process")],
    graph_validate(t))
}

#' Read the 'config' sheet of the input workbook (raw; see config_clean())
read_config_excel <- function(path = input_path()) {
  if (!file.exists(path)) stop("Input workbook not found: ", path)
  if (!"config" %in% readxl::excel_sheets(path)) {
    stop("Problems in ", basename(path), ":\n- sheet 'config' is missing", call. = FALSE)
  }
  df <- as.data.frame(readxl::read_excel(path, sheet = "config", col_types = "list", .name_repair = "minimal"))
  df[] <- lapply(df, function(col) vapply(col, function(v)
    if (is.null(v) || length(v) == 0) NA_character_ else as.character(v), ""))
  df
}

#' Write roadmap tables to a workbook in the input format
#'
#' Use it to give the current catalogue to the authoring agent, or to
#' start a new input file. Adds a 'README' sheet describing every column.
#' @param data list of tables (db_read_all() / load_roadmap_data()), or
#'   NULL for an empty template.
#' @param config config table written to the 'config' sheet (defaults to
#'   the one in the current input workbook).
write_input_excel <- function(path, data = NULL, config = config_read(board_type = "")) {
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
  readme <- rbind(readme, data.frame(
    sheet = "config",
    column = CONFIG_COLUMNS,
    type = c("text", "text", "text", rep("number", 6), "TRUE/FALSE", "TRUE/FALSE", "text"),
    required = c("yes", "yes", "no", "yes", "yes", "yes", "yes", "no", "no", "no", "no", "no"),
    default = c("", "", "", "", "", "", "", "", "", "FALSE", "FALSE", ""),
    description = c("Parameter name used by the model (do not rename)", "Label in the app",
                    "Unit shown next to the value", "Base-case value", "Slider minimum",
                    "Slider maximum", "Slider step", "(not used in v2)", "(not used in v2)",
                    "Show as a percentage (0.15 -> 15%)", "Show as a lever in the Scenario view",
                    "Help text under the slider"),
    stringsAsFactors = FALSE))
  cfg <- config[, CONFIG_COLUMNS]
  writexl::write_xlsx(c(list(README = readme), sheets, list(config = cfg)), path)
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
