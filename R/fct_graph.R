# Value chain: enablers make results possible; results generate value for
# processes. process -> results -> required enablers
# -> their prerequisites (foundations). Graph, attribution and date checks.

#' Convert a quarter label ("2027Q3") to decimal years
#' @param q character vector of quarters.
#' @param end if TRUE return the end of the quarter.
q_to_time <- function(q, end = FALSE) {
  y <- as.integer(substr(q, 1, 4))
  n <- as.integer(substr(q, 6, 6))
  y + (n - 1) / 4 + if (end) 0.25 else 0
}

#' Convert a month ("2027-03") to decimal years (mid-month)
month_to_time <- function(m) {
  as.integer(substr(m, 1, 4)) + (as.integer(substr(m, 6, 7)) - 0.5) / 12
}

#' End of a due month ("2028-06" -> 2028.5): a result is on time if ready by then
due_to_time <- function(m) {
  as.integer(substr(m, 1, 4)) + as.integer(substr(m, 6, 7)) / 12
}

#' Decimal year back to a quarter label
time_to_q <- function(t) {
  y <- floor(t + 1e-9)
  paste0(y, "Q", round((t - y) * 4) + 1)
}

#' Check the data for broken references and dependency cycles
#'
#' These are blocking errors. Date inconsistencies are not: they load and
#' are reported by date_issues() / result_issues() so the app shows them in red.
#' @return character vector of problems (empty when valid).
graph_validate <- function(data) {
  e <- data$enabler$id
  r <- data$result
  dep <- data$enabler_dependency
  re <- data$result_enabler
  probs <- c(
    sprintf("result %s: unknown process %s", r$id, r$process_id)[!r$process_id %in% data$process$id],
    if (!is.null(data$concept)) sprintf("enabler %s: unknown concept %s", data$enabler$id, data$enabler$concept_id)[
      !data$enabler$concept_id %in% data$concept$id],
    sprintf("result_enabler %s-%s: unknown enabler", re$result_id, re$enabler_id)[!re$enabler_id %in% e],
    sprintf("result_enabler %s-%s: unknown result", re$result_id, re$enabler_id)[!re$result_id %in% r$id],
    sprintf("dependency %s-%s: unknown enabler", dep$enabler_id, dep$requires_id)[
      !(dep$enabler_id %in% e & dep$requires_id %in% e)],
    sprintf("result %s requires no enabler", r$id)[!r$id %in% re$result_id]
  )
  rp <- data$result_process
  if (!is.null(rp) && nrow(rp)) {
    lead_missing <- setdiff(unique(rp$result_id[rp$result_id %in% r$id]),
                            rp$result_id[rp$process_id == r$process_id[match(rp$result_id, r$id)]])
    probs <- c(probs,
      sprintf("result_process %s-%s: unknown result", rp$result_id, rp$process_id)[!rp$result_id %in% r$id],
      sprintf("result_process %s-%s: unknown process", rp$result_id, rp$process_id)[!rp$process_id %in% data$process$id],
      sprintf("result_process %s-%s: share must be > 0", rp$result_id, rp$process_id)[!(rp$share > 0)],
      sprintf("result_process %s: list its lead process %s too", lead_missing,
              r$process_id[match(lead_missing, r$id)]))
  }
  # cycle detection by repeatedly removing enablers with no prerequisites left
  remaining <- dep[dep$enabler_id %in% e & dep$requires_id %in% e, ]
  nodes <- e
  repeat {
    free <- setdiff(nodes, remaining$enabler_id)
    if (!length(free)) break
    nodes <- setdiff(nodes, free)
    remaining <- remaining[!remaining$requires_id %in% free, ]
  }
  if (length(nodes)) {
    probs <- c(probs, paste("dependency cycle among:", paste(nodes, collapse = ", ")))
  }
  probs
}

#' Build the enabler graph and attribution matrices
#'
#' @param data list from db_read_all().
#' @return list with prerequisite / dependent lists, normalised weights
#'   (enabler x result), cost allocation shares, result chains (required
#'   enablers + foundations), plan ready dates and plan date issues.
build_graph <- function(data) {
  probs <- graph_validate(data)
  if (length(probs)) stop("Invalid roadmap data:\n", paste(probs, collapse = "\n"))

  ids <- data$enabler$id
  rids <- data$result$id
  dep <- data$enabler_dependency
  prereq <- lapply(stats::setNames(ids, ids), function(i) dep$requires_id[dep$enabler_id == i])
  dependents <- lapply(stats::setNames(ids, ids), function(i) dep$enabler_id[dep$requires_id == i])

  # explicit requirement weights, normalised per result
  w <- matrix(0, length(ids), length(rids), dimnames = list(ids, rids))
  re <- data$result_enabler
  w[cbind(re$enabler_id, re$result_id)] <- re$weight
  wn <- sweep(w, 2, pmax(colSums(w), 1e-12), "/")

  # cost flow: own weight + an equal share of each dependent's flow,
  # so foundations carry the results of everything built on them
  flow <- matrix(NA_real_, length(ids), length(rids), dimnames = list(ids, rids))
  get_flow <- function(i) {
    if (!anyNA(flow[i, ])) return(flow[i, ])
    f <- wn[i, ]
    for (d in dependents[[i]]) f <- f + get_flow(d) / length(prereq[[d]])
    flow[i, ] <<- f
    f
  }
  for (i in ids) get_flow(i)
  rs <- rowSums(flow)
  alloc <- flow / ifelse(rs > 0, rs, 1)

  end_t <- stats::setNames(q_to_time(data$enabler$end_q, TRUE), ids)
  chains <- lapply(stats::setNames(rids, rids), function(r) {
    direct <- re$enabler_id[re$result_id == r]
    found <- setdiff(ancestors(direct, prereq), direct)
    list(direct = direct, foundation = found)
  })
  ready <- vapply(chains, function(ch) max(end_t[c(ch$direct, ch$foundation)]), numeric(1))

  list(ids = ids, results = rids, prereq = prereq, dependents = dependents,
       weight = wn, alloc = alloc, chains = chains, ready = ready,
       share = process_shares(data),
       issues = date_issues(data))
}

