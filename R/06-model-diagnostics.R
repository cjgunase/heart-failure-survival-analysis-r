# Stage 5: Cox-model diagnostics.
#
# This script examines:
#   1. proportional-hazards residual patterns,
#   2. possible nonlinearity in continuous predictors,
#   3. deviance residuals, and
#   4. observations with relatively large DFBETAS.
#
# Diagnostic flags are prompts for investigation, not automatic reasons to
# delete observations or change the model.

required_packages <- c(
  "broom",
  "dplyr",
  "ggplot2",
  "patchwork",
  "readr",
  "survival",
  "tidyr"
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
library(splines)
library(survival)
library(tidyr)

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
    row_id = row_number(),
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

linear_model <- coxph(
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

term_labels <- c(
  age_per_10_years = "Age",
  ef_per_5_points = "Ejection fraction",
  creatinine_per_doubling = "Serum creatinine",
  sodium_per_5_units = "Serum sodium",
  sex_groupMale = "Sex: male versus female"
)

# Proportional-hazards diagnostics -------------------------------------------

ph_assessment <- cox.zph(
  linear_model,
  transform = "km",
  terms = TRUE,
  global = TRUE
)

ph_table <- as.data.frame(ph_assessment$table) |>
  tibble::rownames_to_column("term") |>
  as_tibble() |>
  rename(
    chi_square = chisq,
    degrees_freedom = df,
    p_value = p
  ) |>
  mutate(
    predictor = recode(
      term,
      age_per_10_years = "Age",
      ef_per_5_points = "Ejection fraction",
      creatinine_per_doubling = "Serum creatinine",
      sodium_per_5_units = "Serum sodium",
      sex_group = "Sex",
      GLOBAL = "Global test"
    )
  ) |>
  select(predictor, chi_square, degrees_freedom, p_value)

write_csv(
  ph_table,
  file.path("outputs", "tables", "diagnostic-proportional-hazards.csv")
)

schoenfeld_centers <- c(
  age_per_10_years = unname(coef(linear_model)["age_per_10_years"]),
  ef_per_5_points = unname(coef(linear_model)["ef_per_5_points"]),
  creatinine_per_doubling = unname(
    coef(linear_model)["creatinine_per_doubling"]
  ),
  sodium_per_5_units = unname(coef(linear_model)["sodium_per_5_units"]),
  sex_group = unname(coef(linear_model)["sex_groupMale"])
)

centered_schoenfeld <- sweep(
  ph_assessment$y,
  MARGIN = 2,
  STATS = schoenfeld_centers[colnames(ph_assessment$y)],
  FUN = "-"
)

schoenfeld_data <- as_tibble(
  centered_schoenfeld,
  .name_repair = "minimal"
) |>
  mutate(
    transformed_time = ph_assessment$x,
    event_time_days = ph_assessment$time
  ) |>
  pivot_longer(
    cols = -c(transformed_time, event_time_days),
    names_to = "term",
    values_to = "centered_scaled_schoenfeld_residual"
  ) |>
  mutate(
    predictor = recode(
      term,
      age_per_10_years = "Age",
      ef_per_5_points = "Ejection fraction",
      creatinine_per_doubling = "Serum creatinine",
      sodium_per_5_units = "Serum sodium",
      sex_group = "Sex: male versus female"
    )
  )

ph_plot <- ggplot(
  schoenfeld_data,
  aes(x = transformed_time, y = centered_scaled_schoenfeld_residual)
) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    linewidth = 0.5,
    color = "#666666"
  ) +
  geom_point(
    alpha = 0.45,
    size = 1.3,
    color = "#2457A7"
  ) +
  geom_smooth(
    method = "loess",
    formula = y ~ x,
    se = TRUE,
    linewidth = 0.8,
    color = "#B0483F",
    fill = "#E8B7B2"
  ) +
  facet_wrap(vars(predictor), scales = "free_y", ncol = 2) +
  labs(
    title = "Scaled Schoenfeld residuals",
    subtitle = "A systematic trend may indicate a time-varying coefficient",
    x = "Kaplan–Meier transformed follow-up time",
    y = "Centered scaled Schoenfeld value"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

ggsave(
  file.path("outputs", "figures", "cox-schoenfeld-residuals.png"),
  ph_plot,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Functional-form diagnostics ------------------------------------------------
#
# For each continuous predictor, compare the linear term with a natural spline
# using 3 degrees of freedom while leaving the other predictors unchanged.
# The likelihood-ratio test evaluates whether the two additional spline
# parameters improve model fit.

nonlinear_formulas <- list(
  "Age" = update(
    formula(linear_model),
    . ~ . - age_per_10_years + ns(age_per_10_years, df = 3)
  ),
  "Ejection fraction" = update(
    formula(linear_model),
    . ~ . - ef_per_5_points + ns(ef_per_5_points, df = 3)
  ),
  "Serum creatinine" = update(
    formula(linear_model),
    . ~ . - creatinine_per_doubling +
      ns(creatinine_per_doubling, df = 3)
  ),
  "Serum sodium" = update(
    formula(linear_model),
    . ~ . - sodium_per_5_units + ns(sodium_per_5_units, df = 3)
  )
)

nonlinearity_results <- bind_rows(lapply(
  names(nonlinear_formulas),
  function(predictor_name) {
    spline_fit <- coxph(
      nonlinear_formulas[[predictor_name]],
      data = heart,
      ties = "efron"
    )

    comparison <- anova(
      linear_model,
      spline_fit,
      test = "LRT"
    )

    tibble(
      predictor = predictor_name,
      added_degrees_freedom = comparison[2, "Df"],
      likelihood_ratio_chi_square = comparison[2, "Chisq"],
      p_value = comparison[2, "Pr(>|Chi|)"],
      linear_model_aic = AIC(linear_model),
      predictor_spline_model_aic = AIC(spline_fit)
    )
  }
))

write_csv(
  nonlinearity_results,
  file.path("outputs", "tables", "diagnostic-nonlinearity-tests.csv")
)

all_spline_model <- coxph(
  Surv(followup_days, death) ~
    ns(age_per_10_years, df = 3) +
    ns(ef_per_5_points, df = 3) +
    ns(creatinine_per_doubling, df = 3) +
    ns(sodium_per_5_units, df = 3) +
    sex_group,
  data = heart,
  ties = "efron"
)

all_spline_comparison <- anova(
  linear_model,
  all_spline_model,
  test = "LRT"
)

model_shape_comparison <- tibble(
  model = c(
    "Linear predictor terms",
    "All continuous predictors as 3-df natural splines"
  ),
  coefficients = c(
    length(coef(linear_model)),
    length(coef(all_spline_model))
  ),
  log_likelihood = c(
    as.numeric(logLik(linear_model)),
    as.numeric(logLik(all_spline_model))
  ),
  aic = c(
    AIC(linear_model),
    AIC(all_spline_model)
  ),
  likelihood_ratio_chi_square = c(
    NA_real_,
    all_spline_comparison[2, "Chisq"]
  ),
  added_degrees_freedom = c(
    NA_real_,
    all_spline_comparison[2, "Df"]
  ),
  likelihood_ratio_p_value = c(
    NA_real_,
    all_spline_comparison[2, "Pr(>|Chi|)"]
  )
)

write_csv(
  model_shape_comparison,
  file.path("outputs", "tables", "diagnostic-model-shape-comparison.csv")
)

# Visualize the ejection-fraction functional form -----------------------------
#
# The predictor-specific test suggests that a straight-line term may be too
# simple for ejection fraction. Estimate its adjusted relative-hazard curve with
# a 3-df natural spline, using ejection fraction of 40% as the reference.

ef_spline_model <- coxph(
  Surv(followup_days, death) ~
    age_per_10_years +
    ns(ef_per_5_points, df = 3) +
    creatinine_per_doubling +
    sodium_per_5_units +
    sex_group,
  data = heart,
  ties = "efron"
)

ef_grid <- seq(
  min(heart$ejection_fraction),
  max(heart$ejection_fraction),
  length.out = 150
)

reference_ef <- 40

newdata_grid <- tibble(
  age_per_10_years = median(heart$age_per_10_years),
  ef_per_5_points = ef_grid / 5,
  creatinine_per_doubling = median(heart$creatinine_per_doubling),
  sodium_per_5_units = median(heart$sodium_per_5_units),
  sex_group = factor(
    "Female",
    levels = levels(heart$sex_group)
  )
)

reference_data <- newdata_grid |>
  slice(1) |>
  mutate(ef_per_5_points = reference_ef / 5)

design_terms <- delete.response(terms(ef_spline_model))
grid_matrix <- model.matrix(design_terms, newdata_grid)
reference_matrix <- model.matrix(design_terms, reference_data)

coefficient_names <- names(coef(ef_spline_model))
grid_matrix <- grid_matrix[, coefficient_names, drop = FALSE]
reference_matrix <- reference_matrix[, coefficient_names, drop = FALSE]

contrast_matrix <- sweep(
  grid_matrix,
  MARGIN = 2,
  STATS = reference_matrix[1, ],
  FUN = "-"
)

log_hazard_ratio <- as.numeric(
  contrast_matrix %*% coef(ef_spline_model)
)

contrast_standard_error <- sqrt(
  rowSums(
    (contrast_matrix %*% vcov(ef_spline_model)) *
      contrast_matrix
  )
)

ef_spline_effect <- tibble(
  ejection_fraction = ef_grid,
  hazard_ratio = exp(log_hazard_ratio),
  lower_95 = exp(log_hazard_ratio - 1.96 * contrast_standard_error),
  upper_95 = exp(log_hazard_ratio + 1.96 * contrast_standard_error),
  reference_ejection_fraction = reference_ef
)

write_csv(
  ef_spline_effect,
  file.path(
    "outputs",
    "tables",
    "diagnostic-ejection-fraction-spline.csv"
  )
)

ef_spline_plot <- ggplot(
  ef_spline_effect,
  aes(x = ejection_fraction, y = hazard_ratio)
) +
  geom_hline(
    yintercept = 1,
    linetype = "dashed",
    linewidth = 0.5,
    color = "#666666"
  ) +
  geom_ribbon(
    aes(ymin = lower_95, ymax = upper_95),
    fill = "#A9BEE2",
    alpha = 0.55
  ) +
  geom_line(
    linewidth = 0.9,
    color = "#2457A7"
  ) +
  geom_rug(
    data = heart,
    aes(x = ejection_fraction),
    inherit.aes = FALSE,
    sides = "b",
    alpha = 0.25,
    color = "#555555"
  ) +
  annotate(
    "point",
    x = reference_ef,
    y = 1,
    size = 2.5,
    color = "#B0483F"
  ) +
  scale_y_log10() +
  labs(
    title = "Adjusted nonlinear association for ejection fraction",
    subtitle = "Natural spline with 3 df; EF 40% is the hazard-ratio reference",
    x = "Baseline ejection fraction (%)",
    y = "Adjusted hazard ratio on logarithmic scale"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

ggsave(
  file.path(
    "outputs",
    "figures",
    "cox-ejection-fraction-spline.png"
  ),
  ef_spline_plot,
  width = 9,
  height = 6,
  dpi = 300,
  bg = "white"
)

# Deviance residuals ---------------------------------------------------------

deviance_data <- heart |>
  transmute(
    row_id,
    followup_days,
    death,
    age,
    ejection_fraction,
    serum_creatinine,
    serum_sodium,
    deviance_residual = as.numeric(
      residuals(linear_model, type = "deviance")
    ),
    large_deviance_flag = abs(deviance_residual) > 3
  )

write_csv(
  deviance_data,
  file.path("outputs", "tables", "diagnostic-deviance-residuals.csv")
)

deviance_plot <- ggplot(
  deviance_data,
  aes(
    x = row_id,
    y = deviance_residual,
    shape = factor(death)
  )
) +
  geom_hline(
    yintercept = c(-3, 0, 3),
    linetype = c("dotted", "solid", "dotted"),
    linewidth = c(0.5, 0.4, 0.5),
    color = "#777777"
  ) +
  geom_point(
    aes(color = large_deviance_flag),
    alpha = 0.75,
    size = 1.8
  ) +
  scale_color_manual(
    values = c("FALSE" = "#2457A7", "TRUE" = "#B0483F"),
    labels = c("FALSE" = "No", "TRUE" = "Yes")
  ) +
  scale_shape_manual(
    values = c("0" = 1, "1" = 16),
    labels = c("0" = "Censored", "1" = "Death observed")
  ) +
  labs(
    title = "Cox-model deviance residuals",
    subtitle = "Absolute residual above 3 is shown as an investigation flag",
    x = "Dataset row index",
    y = "Deviance residual",
    color = "Flagged",
    shape = "Outcome"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "top",
    plot.title.position = "plot"
  )

ggsave(
  file.path("outputs", "figures", "cox-deviance-residuals.png"),
  deviance_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

# DFBETAS influence diagnostics ----------------------------------------------
#
# DFBETAS approximate how much each coefficient changes when one observation is
# removed. The 2/sqrt(n) threshold is a heuristic screening rule.

dfbetas_matrix <- residuals(
  linear_model,
  type = "dfbetas"
)

colnames(dfbetas_matrix) <- names(coef(linear_model))

dfbetas_threshold <- 2 / sqrt(nrow(heart))

dfbetas_data <- as_tibble(
  dfbetas_matrix,
  .name_repair = "minimal"
) |>
  mutate(row_id = heart$row_id) |>
  pivot_longer(
    cols = -row_id,
    names_to = "term",
    values_to = "dfbetas"
  ) |>
  mutate(
    predictor = recode(term, !!!term_labels),
    influence_flag = abs(dfbetas) > dfbetas_threshold
  )

write_csv(
  dfbetas_data,
  file.path("outputs", "tables", "diagnostic-dfbetas.csv")
)

influence_summary <- dfbetas_data |>
  group_by(row_id) |>
  summarise(
    maximum_absolute_dfbetas = max(abs(dfbetas)),
    flagged_coefficients = sum(influence_flag),
    .groups = "drop"
  ) |>
  left_join(
    heart |>
      select(
        row_id,
        followup_days,
        death,
        age,
        ejection_fraction,
        serum_creatinine,
        serum_sodium,
        sex
      ),
    by = "row_id"
  ) |>
  arrange(desc(maximum_absolute_dfbetas))

write_csv(
  influence_summary,
  file.path("outputs", "tables", "diagnostic-influence-summary.csv")
)

dfbetas_plot <- ggplot(
  dfbetas_data,
  aes(x = row_id, y = dfbetas)
) +
  geom_hline(
    yintercept = c(-dfbetas_threshold, dfbetas_threshold),
    linetype = "dotted",
    linewidth = 0.5,
    color = "#B0483F"
  ) +
  geom_point(
    aes(color = influence_flag),
    alpha = 0.70,
    size = 1.2
  ) +
  scale_color_manual(
    values = c("FALSE" = "#2457A7", "TRUE" = "#B0483F"),
    labels = c("FALSE" = "No", "TRUE" = "Yes")
  ) +
  facet_wrap(vars(predictor), scales = "free_y", ncol = 2) +
  labs(
    title = "DFBETAS influence screening",
    subtitle = paste0(
      "Dotted lines show the heuristic ±2/√n threshold (±",
      round(dfbetas_threshold, 3),
      ")"
    ),
    x = "Dataset row index",
    y = "DFBETAS",
    color = "Flagged"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "top",
    plot.title.position = "plot"
  )

ggsave(
  file.path("outputs", "figures", "cox-dfbetas.png"),
  dfbetas_plot,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)

message("Cox-model diagnostics complete.")
message(
  "Global proportional-hazards p-value: ",
  format.pval(
    ph_table$p_value[ph_table$predictor == "Global test"],
    digits = 4
  )
)
message(
  "All-spline versus linear likelihood-ratio p-value: ",
  format.pval(
    model_shape_comparison$likelihood_ratio_p_value[2],
    digits = 4
  )
)
message(
  "Patients with |deviance residual| > 3: ",
  sum(deviance_data$large_deviance_flag)
)
message(
  "Patients flagged by at least one DFBETAS coefficient: ",
  sum(influence_summary$flagged_coefficients > 0)
)
message("Tables: outputs/tables/")
message("Figures: outputs/figures/")
