# Editor: operations on an in-memory copy of the roadmap tables.
# Pure functions: tables in, tables (or an error message) out. The editor
# never writes to the workbook the main app reads; it imports and exports.

EDITOR_ITEMS <- c(process = "process", result = "result", concept = "concept", enabler = "enabler")
ID_PREFIX <- c(process = "P", result = "R-", concept = "C-", enabler = "E-")

#' Empty tables with the input columns and types
empty_tables <- function() {
  lapply(INPUT_SPEC, function(spec) {
    cols <- lapply(spec, function(sp) switch(sp[[1]], num = numeric(0), int = integer(0), character(0)))
    as.data.frame(cols, stringsAsFactors = FALSE)
  })
}

#' Keep only the input columns, in order (drops derived columns)
clean_tables <- function(t) {
  out <- lapply(stats::setNames(names(INPUT_SPEC), names(INPUT_SPEC)), function(n) {
    df <- t[[n]]
    spec <- INPUT_SPEC[[n]]
    if (is.null(df)) return(empty_tables()[[n]])
    for (col in setdiff(names(spec), names(df))) df[[col]] <- rep(spec[[col]][[3]], nrow(df))
    df <- df[, names(spec), drop = FALSE]
    rownames(df) <- NULL
    df
  })
  out
}

#' Next free id for an item kind: P09, R-12, C-03, E-22
next_id <- function(t, kind) {
  ids <- t[[kind]]$id
  pre <- ID_PREFIX[[kind]]
  pat <- paste0("^", gsub("-", "\\\\-", pre), "(\\d+)$")
  n <- suppressWarnings(as.integer(sub(pat, "\\1", ids[grepl(pat, ids)])))
  nxt <- if (length(n)) max(n) + 1 else 1
  repeat {
    id <- sprintf("%s%02d", pre, nxt)
    if (!id %in% ids) return(id)
    nxt <- nxt + 1
  }
}

#' A new item with defaults
new_item <- function(t, kind) {
  spec <- INPUT_SPEC[[kind]]
  row <- lapply(spec, function(sp) if (is.na(sp[[3]])) NA else sp[[3]])
  row$id <- next_id(t, kind)
  row$name <- ""
  if (kind == "result") {
    row$process_id <- if (nrow(t$process)) t$process$id[1] else ""
    row$due <- "2028-12"
  }
  if (kind == "concept") row$enabler_group <- "digital"
  if (kind == "enabler") {
    row$concept_id <- if (nrow(t$concept)) t$concept$id[1] else ""
    row$start_q <- "2027Q1"
    row$end_q <- "2027Q4"
  }
  row
}

#' Check one item's fields; returns problems (empty when valid)
check_item <- function(t, kind, row, old_id = NULL) {
  spec <- INPUT_SPEC[[kind]]
  probs <- character(0)
  for (col in names(spec)) {
    sp <- spec[[col]]
    v <- row[[col]]
    empty <- is.null(v) || length(v) == 0 || is.na(v) || trimws(as.character(v)) == ""
    if (sp[[2]] && empty) {
      probs <- c(probs, sprintf("%s is required", col))
      next
    }
    if (empty) next
    if (sp[[1]] == "quarter" && !grepl("^\\d{4}Q[1-4]$", v)) probs <- c(probs, sprintf("%s must look like 2027Q3", col))
    if (sp[[1]] == "month" && !grepl("^\\d{4}-(0[1-9]|1[0-2])$", v)) probs <- c(probs, sprintf("%s must look like 2027-03", col))
    if (sp[[1]] %in% c("num", "int") && is.na(suppressWarnings(as.numeric(v)))) probs <- c(probs, sprintf("%s must be a number", col))
  }
  if (!is.null(row$id) && row$id %in% setdiff(t[[kind]]$id, old_id)) probs <- c(probs, sprintf("id %s is already used", row$id))
  if (kind == "result" && xor(is.na(row$baseline), is.na(row$target))) probs <- c(probs, "a measure needs both baseline and target")
  if (kind == "enabler" && !is.na(row$start_q) && !is.na(row$end_q) && grepl("Q", row$start_q) && grepl("Q", row$end_q) &&
      q_to_time(row$end_q, TRUE) <= q_to_time(row$start_q)) probs <- c(probs, "end_q is before start_q")
  probs
}

