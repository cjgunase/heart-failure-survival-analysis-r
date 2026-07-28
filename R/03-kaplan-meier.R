# Stage 2: Overall Kaplan-Meier survival estimation.
#
# This script:
#   1. creates a survival outcome with survival::Surv(),
#   2. calculates the Kaplan-Meier estimator from risk-set arithmetic,
#   3. confirms the manual calculation against survival::survfit(), and
#   4. saves an overall survival curve and numbers-at-risk table.

required_packages <- c(
  "dplyr",
  "ggplot2",
  "patchwork",
  "readr",
  "survival"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "Install missing packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

library(dplyr)
library(ggplot2)
library(patchwork)
library(readr)
library(survival)

clean_file <- file.path(
  "data",
  "processed",
  "heart_failure_clean.csv"
)

if (!file.exists(clean_file)) {
  stop("Clean data not found. Run R/02-exploratory-analysis.R first.")
}

dir.create(file.path("outputs", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "figures"), recursive = TRUE, showWarnings = FALSE)

heart <- read_csv(clean_file, show_col_types = FALSE)

if (any(is.na(heart$followup_days)) || any(heart$followup_days <= 0)) {
  stop("All follow-up times must be known and positive.")
}

if (any(is.na(heart$death)) || any(!heart$death %in% c(0, 1))) {
  stop("The death indicator must contain only 0 (censored) and 1 (event).")
}

# Surv() stores each person's observed time and event status together.
survival_outcome <- with(
  heart,
  Surv(time = followup_days, event = death)
)

# Manual Kaplan-Meier calculation ---------------------------------------------
#
# At each observed time:
#   n.risk  = number still under observation immediately before that time
#   n.event = number of deaths at that time
#
# The conditional survival probability is:
#   p_j = (n.risk - n.event) / n.risk
#
# The Kaplan-Meier estimate multiplies all conditional probabilities through t:
#   S(t) = product of p_j for event times <= t

manual_km <- heart |>
  group_by(followup_days) |>
  summarise(
    n_event = sum(death == 1),
    n_censor = sum(death == 0),
    .groups = "drop"
  ) |>
  arrange(followup_days) |>
  rowwise() |>
  mutate(
    n_risk = sum(heart$followup_days >= followup_days)
  ) |>
  ungroup() |>
  mutate(
    conditional_survival = (n_risk - n_event) / n_risk,
    survival = cumprod(conditional_survival)
  ) |>
  select(
    time = followup_days,
    n_risk,
    n_event,
    n_censor,
    conditional_survival,
    survival
  )

# Package calculation ---------------------------------------------------------

km_fit <- survfit(
  survival_outcome ~ 1,
  conf.type = "log",
  data = heart
)

package_km <- tibble(
  time = km_fit$time,
  n_risk = km_fit$n.risk,
  n_event = km_fit$n.event,
  n_censor = km_fit$n.censor,
  survival = km_fit$surv,
  standard_error = km_fit$std.err,
  lower_95 = km_fit$lower,
  upper_95 = km_fit$upper
)

comparison <- manual_km |>
  select(time, manual_survival = survival) |>
  left_join(
    package_km |>
      select(time, package_survival = survival),
    by = "time"
  ) |>
  mutate(
    absolute_difference = abs(manual_survival - package_survival)
  )

maximum_difference <- max(comparison$absolute_difference, na.rm = TRUE)

if (maximum_difference > 1e-12) {
  stop(
    "Manual and package Kaplan-Meier estimates disagree. Maximum difference: ",
    maximum_difference
  )
}

write_csv(
  manual_km,
  file.path("outputs", "tables", "kaplan-meier-event-table.csv")
)

write_csv(
  comparison,
  file.path("outputs", "tables", "kaplan-meier-validation.csv")
)

# Estimates at interpretable follow-up times ---------------------------------

report_times <- c(30, 60, 90, 180, 270)
time_summary <- summary(
  km_fit,
  times = report_times,
  extend = FALSE,
  data.frame = TRUE
)

selected_estimates <- tibble(
  time_days = time_summary$time,
  n_risk = time_summary$n.risk,
  survival = time_summary$surv,
  lower_95 = time_summary$lower,
  upper_95 = time_summary$upper
)

write_csv(
  selected_estimates,
  file.path("outputs", "tables", "kaplan-meier-selected-times.csv")
)

fit_table <- summary(km_fit)$table
median_summary <- tibble(
  statistic = c(
    "Number of patients",
    "Observed deaths",
    "Median survival days",
    "Median survival lower 95%",
    "Median survival upper 95%"
  ),
  value = c(
    unname(fit_table["records"]),
    unname(fit_table["events"]),
    unname(fit_table["median"]),
    unname(fit_table["0.95LCL"]),
    unname(fit_table["0.95UCL"])
  )
)

write_csv(
  median_summary,
  file.path("outputs", "tables", "kaplan-meier-summary.csv")
)

# Overall Kaplan-Meier figure -------------------------------------------------

plot_data <- bind_rows(
  tibble(
    time = 0,
    n_risk = nrow(heart),
    n_event = 0,
    n_censor = 0,
    survival = 1,
    standard_error = 0,
    lower_95 = 1,
    upper_95 = 1
  ),
  package_km
)

censor_data <- package_km |>
  filter(n_censor > 0)

risk_times <- c(0, 30, 60, 90, 120, 180, 240, 285)
risk_table <- tibble(
  time = risk_times,
  n_risk = vapply(
    risk_times,
    function(current_time) sum(heart$followup_days >= current_time),
    integer(1)
  )
)

write_csv(
  risk_table,
  file.path("outputs", "tables", "numbers-at-risk.csv")
)

survival_plot <- ggplot(plot_data, aes(x = time, y = survival)) +
  geom_step(linewidth = 0.9, color = "#2457A7") +
  geom_step(
    aes(y = lower_95),
    linewidth = 0.45,
    linetype = "dashed",
    color = "#6D86B3"
  ) +
  geom_step(
    aes(y = upper_95),
    linewidth = 0.45,
    linetype = "dashed",
    color = "#6D86B3"
  ) +
  geom_point(
    data = censor_data,
    shape = 3,
    size = 2,
    stroke = 0.7,
    color = "#B0483F"
  ) +
  scale_x_continuous(
    limits = c(-8, 290),
    breaks = c(0, 30, 60, 90, 120, 180, 240, 285),
    expand = expansion(mult = c(0, 0.01))
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  labs(
    title = "Overall Kaplan–Meier survival estimate",
    subtitle = "Dashed lines: 95% confidence interval; + marks: censoring",
    x = "Follow-up time (days)",
    y = "Estimated survival probability"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

risk_plot <- ggplot(risk_table, aes(x = time, y = 0, label = n_risk)) +
  geom_text(size = 3.5) +
  scale_x_continuous(
    limits = c(-8, 290),
    breaks = c(0, 30, 60, 90, 120, 180, 240, 285),
    expand = expansion(mult = c(0, 0.01))
  ) +
  scale_y_continuous(limits = c(-0.5, 0.5)) +
  labs(
    title = "Number at risk",
    x = "Follow-up time (days)",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid = element_blank(),
    plot.title = element_text(size = 11)
  )

combined_plot <- survival_plot / risk_plot +
  plot_layout(heights = c(4, 1))

ggsave(
  file.path("outputs", "figures", "overall-kaplan-meier.png"),
  combined_plot,
  width = 9,
  height = 7,
  dpi = 300,
  bg = "white"
)

message("Kaplan-Meier analysis complete.")
message("Patients: ", unname(fit_table["records"]))
message("Observed deaths: ", unname(fit_table["events"]))
message("Median survival: ", unname(fit_table["median"]), " days")
message(
  "Manual/package maximum absolute difference: ",
  format(maximum_difference, scientific = TRUE)
)
message("Tables: outputs/tables/")
message("Figure: outputs/figures/overall-kaplan-meier.png")
