# Stage 4: Cox proportional-hazards regression.
#
# The model estimates prognostic associations with the instantaneous mortality
# hazard. It does not estimate causal effects.
#
# Prespecified predictors:
#   age                       per 10-year increase
#   ejection fraction         per 5-percentage-point increase
#   serum creatinine          per doubling
#   serum sodium              per 5-mEq/L increase
#   sex                       male versus female

required_packages <- c(
  "broom",
  "dplyr",
  "ggplot2",
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

library(broom)
library(dplyr)
library(ggplot2)
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
    age_per_10_years = age / 10,
    ef_per_5_points = ejection_fraction / 5,
    creatinine_per_doubling = log2(serum_creatinine),
    sodium_per_5_units = serum_sodium / 5,
    sex_group = factor(
      sex,
      levels = c(0, 1),
      labels = c("Female", "Male")
    )
  )

model_variables <- c(
  "followup_days",
  "death",
  "age_per_10_years",
  "ef_per_5_points",
  "creatinine_per_doubling",
  "sodium_per_5_units",
  "sex_group"
)

if (any(is.na(heart[model_variables]))) {
  stop("The prespecified Cox-model variables contain missing values.")
}

if (any(heart$serum_creatinine <= 0)) {
  stop("Serum creatinine must be positive before log2 transformation.")
}

predictor_labels <- c(
  age_per_10_years = "Age, per 10-year increase",
  ef_per_5_points = "Ejection fraction, per 5-point increase",
  creatinine_per_doubling = "Serum creatinine, per doubling",
  sodium_per_5_units = "Serum sodium, per 5-mEq/L increase",
  sex_groupMale = "Male versus female"
)

predictors <- c(
  "age_per_10_years",
  "ef_per_5_points",
  "creatinine_per_doubling",
  "sodium_per_5_units",
  "sex_group"
)

fit_univariable_cox <- function(predictor) {
  model_formula <- as.formula(
    paste(
      "Surv(followup_days, death) ~",
      predictor
    )
  )

  fit <- coxph(
    model_formula,
    data = heart,
    ties = "efron"
  )

  tidy(
    fit,
    exponentiate = TRUE,
    conf.int = TRUE
  ) |>
    transmute(
      predictor = unname(predictor_labels[term]),
      hazard_ratio = estimate,
      lower_95 = conf.low,
      upper_95 = conf.high,
      p_value = p.value
    )
}

univariable_results <- bind_rows(
  lapply(predictors, fit_univariable_cox)
)

write_csv(
  univariable_results,
  file.path("outputs", "tables", "cox-univariable-results.csv")
)

# Multivariable model ---------------------------------------------------------
#
# Each hazard ratio is conditional on all other predictors in this formula.
# With 96 deaths and five model coefficients, the model has approximately
# 19 observed events per coefficient.

adjusted_model <- coxph(
  Surv(followup_days, death) ~
    age_per_10_years +
    ef_per_5_points +
    creatinine_per_doubling +
    sodium_per_5_units +
    sex_group,
  data = heart,
  ties = "efron",
  x = TRUE,
  y = TRUE,
  model = TRUE
)

adjusted_results <- tidy(
  adjusted_model,
  exponentiate = TRUE,
  conf.int = TRUE
) |>
  transmute(
    predictor = unname(predictor_labels[term]),
    hazard_ratio = estimate,
    lower_95 = conf.low,
    upper_95 = conf.high,
    p_value = p.value
  )

write_csv(
  adjusted_results,
  file.path("outputs", "tables", "cox-adjusted-results.csv")
)

model_glance <- glance(adjusted_model)

