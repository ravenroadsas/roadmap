# Formatting and user helpers.

fmt_musd <- function(x, digits = 1) {
  ifelse(is.na(x), "\u2013",
         paste0(ifelse(x < 0, "\u2212", ""), "$",
                formatC(abs(x), format = "f", digits = digits, big.mark = ","), "M"))
}

fmt_pct <- function(x, digits = 0) {
  ifelse(is.na(x), "\u2013", paste0(formatC(x * 100, format = "f", digits = digits), "%"))
}

fmt_num <- function(x, unit = "") {
  s <- ifelse(abs(x) >= 1000, formatC(x, format = "d", big.mark = ","),
              format(x, trim = TRUE, drop0trailing = TRUE))
  ifelse(unit == "$M", paste0("$", s, "M"),
         ifelse(unit == "%", paste0(s, "%"), paste(s, unit)))
}

fmt_cfg <- function(row, v = row$value) {
  if (isTRUE(row$is_pct)) fmt_pct(v)
  else if (row$key == "horizon_end") as.character(v)
  else if (identical(row$unit, "x")) sprintf("\u00d7%.2f", v)
  else paste(v, row$unit)
}

GROUPS <- data.frame(
  id = c("people", "digital", "data", "infra"),
  name = c("People & adoption", "Digital solutions", "Data", "Infrastructure"),
  stringsAsFactors = FALSE
)

#' Quarter label of the quarter containing time t ("2028Q3")
q_of <- function(t) ifelse(is.na(t), "\u2013", time_to_q(ceiling(t * 4 - 1e-9) / 4 - 0.25))

# Digital maturity levels (framework: BPMM / OMG, acatech Industrie 4.0
# Maturity Index, CMMI, Deloitte Digital and AI Maturity)
LEVELS <- data.frame(
  level = 1:5,
  code = paste0("M", 1:5),
  name = c("Manual", "Assisted", "Integrated", "Automated", "Adaptive"),
  key = c("Dependence on human intervention", "Digital support to execution",
          "End-to-end integration and traceability", "Automation and data-driven decisions",
          "Anticipation, adaptability and continuous optimisation"),
  description = c(
    "Mostly manual activities, scattered information, isolated digital tools. Management, validation and decisions rely on people's knowledge and judgement.",
    "Digital tools support execution, recording, consultation and follow-up. Activities and decisions stay mainly under human control, with limited automation and manual steps between systems.",
    "Standardised workflows connected end to end. Systems, data and areas exchange information in a structured, traceable way; there is an integrated view of process performance.",
    "Workflows, business rules, algorithms and analytical models execute tasks, validate conditions, detect deviations and recommend or take decisions within set parameters. People focus on exceptions, supervision and high-impact decisions.",
    "Real-time data, advanced analytics and AI anticipate conditions, evaluate scenarios and adjust execution dynamically, with continuous learning and autonomous decisions within operating, safety and governance limits."),
  stringsAsFactors = FALSE)

# How the levels differ, by dimension
LEVEL_DIMENSIONS <- data.frame(
  dimension = c("Execution", "Information", "Systems", "Decisions", "Human intervention", "Improvement"),
  M1 = c("Manual", "Scattered", "Isolated", "Human", "Permanent", "Reactive"),
  M2 = c("Digitally assisted", "Digitised", "Support tools", "Supported by data", "High", "Follow-up"),
  M3 = c("Connected flows", "Integrated", "Interoperable", "Based on integrated information", "Supervision and management", "Systematic measurement"),
  M4 = c("Automated", "Analysed", "Orchestrated", "Recommended or automated", "Exceptions and supervision", "Data-driven optimisation"),
  M5 = c("Adaptive", "Predictive", "Intelligent", "Predictive and adaptive", "Strategy, exceptions and governance", "Continuous learning"),
  stringsAsFactors = FALSE)

# The six dimensions used to assess a process's current level
ASSESSMENT_DIMENSIONS <- data.frame(
  dimension = c("Digitalisation of activities", "Integration and architecture", "Data management and quality",
                "Automation", "Intelligence and decisions", "Adaptability and optimisation"),
  criterion = c("Share of activities executed with digital tools",
                "How connected the systems, applications and actors of the process are",
                "Availability, reliability, timeliness, traceability and use of data",
                "Which activities, flows and rules run automatically",
                "Use of descriptive, diagnostic, predictive and prescriptive analytics to decide",
                "Ability to learn, anticipate change and adjust operation dynamically"),
  stringsAsFactors = FALSE)

# Proposed impact curves: % of a metric's impact reached at each level
DEFAULT_CURVES <- data.frame(
  id = c("concave", "threshold", "linear", "s_curve"),
  name = c("Diminishing returns", "Threshold", "Linear", "S-curve"),
  m1 = c(0, 0, 0, 0), m2 = c(45, 5, 25, 10), m3 = c(75, 15, 50, 45),
  m4 = c(92, 55, 75, 85), m5 = c(100, 100, 100, 100),
  description = c("Most of the impact comes with the first steps; each further level adds less (e.g. production, deferred production)",
                  "Little impact until the process is automated (e.g. man-hours saved, headcount ratios)",
                  "Each level adds the same impact",
                  "Impact concentrates on integration and automation (e.g. cycle times, non-productive time)"),
  stringsAsFactors = FALSE)

#' Level code "M3" (NA-safe)
lvl <- function(x) ifelse(is.na(x), "\u2013", paste0("M", x))
