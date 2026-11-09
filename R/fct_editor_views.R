# Editor: what the views show (lists, relations, link descriptions).
# Pure functions on the working tables, so they are tested without Shiny.

ITEM_TITLES <- c(process = "Processes", result = "Results", concept = "Concepts", enabler = "Enablers")
ITEM_SINGULAR <- c(process = "process", result = "result", concept = "concept", enabler = "enabler")

#' Allowed values of the coded columns (shown as selects in the forms)
field_choices <- function(t, col) {
  named <- function(df) if (nrow(df)) stats::setNames(df$id, paste0(df$id, " \u00b7 ", df$name)) else character(0)
  switch(col,
    process_id = named(t$process),
    concept_id = named(t$concept),
    value_driver = c("none" = "none", "oil price" = "oil_price", "FTE cost" = "fte_cost"),
    enabler_group = stats::setNames(GROUPS$id, GROUPS$name),
    cost_basis = c("fixed" = "fixed", "per process" = "per_process"),
    NULL)
}

#' People of each enabler, spread from its concept as the model does
#' @return data frame id, fte_internal, fte_partner (during the build).
enabler_people <- function(t) {
  e <- tryCatch(suppressWarnings(prepare_data(t)$enabler), error = function(err) NULL)
  if (is.null(e) || !nrow(e)) return(data.frame(id = character(0), fte_internal = numeric(0), fte_partner = numeric(0)))
  z <- function(x) ifelse(is.na(x), 0, x)
  data.frame(id = e$id, fte_internal = z(e$fte_internal), fte_partner = z(e$fte_partner), stringsAsFactors = FALSE)
}

#' Compact list of items for the Items view
item_table <- function(t, kind) {
  n_of <- function(x, ids) as.integer(vapply(ids, function(i) sum(x == i, na.rm = TRUE), 0))
  num <- function(x, d = 1) ifelse(is.na(x), "", formatC(x, format = "f", digits = d))
  df <- function(...) data.frame(..., check.names = FALSE, stringsAsFactors = FALSE)
  x <- t[[kind]]
  switch(kind,
    process = df(id = x$id, Name = x$name, Owner = x$owner,
                 Results = n_of(c(t$result$process_id, t$result_process$process_id[
                   !paste(t$result_process$result_id, t$result_process$process_id) %in%
                     paste(t$result$id, t$result$process_id)]), x$id)),
    result = df(id = x$id, Name = x$name, Process = x$process_id, Due = x$due,
                `Value $M/yr` = num(x$value_musd), Enablers = n_of(t$result_enabler$result_id, x$id)),
    concept = df(id = x$id, Name = x$name, Group = GROUPS$name[match(x$enabler_group, GROUPS$id)],
                 `FTE int.` = num(x$fte_internal), `FTE partner` = num(x$fte_partner),
                 Enablers = n_of(t$enabler$concept_id, x$id)),
    enabler = df(id = x$id, Name = x$name, Concept = x$concept_id, Build = paste(x$start_q, "\u2013", x$end_q),
                 `Capex $M` = num(x$capex_musd), `Opex $M/yr` = num(x$opex_musd_yr),
                 Basis = ifelse(x$cost_basis == "per_process", "per process", x$cost_basis),
                 Scal. = num(x$scalability, 2), Results = n_of(t$result_enabler$enabler_id, x$id)))
}