#' Add or update an item; renaming an id is cascaded to every reference
#' @return updated tables, or a character vector of problems.
upsert_item <- function(t, kind, row, old_id = NULL) {
  probs <- check_item(t, kind, row, old_id)
  if (length(probs)) return(probs)
  spec <- INPUT_SPEC[[kind]]
  df <- t[[kind]]
  new <- as.data.frame(lapply(stats::setNames(names(spec), names(spec)), function(col) {
    v <- row[[col]]
    if (is.null(v) || length(v) == 0 || (is.character(v) && trimws(v) == "")) v <- if (is.na(spec[[col]][[3]])) NA else spec[[col]][[3]]
    if (spec[[col]][[1]] %in% c("num", "int")) as.numeric(v) else as.character(v)
  }), stringsAsFactors = FALSE)
  if (!is.null(old_id) && old_id %in% df$id) {
    df[df$id == old_id, ] <- new
    if (old_id != new$id) t <- rename_refs(t, kind, old_id, new$id)
  } else {
    df <- rbind(df, new)
  }
  t[[kind]] <- df
  t
}

rename_refs <- function(t, kind, old, new) {
  sw <- function(x) ifelse(x == old, new, x)
  if (kind == "process") {
    t$result$process_id <- sw(t$result$process_id)
    t$result_process$process_id <- sw(t$result_process$process_id)
  }
  if (kind == "result") {
    t$result_enabler$result_id <- sw(t$result_enabler$result_id)
    t$result_process$result_id <- sw(t$result_process$result_id)
  }
  if (kind == "concept") t$enabler$concept_id <- sw(t$enabler$concept_id)
  if (kind == "enabler") {
    t$result_enabler$enabler_id <- sw(t$result_enabler$enabler_id)
    t$enabler_dependency$enabler_id <- sw(t$enabler_dependency$enabler_id)
    t$enabler_dependency$requires_id <- sw(t$enabler_dependency$requires_id)
  }
  t
}

#' Delete an item and the connections that point to it
#'
#' A process that still leads results, or a concept that still has
#' enablers, can't be deleted: the message says what to move first.
#' @return updated tables, or a problem message.
delete_item <- function(t, kind, id) {
  if (kind == "process" && any(t$result$process_id == id)) {
    return(sprintf("Process %s still leads %d result(s); move them to another process first.", id, sum(t$result$process_id == id)))
  }
  if (kind == "concept" && any(t$enabler$concept_id == id)) {
    return(sprintf("Concept %s still has %d enabler(s); move them to another concept first.", id, sum(t$enabler$concept_id == id)))
  }
  t[[kind]] <- t[[kind]][t[[kind]]$id != id, , drop = FALSE]
  if (kind == "process") t$result_process <- t$result_process[t$result_process$process_id != id, , drop = FALSE]
  if (kind == "result") {
    t$result_enabler <- t$result_enabler[t$result_enabler$result_id != id, , drop = FALSE]
    t$result_process <- t$result_process[t$result_process$result_id != id, , drop = FALSE]
  }
  if (kind == "enabler") {
    t$result_enabler <- t$result_enabler[t$result_enabler$enabler_id != id, , drop = FALSE]
    d <- t$enabler_dependency
    t$enabler_dependency <- d[d$enabler_id != id & d$requires_id != id, , drop = FALSE]
  }
  t
}