model_summary <- tibble(
  statistic = c(
    "Patients",
    "Observed deaths",
    "Model coefficients",
    "Events per coefficient",
    "Concordance",
    "Concordance standard error",
    "Likelihood-ratio chi-square",
    "Likelihood-ratio p-value",
    "Wald chi-square",
    "Wald p-value",
    "Score chi-square",
    "Score p-value"
  ),
  value = c(
    adjusted_model$n,
    adjusted_model$nevent,
    length(coef(adjusted_model)),
    adjusted_model$nevent / length(coef(adjusted_model)),
    model_glance$concordance,
    model_glance$std.error.concordance,
    model_glance$statistic.log,
    model_glance$p.value.log,
    model_glance$statistic.wald,
    model_glance$p.value.wald,
    model_glance$statistic.sc,
    model_glance$p.value.sc
  )
)

write_csv(
  model_summary,
  file.path("outputs", "tables", "cox-model-summary.csv")
)

# Proportional-hazards assessment --------------------------------------------
#
# A small p-value suggests that a predictor's coefficient may change over time.
# A large p-value is not proof that the assumption is exactly true.

ph_assessment <- cox.zph(
  adjusted_model,
  transform = "km",
  terms = TRUE,
  global = TRUE
)

ph_results <- as.data.frame(ph_assessment$table) |>
  tibble::rownames_to_column("term") |>
  as_tibble() |>
  rename(
    chi_square = chisq,
    degrees_freedom = df,
    p_value = p
  ) |>
  mutate(
    term = recode(
      term,
      age_per_10_years = "Age",
      ef_per_5_points = "Ejection fraction",
      creatinine_per_doubling = "Serum creatinine",
      sodium_per_5_units = "Serum sodium",
      sex_group = "Sex",
      GLOBAL = "Global test"
    )
  )

write_csv(
  ph_results,
  file.path("outputs", "tables", "cox-proportional-hazards-tests.csv")
)

# Adjusted hazard-ratio forest plot -------------------------------------------

forest_data <- adjusted_results |>
  mutate(
    predictor = factor(
      predictor,
      levels = rev(unname(predictor_labels))
    ),
    result_label = sprintf(
      "HR %.2f (95%% CI %.2f–%.2f)",
      hazard_ratio,
      lower_95,
      upper_95
    )
  )

forest_plot <- ggplot(
  forest_data,
  aes(x = hazard_ratio, y = predictor)
) +
  geom_vline(
    xintercept = 1,
    linetype = "dashed",
    linewidth = 0.6,
    color = "#666666"
  ) +
  geom_errorbar(
    aes(xmin = lower_95, xmax = upper_95),
    orientation = "y",
    width = 0.18,
    linewidth = 0.7,
    color = "#2457A7"
  ) +
  geom_point(
    size = 2.7,
    color = "#2457A7"
  ) +
  geom_text(
    aes(label = result_label),
    hjust = 0,
    nudge_x = 0.08,
    size = 3.4
  ) +
  scale_x_log10(
    limits = c(
      min(forest_data$lower_95) * 0.75,
      max(forest_data$upper_95) * 2.2
    ),
    breaks = c(0.5, 0.75, 1, 1.5, 2, 3),
    labels = scales::label_number(accuracy = 0.01)
  ) +
  labs(
    title = "Adjusted associations with mortality hazard",
    subtitle = "Cox proportional-hazards model",
    x = "Hazard ratio on logarithmic scale",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    plot.title.position = "plot"
  )

ggsave(
  file.path("outputs", "figures", "cox-adjusted-forest-plot.png"),
  forest_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

message("Cox regression analysis complete.")
message("Patients: ", adjusted_model$n)
message("Observed deaths: ", adjusted_model$nevent)
message(
  "Events per coefficient: ",
  round(adjusted_model$nevent / length(coef(adjusted_model)), 1)
)
message(
  "Concordance: ",
  round(model_glance$concordance, 3)
)
message(
  "Global proportional-hazards p-value: ",
  format.pval(
    ph_results$p_value[ph_results$term == "Global test"],
    digits = 4
  )
)
message("Tables: outputs/tables/")
message("Figure: outputs/figures/cox-adjusted-forest-plot.png")
