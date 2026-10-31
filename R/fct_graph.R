# Dependency graph between enablers, and the enabler -> KPI attribution.

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

#' Decimal year back to a quarter label
time_to_q <- function(t) {
  y <- floor(t + 1e-9)
  paste0(y, "Q", round((t - y) * 4) + 1)
}

#' Check the data for broken references and dependency cycles
#'
#' These are blocking errors. Date inconsistencies are not: they load and
#' are reported by date_issues() so the app can show them in red.
#' @return character vector of problems (empty when valid).
graph_validate <- function(data) {
  e <- data$enabler$id
  k <- data$kpi$id
  dep <- data$enabler_dependency
  lk <- data$enabler_link
  probs <- c(
    sprintf("kpi %s: unknown process %s",
            data$kpi$id, data$kpi$process_id)[!data$kpi$process_id %in% data$process$id],
    sprintf("link %s-%s: unknown enabler", lk$enabler_id, lk$kpi_id)[!lk$enabler_id %in% e],
    sprintf("link %s-%s: unknown kpi", lk$enabler_id, lk$kpi_id)[!lk$kpi_id %in% k],
    sprintf("dependency %s-%s: unknown enabler", dep$enabler_id, dep$requires_id)[
      !(dep$enabler_id %in% e & dep$requires_id %in% e)],
    sprintf("kpi %s has no enabler", k)[!k %in% lk$kpi_id],
    sprintf("milestone %s: unknown enabler", data$milestone$id)[
      !data$milestone$enabler_id %in% e]
  )
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
#'   (enabler x KPI), cost allocation shares, KPI chains and ready dates.
build_graph <- function(data) {
  probs <- graph_validate(data)
  if (length(probs)) stop("Invalid roadmap data:\n", paste(probs, collapse = "\n"))

  ids <- data$enabler$id
  kids <- data$kpi$id
  dep <- data$enabler_dependency
  prereq <- lapply(stats::setNames(ids, ids), function(i) dep$requires_id[dep$enabler_id == i])
  dependents <- lapply(stats::setNames(ids, ids), function(i) dep$enabler_id[dep$requires_id == i])

  # direct weights, normalised per KPI
  w <- matrix(0, length(ids), length(kids), dimnames = list(ids, kids))
  lk <- data$enabler_link
  w[cbind(lk$enabler_id, lk$kpi_id)] <- lk$weight
  wn <- sweep(w, 2, pmax(colSums(w), 1e-12), "/")

  # cost flow: direct weight + an equal share of each dependent's flow,
  # so foundations carry the KPIs of everything built on them
  flow <- matrix(NA_real_, length(ids), length(kids), dimnames = list(ids, kids))
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
  chains <- lapply(stats::setNames(kids, kids), function(k) {
    direct <- ids[wn[, k] > 0]
    found <- setdiff(ancestors(direct, prereq), direct)
    list(direct = direct, foundation = found)
  })
  ready <- vapply(chains, function(ch) max(end_t[c(ch$direct, ch$foundation)]), numeric(1))

  list(ids = ids, kpis = kids, prereq = prereq, dependents = dependents,
       weight = wn, alloc = alloc, chains = chains, ready = ready,
       issues = date_issues(data))
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

#' Date inconsistencies in the plan (non-blocking)
#'
#' * `end_before_start`: end quarter earlier than start quarter.
#' * `prereq_ends_later`: a prerequisite goes live after the enabler that needs it.
#' @return data frame enabler_id, related_id, type, message (one row per issue).
date_issues <- function(data) {
  e <- data$enabler
  s <- stats::setNames(q_to_time(e$start_q), e$id)
  f <- stats::setNames(q_to_time(e$end_q, TRUE), e$id)
  name <- stats::setNames(e$name, e$id)
  bad <- e$id[f <= s]
  dep <- data$enabler_dependency
  dep <- dep[dep$enabler_id %in% e$id & dep$requires_id %in% e$id, ]
  late <- dep[f[dep$requires_id] > f[dep$enabler_id] + 1e-9, ]
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
                                 e$end_q[match(late$requires_id, e$id)],
                                 e$end_q[match(late$enabler_id, e$id)]),
               stringsAsFactors = FALSE)
  )
  rownames(out) <- NULL
  out
}
