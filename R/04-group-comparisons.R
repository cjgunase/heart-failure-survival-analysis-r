# Stage 3: Grouped Kaplan-Meier curves and log-rank tests.
#
# Primary educational comparison:
#   ejection fraction below 40% versus 40% or higher
#
# Secondary comparison:
#   female versus male
#
# Categorizing a continuous measurement such as ejection fraction loses
# information. The later Cox model will use ejection fraction continuously.

required_packages <- c(
  "broom",
  "dplyr",
  "ggplot2",
  "patchwork",
  "readr",
  "scales",
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

library(broom)
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

heart <- read_csv(clean_file, show_col_types = FALSE) |>
  mutate(
    ef_group = factor(
      if_else(ejection_fraction < 40, "EF < 40%", "EF ≥ 40%"),
      levels = c("EF < 40%", "EF ≥ 40%")
    ),
    sex_group = factor(
      sex,
      levels = c(0, 1),
      labels = c("Female", "Male")
    )
  )

group_summary <- function(data, group_variable) {
  data |>
    group_by(group = .data[[group_variable]]) |>
    summarise(
      patients = n(),
      deaths = sum(death == 1),
      censored = sum(death == 0),
      observed_death_proportion = mean(death),
      median_observed_followup = median(followup_days),
      .groups = "drop"
    )
}

log_rank_result <- function(fit, comparison_name) {
  degrees_freedom <- length(fit$n) - 1L

  tibble(
    comparison = comparison_name,
    chi_square = unname(fit$chisq),
    degrees_freedom = degrees_freedom,
    p_value = pchisq(
      fit$chisq,
      df = degrees_freedom,
      lower.tail = FALSE
    )
  )
}

selected_group_estimates <- function(fit, comparison_name) {
  result <- summary(
    fit,
    times = c(30, 90, 180),
    extend = TRUE,
    data.frame = TRUE
  )

  tibble(
    comparison = comparison_name,
    group = sub("^[^=]+=", "", result$strata),
    time_days = result$time,
    n_risk = result$n.risk,
    survival = result$surv,
    lower_95 = result$lower,
    upper_95 = result$upper
  )
}

grouped_km_plot <- function(fit, title, log_rank_p) {
  curve_data <- tidy(fit) |>
    mutate(group = sub("^[^=]+=", "", strata))

  initial_data <- summary(
    fit,
    times = 0,
    extend = TRUE,
    data.frame = TRUE
  ) |>
    as_tibble() |>
    transmute(
      time = time,
      n.risk = n.risk,
      n.event = n.event,
      n.censor = n.censor,
      estimate = surv,
      std.error = std.err,
      conf.high = upper,
      conf.low = lower,
      strata = strata,
      group = sub("^[^=]+=", "", strata)
    )

  plot_data <- bind_rows(initial_data, curve_data)
  group_levels <- unique(initial_data$group)

  censor_data <- curve_data |>
    filter(n.censor > 0)

  risk_times <- c(0, 30, 60, 90, 120, 180, 240, 285)
  risk_summary <- summary(
    fit,
    times = risk_times,
    extend = TRUE,
    data.frame = TRUE
  ) |>
    as_tibble() |>
    transmute(
      time = time,
      n_risk = n.risk,
      group = factor(
        sub("^[^=]+=", "", strata),
        levels = group_levels
      )
    )

  main_plot <- ggplot(
    plot_data,
    aes(x = time, y = estimate, color = group)
  ) +
    geom_step(linewidth = 0.9) +
    geom_step(
      aes(y = conf.low),
      linewidth = 0.4,
      linetype = "dotted",
      alpha = 0.55
    ) +
    geom_step(
      aes(y = conf.high),
      linewidth = 0.4,
      linetype = "dotted",
      alpha = 0.55
    ) +
    geom_point(
      data = censor_data,
      shape = 3,
      size = 1.8,
      stroke = 0.65
    ) +
    scale_color_brewer(palette = "Dark2") +
    scale_x_continuous(
      limits = c(-8, 290),
      breaks = risk_times,
      expand = expansion(mult = c(0, 0.01))
    ) +
    scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2),
      labels = scales::label_percent(accuracy = 1),
      expand = expansion(mult = c(0, 0.02))
    ) +
    labs(
      title = title,
      subtitle = paste0(
        "Dotted lines: 95% CI; + marks: censoring; log-rank p = ",
        format.pval(log_rank_p, digits = 3, eps = 0.001)
      ),
      x = "Follow-up time (days)",
      y = "Estimated survival probability",
      color = "Group"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "top",
      plot.title.position = "plot"
    )

  risk_plot <- ggplot(
    risk_summary,
    aes(x = time, y = group, label = n_risk, color = group)
    ) +
    geom_text(size = 3.3, show.legend = FALSE) +
    scale_color_brewer(palette = "Dark2") +
    scale_y_discrete(limits = rev(group_levels)) +
    scale_x_continuous(
      limits = c(-8, 290),
      breaks = risk_times,
      expand = expansion(mult = c(0, 0.01))
    ) +
    labs(
      title = "Number at risk",
      x = "Follow-up time (days)",
      y = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      axis.ticks.y = element_blank(),
      panel.grid = element_blank(),
      plot.title = element_text(size = 11)
    )

  main_plot / risk_plot +
    plot_layout(heights = c(4, 1.2))
}