#' Path of prerequisites from `from` back to `to` (empty if none)
prereq_path <- function(t, from, to) {
  d <- t$enabler_dependency
  prev <- stats::setNames(list(NULL), from)
  queue <- from
  while (length(queue)) {
    cur <- queue[1]
    queue <- queue[-1]
    for (nx in d$requires_id[d$enabler_id == cur]) {
      if (!is.null(prev[[nx]]) || nx == from) next
      prev[[nx]] <- cur
      if (nx == to) {
        path <- to
        while (path[1] != from) path <- c(prev[[path[1]]], path)
        return(path)
      }
      queue <- c(queue, nx)
    }
  }
  character(0)
}

node_kind <- function(x) sub(":.*", "", x)
node_id <- function(x) sub("^[^:]*:", "", x)

#' Create a connection by dragging one box onto another
#'
#' enabler -> result: the result requires the enabler (weight 1)
#' enabler -> enabler: the target needs the source first (dependency)
#' result -> process: the result is shared with the process (share 1)
#' enabler -> concept: the enabler moves to that concept
#' @param from,to node keys like "enabler:E-01".
#' @return list(tables, message) on success, or a problem message.
connect_nodes <- function(t, from, to) {
  kf <- node_kind(from); kt <- node_kind(to); f <- node_id(from); g <- node_id(to)
  nm <- function(kind, id) {
    n <- t[[kind]]$name[t[[kind]]$id == id]
    if (length(n) && nzchar(n)) n else id
  }
  if (kf == "enabler" && kt == "result") {
    if (any(t$result_enabler$result_id == g & t$result_enabler$enabler_id == f)) return("already connected")
    t$result_enabler <- rbind(t$result_enabler, data.frame(result_id = g, enabler_id = f, weight = 1))
    msg <- sprintf("%s now requires %s", nm("result", g), nm("enabler", f))
  } else if (kf == "enabler" && kt == "enabler") {
    if (f == g) return("an enabler can't require itself")
    if (any(t$enabler_dependency$enabler_id == g & t$enabler_dependency$requires_id == f)) return("already connected")
    loop <- prereq_path(t, f, g)
    if (length(loop)) {
      return(sprintf("this would close a loop: %s", paste(vapply(c(g, loop), function(x) nm("enabler", x), ""), collapse = " \u2192 ")))
    }
    t$enabler_dependency <- rbind(t$enabler_dependency, data.frame(enabler_id = g, requires_id = f))
    msg <- sprintf("%s now needs %s first", nm("enabler", g), nm("enabler", f))
  } else if (kf == "result" && kt == "process") {
    r <- t$result[t$result$id == f, ]
    rp <- t$result_process
    if (r$process_id == g && !any(rp$result_id == f)) return("this is already its lead process")
    if (!any(rp$result_id == f)) rp <- rbind(rp, data.frame(result_id = f, process_id = r$process_id, share = 1))
    if (any(rp$result_id == f & rp$process_id == g)) return("already shared with this process")
    t$result_process <- rbind(rp, data.frame(result_id = f, process_id = g, share = 1))
    msg <- sprintf("%s is now shared with %s", nm("result", f), nm("process", g))
  } else if (kf == "enabler" && kt == "concept") {
    if (t$enabler$concept_id[t$enabler$id == f] == g) return("already in this concept")
    t$enabler$concept_id[t$enabler$id == f] <- g
    msg <- sprintf("%s moved to %s", nm("enabler", f), nm("concept", g))
  } else {
    return(sprintf("a %s can't be connected to a %s", kf, kt))
  }
  probs <- graph_validate(t)
  if (length(probs)) return(paste(probs, collapse = "; "))
  list(tables = t, message = msg)
}