#' Results that cannot be achieved by their due date
#'
#' A result is late when its required enablers (and their prerequisites)
#' go live after the end of its due month.
#' @param ready named vector of ready times (scenario).
#' @return data frame result_id, enabler_id (the latest one), type, message.
result_issues <- function(data, graph, ready, end) {
  r <- data$result
  due <- stats::setNames(due_to_time(r$due), r$id)
  late <- r$id[ready[r$id] > due + 1e-6]
  lbl <- function(t) time_to_q(ceiling(t * 4 - 1e-9) / 4 - 0.25)
  ename <- stats::setNames(data$enabler$name, data$enabler$id)
  last <- vapply(late, function(i) {
    ch <- graph$chains[[i]]
    en <- c(ch$direct, ch$foundation)
    en[which.max(end[en])]
  }, "")
  data.frame(
    result_id = late, enabler_id = unname(last), type = rep("result_late", length(late)),
    message = sprintf("%s (due %s) can only be achieved in %s: %s goes live then",
                      r$name[match(late, r$id)], r$due[match(late, r$id)],
                      lbl(ready[late]), ename[last]),
    stringsAsFactors = FALSE)
}

#' All transitive prerequisites (or dependents) of a set of enablers
walk_graph <- function(start, nxt) {
  seen <- character(0)
  stack <- unique(start)
  while (length(stack)) {
    cur <- stack[1]
    stack <- stack[-1]
    new <- setdiff(nxt[[cur]], seen)
    seen <- c(seen, new)
    stack <- c(stack, new)
  }
  seen
}
ancestors <- function(ids, prereq) walk_graph(ids, prereq)
descendants <- function(ids, dependents) walk_graph(ids, dependents)

#' Date inconsistencies (non-blocking)
#'
#' * `end_before_start`: end quarter earlier than start quarter (input error).
#' * `prereq_ends_later`: a prerequisite goes live after the enabler that
#'   needs it (a "late dependency", red arrow on the timeline).
#' @param end optional named vector of scenario end times; plan ends when NULL.
#' @return data frame enabler_id, related_id, type, message (one row per issue).
date_issues <- function(data, end = NULL) {
  e <- data$enabler
  s <- stats::setNames(q_to_time(e$start_q), e$id)
  f_plan <- stats::setNames(q_to_time(e$end_q, TRUE), e$id)
  f <- if (is.null(end)) f_plan else end[e$id]
  lbl <- function(t) time_to_q(ceiling(t * 4 - 1e-9) / 4 - 0.25)
  name <- stats::setNames(e$name, e$id)
  bad <- e$id[f_plan <= s]
  dep <- data$enabler_dependency
  dep <- dep[dep$enabler_id %in% e$id & dep$requires_id %in% e$id, ]
  late <- dep[f[dep$requires_id] > f[dep$enabler_id] + 1e-6, ]
  out <- rbind(
    data.frame(enabler_id = bad, related_id = rep(NA_character_, length(bad)),
               type = rep("end_before_start", length(bad)),
               message = sprintf("%s ends (%s) before it starts (%s)", name[bad],
                                 e$end_q[match(bad, e$id)], e$start_q[match(bad, e$id)]),
               stringsAsFactors = FALSE),
    data.frame(enabler_id = late$enabler_id, related_id = late$requires_id,
               type = rep("prereq_ends_later", nrow(late)),
               message = sprintf("%s needs %s, which only goes live in %s (after %s)",
                                 name[late$enabler_id], name[late$requires_id],
                                 lbl(f[late$requires_id]), lbl(f[late$enabler_id])),
               stringsAsFactors = FALSE)
  )
  rownames(out) <- NULL
  out
}

#' Share of each result held by each process (result x process, rows sum to 1)
#'
#' A result belongs to its lead process (result.process_id) unless the
#' optional result_process sheet lists it: then it is split across the
#' listed processes by share.
process_shares <- function(data) {
  r <- data$result
  pids <- data$process$id
  m <- matrix(0, nrow(r), length(pids), dimnames = list(r$id, pids))
  m[cbind(r$id, r$process_id)] <- 1
  rp <- data$result_process
  if (!is.null(rp) && nrow(rp)) {
    rp <- rp[rp$result_id %in% r$id & rp$process_id %in% pids, ]
    m[unique(rp$result_id), ] <- 0
    m[cbind(rp$result_id, rp$process_id)] <- rp$share
  }
  m / pmax(rowSums(m), 1e-12)
}

#' Weight of each result for a set of processes (sum of their shares)
process_weights <- function(graph, result_ids, process_ids) {
  rowSums(graph$share[result_ids, intersect(process_ids, colnames(graph$share)), drop = FALSE])
}

#' Results a process holds (any share), and the processes of a result
results_of_process <- function(graph, pid) rownames(graph$share)[graph$share[, pid] > 0]
processes_of_result <- function(graph, rid) colnames(graph$share)[graph$share[rid, ] > 0]