# Fit grouped Kaplan-Meier curves ---------------------------------------------

ef_km <- survfit(
  Surv(followup_days, death) ~ ef_group,
  data = heart,
  conf.type = "log"
)

sex_km <- survfit(
  Surv(followup_days, death) ~ sex_group,
  data = heart,
  conf.type = "log"
)

# The log-rank test compares observed versus expected deaths across groups over
# the full follow-up period. It does not estimate effect size or causality.
ef_log_rank <- survdiff(
  Surv(followup_days, death) ~ ef_group,
  data = heart
)

sex_log_rank <- survdiff(
  Surv(followup_days, death) ~ sex_group,
  data = heart
)

ef_test <- log_rank_result(ef_log_rank, "Ejection fraction group")
sex_test <- log_rank_result(sex_log_rank, "Sex")

write_csv(
  bind_rows(ef_test, sex_test),
  file.path("outputs", "tables", "log-rank-tests.csv")
)

write_csv(
  group_summary(heart, "ef_group"),
  file.path("outputs", "tables", "ejection-fraction-group-summary.csv")
)

write_csv(
  group_summary(heart, "sex_group"),
  file.path("outputs", "tables", "sex-group-summary.csv")
)

write_csv(
  bind_rows(
    selected_group_estimates(ef_km, "Ejection fraction group"),
    selected_group_estimates(sex_km, "Sex")
  ),
  file.path("outputs", "tables", "grouped-survival-selected-times.csv")
)

ef_plot <- grouped_km_plot(
  ef_km,
  "Survival by baseline ejection-fraction group",
  ef_test$p_value
)

sex_plot <- grouped_km_plot(
  sex_km,
  "Survival by sex",
  sex_test$p_value
)

ggsave(
  file.path("outputs", "figures", "kaplan-meier-ejection-fraction.png"),
  ef_plot,
  width = 9,
  height = 7.5,
  dpi = 300,
  bg = "white"
)

ggsave(
  file.path("outputs", "figures", "kaplan-meier-sex.png"),
  sex_plot,
  width = 9,
  height = 7.5,
  dpi = 300,
  bg = "white"
)

message("Grouped Kaplan-Meier analysis complete.")
message(
  "Ejection-fraction log-rank p-value: ",
  format.pval(ef_test$p_value, digits = 4)
)
message(
  "Sex log-rank p-value: ",
  format.pval(sex_test$p_value, digits = 4)
)
message("Tables: outputs/tables/")
message("Figures: outputs/figures/")