#' Link ids used by the board: "re|enabler|result", "dep|requires|enabler", "rp|result|process"
remove_link <- function(t, link) {
  p <- strsplit(link, "|", fixed = TRUE)[[1]]
  if (p[1] == "re") t$result_enabler <- t$result_enabler[!(t$result_enabler$enabler_id == p[2] & t$result_enabler$result_id == p[3]), , drop = FALSE]
  if (p[1] == "dep") t$enabler_dependency <- t$enabler_dependency[!(t$enabler_dependency$requires_id == p[2] & t$enabler_dependency$enabler_id == p[3]), , drop = FALSE]
  if (p[1] == "rp") {
    rp <- t$result_process
    rp <- rp[!(rp$result_id == p[2] & rp$process_id == p[3]), , drop = FALSE]
    # a result left with only its lead process needs no sharing rows
    lead <- t$result$process_id[t$result$id == p[2]]
    if (sum(rp$result_id == p[2]) == 1 && rp$process_id[rp$result_id == p[2]] == lead) rp <- rp[rp$result_id != p[2], , drop = FALSE]
    t$result_process <- rp
  }
  t
}

#' Set a requirement weight or a sharing share
set_link_value <- function(t, link, value) {
  value <- suppressWarnings(as.numeric(value))
  if (is.na(value) || value <= 0) return("the value must be a number above 0")
  p <- strsplit(link, "|", fixed = TRUE)[[1]]
  if (p[1] == "re") t$result_enabler$weight[t$result_enabler$enabler_id == p[2] & t$result_enabler$result_id == p[3]] <- value
  else if (p[1] %in% c("rp", "lead")) {
    if (!any(t$result_process$result_id == p[2])) return("the lead process takes all the value until the result is shared")
    t$result_process$share[t$result_process$result_id == p[2] & t$result_process$process_id == p[3]] <- value
  } else return("this link has no value")
  t
}

#' Board payload: boxes in four columns and every link
board_payload <- function(t, ns_prefix = "") {
  e <- t$enabler; r <- t$result; p <- t$process; cpt <- t$concept
  grp <- cpt$enabler_group[match(e$concept_id, cpt$id)]
  ord <- order(match(grp, GROUPS$id), e$concept_id, e$name)
  df <- function(...) data.frame(..., stringsAsFactors = FALSE)
  link_df <- function(kind, a, b, from_kind, to_kind, value = rep(NA_real_, length(a))) {
    df(id = if (length(a)) paste(kind, a, b, sep = "|") else character(0), from = paste0(from_kind, ":", a)[seq_along(a)], to = paste0(to_kind, ":", b)[seq_along(a)],
       value = as.numeric(value), kind = rep(kind, length(a)))
  }
  d <- t$enabler_dependency; re <- t$result_enabler; rp <- t$result_process
  # the lead link carries the lead's share when the result is shared
  lead_share <- rp$share[match(paste(r$id, r$process_id), paste(rp$result_id, rp$process_id))]
  others <- rp[!paste(rp$result_id, rp$process_id) %in% paste(r$id, r$process_id), , drop = FALSE]
  links <- rbind(
    link_df("dep", d$requires_id, d$enabler_id, "enabler", "enabler"),
    link_df("re", re$enabler_id, re$result_id, "enabler", "result", re$weight),
    link_df("lead", r$id, r$process_id, "result", "process", lead_share),
    link_df("rp", others$result_id, others$process_id, "result", "process", others$share),
    link_df("cpt", e$id, e$concept_id, "enabler", "concept"))
  lbl <- function(x, id) ifelse(is.na(x) | x == "", id, x)
  list(
    ns = ns_prefix,
    cols = list(
      list(key = "concept", title = "Concepts",
           items = df(id = paste0("concept:", cpt$id), name = lbl(cpt$name, cpt$id), g = cpt$enabler_group)),
      list(key = "enabler", title = "Enablers",
           items = df(id = paste0("enabler:", e$id[ord]), name = lbl(e$name[ord], e$id[ord]), g = grp[ord])),
      list(key = "result", title = "Results",
           items = df(id = paste0("result:", r$id), name = lbl(r$name, r$id), g = rep("", nrow(r)))),
      list(key = "process", title = "Processes",
           items = df(id = paste0("process:", p$id), name = lbl(p$name, p$id), g = rep("", nrow(p))))),
    links = links)
}
