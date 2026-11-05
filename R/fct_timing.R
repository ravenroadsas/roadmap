# Timing view for the Sensitivity tab: what the scenario does to dates,
# late dependencies and investment, compared with no acceleration.

#' Quarter label of the quarter containing time t ("2028Q3")
q_of <- function(t) ifelse(is.na(t), "\u2013", time_to_q(ceiling(t * 4 - 1e-9) / 4 - 0.25))

#' Dates, late dependencies and cost of the scenario vs no acceleration
#' @param model scenario run_model().
#' @param plan_model run_model() with the same assumptions, no extra resources.
timing_summary <- function(data, model, plan_model) {
  sch <- model$schedule
  extra <- rowSums(model$cost) - rowSums(plan_model$cost)
  acc <- sch[sch$resources > 1 + 1e-9, ]
  late <- function(m) sum(m$issues$type == "prereq_ends_later")
  last_ms <- function(m) last_result_time(data, m, "any")
  pf <- portfolio(model)
  pp <- portfolio(plan_model)
  list(
    last_ms_plan = last_ms(plan_model), last_ms = last_ms(model),
    end_plan = max(plan_model$schedule$end), end = max(sch$end),
    late_plan = late(plan_model), late = late(model),
    late_res_plan = nrow(plan_model$late), late_res = nrow(model$late),
    extra_cost = sum(extra), npv_diff = pf$npv - pp$npv, value_diff = pf$total_value - pp$total_value,
    accelerated = data.frame(
      id = acc$id, name = data$enabler$name[match(acc$id, data$enabler$id)],
      scalability = acc$scalability, resources = acc$resources,
      end_plan = acc$end_plan, end = acc$end, extra_cost = unname(extra[acc$id]),
      stringsAsFactors = FALSE)
  )
}

#' Timing panel
#' @param solved solve_target() result, or NULL in uniform mode.
timing_ui <- function(data, model, plan_model, solved = NULL) {
  s <- timing_summary(data, model, plan_model)
  ename <- function(id) data$enabler$name[match(id, data$enabler$id)]
  goal <- if (is.null(solved)) "" else if (solved$scope == "due") "Every result by its due date" else
    sprintf("Target %s", q_of(solved$target))
  head <- if (is.null(solved)) {
    NULL
  } else if (solved$feasible) {
    tags$div(class = "callout ok", tags$b(goal, " is reachable. "),
      sprintf("%d enabler%s get extra resources; the extra investment is %s.",
              nrow(s$accelerated), if (nrow(s$accelerated) == 1) "" else "s", fmt_musd(s$extra_cost)))
  } else {
    b <- solved$blockers
    tags$div(class = "callout issue",
      tags$b(goal, " can't be met. "),
      sprintf("Best achievable: last result %s, roadmap complete %s. Limited by:", q_of(s$last_ms), q_of(s$end)),
      tags$ul(lapply(seq_len(nrow(b)), function(i) tags$li(ename(b$enabler_id[i]), ": ", b$reason[i]))))
  }
  arrow <- function(a, b) if (identical(a, b)) a else paste(a, "\u2192", b)
  tagList(
    head,
    kv(c("Last result ready", "Roadmap complete", "Late results"),
       list(arrow(q_of(s$last_ms_plan), q_of(s$last_ms)),
            arrow(q_of(s$end_plan), q_of(s$end)),
            cls(if (s$late_res == s$late_res_plan) as.character(s$late_res) else paste(s$late_res_plan, "\u2192", s$late_res),
                if (s$late_res > 0) "neg" else ""))),
    if (s$late > 0 || s$late_plan > 0) kv(c("Late dependencies", "", ""),
       list(cls(if (s$late == s$late_plan) as.character(s$late) else paste(s$late_plan, "\u2192", s$late),
                if (s$late > 0) "neg" else ""), "", "")),
    kv(c("Extra investment", "Value to horizon", "NPV"),
       list(cls(sprintf("%+.1f $M", s$extra_cost), if (s$extra_cost > 0.05) "neg" else ""),
            cls(sprintf("%+.1f $M", s$value_diff), if (s$value_diff > 0.05) "pos" else ""),
            cls(sprintf("%+.1f $M", s$npv_diff), sign_cls(s$npv_diff)))),
    if (nrow(s$accelerated)) {
      a <- s$accelerated[order(-s$accelerated$extra_cost), ]
      blk <- if (is.null(solved)) character(0) else solved$blockers$enabler_id
      tags$table(class = "t",
        tags$thead(tags$tr(tags$th("Enabler accelerated"), tags$th(class = "r", "Scalability"),
                           tags$th(class = "r", "Resources"), tags$th(class = "r", "Plan end"),
                           tags$th(class = "r", "New end"), tags$th(class = "r", "Extra $M"))),
        tags$tbody(lapply(seq_len(nrow(a)), function(i) tags$tr(class = if (a$id[i] %in% blk) "late",
          tags$td(a$name[i]), tags$td(class = "r", formatC(a$scalability[i], format = "f", digits = 1)),
          tags$td(class = "r", sprintf("x%.2f", a$resources[i])),
          tags$td(class = "r", q_of(a$end_plan[i])), tags$td(class = "r", q_of(a$end[i])),
          tags$td(class = "r", sprintf("%+.1f", a$extra_cost[i]))))))
    } else tags$p(class = "hint", style = "margin:0", "No enabler gets extra resources in this scenario."),
    late_ui(model$late),
    if (s$late > 0) issues_ui(model$issues[model$issues$type == "prereq_ends_later", ])
  )
}