#' Connections of one item, as lines of text (shown under its form)
#' @return list of list(label, items = character()).
item_relations <- function(t, kind, id) {
  nm <- function(k, i) {
    n <- t[[k]]$name[match(i, t[[k]]$id)]
    ifelse(is.na(n) | n == "", i, n)
  }
  w <- function(x) ifelse(is.na(x) | x == 1, "", sprintf(" \u00b7 weight %s", format(x)))
  re <- t$result_enabler; d <- t$enabler_dependency; rp <- t$result_process
  out <- switch(kind,
    process = list(
      list(label = "Leads", items = nm("result", t$result$id[t$result$process_id == id])),
      list(label = "Shares", items = nm("result", setdiff(rp$result_id[rp$process_id == id], t$result$id[t$result$process_id == id])))),
    result = list(
      list(label = "Requires", items = paste0(nm("enabler", re$enabler_id[re$result_id == id]), w(re$weight[re$result_id == id]))),
      list(label = "Shared with", items = {
        x <- rp[rp$result_id == id, ]
        if (nrow(x)) sprintf("%s \u00b7 share %s", nm("process", x$process_id), format(x$share)) else character(0)
      })),
    concept = list(list(label = "Enablers", items = nm("enabler", t$enabler$id[t$enabler$concept_id == id]))),
    enabler = list(
      list(label = "Required by", items = paste0(nm("result", re$result_id[re$enabler_id == id]), w(re$weight[re$enabler_id == id]))),
      list(label = "Needs first", items = nm("enabler", d$requires_id[d$enabler_id == id])),
      list(label = "Needed by", items = nm("enabler", d$enabler_id[d$requires_id == id]))))
  out
}

#' What a link on the board means, and whether it carries a value
#' @return list(text, value_label, value, removable, note).
link_info <- function(t, link) {
  p <- strsplit(link, "|", fixed = TRUE)[[1]]
  nm <- function(k, i) {
    n <- t[[k]]$name[match(i, t[[k]]$id)]
    if (length(n) && !is.na(n) && nzchar(n)) n else i
  }
  rp <- t$result_process
  switch(p[1],
    re = list(text = sprintf("%s requires %s", nm("result", p[3]), nm("enabler", p[2])),
              value_label = "Weight", removable = TRUE,
              value = t$result_enabler$weight[t$result_enabler$enabler_id == p[2] & t$result_enabler$result_id == p[3]],
              note = "Relative contribution of the enabler to the result; the cost attributed to the result follows it."),
    dep = list(text = sprintf("%s needs %s first", nm("enabler", p[3]), nm("enabler", p[2])),
               value_label = NULL, value = NA, removable = TRUE,
               note = "A foundation: the enabler can only go live after its prerequisite."),
    lead = {
      shared <- any(rp$result_id == p[2])
      list(text = sprintf("%s is led by %s", nm("result", p[2]), nm("process", p[3])),
           value_label = if (shared) "Share" else NULL, removable = FALSE,
           value = if (shared) rp$share[rp$result_id == p[2] & rp$process_id == p[3]] else NA,
           note = if (shared) "The result is shared: its value is split by share. Change the lead process in the result's form."
                  else "The lead process holds all of the result's value. Drag the result onto another process to share it.")
    },
    rp = list(text = sprintf("%s is shared with %s", nm("result", p[2]), nm("process", p[3])),
              value_label = "Share", removable = TRUE,
              value = rp$share[rp$result_id == p[2] & rp$process_id == p[3]],
              note = "Shares are relative and normalised per result."),
    cpt = list(text = sprintf("%s belongs to %s", nm("enabler", p[2]), nm("concept", p[3])),
               value_label = NULL, value = NA, removable = FALSE,
               note = "Drag the enabler onto another concept to move it."),
    list(text = link, value_label = NULL, value = NA, removable = FALSE, note = ""))
}

#' Short count line: "8 processes \u00b7 11 results \u00b7 ..."
tables_summary <- function(t) {
  n <- c(process = nrow(t$process), result = nrow(t$result), concept = nrow(t$concept), enabler = nrow(t$enabler),
         link = nrow(t$result_enabler) + nrow(t$enabler_dependency))
  lab <- c(process = "process", result = "result", concept = "concept", enabler = "enabler", link = "connection")
  paste(sprintf("%d %s%s", n, lab, ifelse(n == 1, "", ifelse(lab == "process", "es", "s"))), collapse = " \u00b7 ")
}

#' Run the model on the working tables for the export check
#' @return list(data, model) or NULL when the tables are not valid.
editor_model <- function(t, cfg_table) {
  if (length(validate_tables(t))) return(NULL)
  data <- prepare_data(t)
  graph <- build_graph(data)
  cfg <- config_values(cfg_table)
  list(data = data, model = run_model(data, graph, cfg, cfg))
}
