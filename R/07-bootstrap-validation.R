# Stage 6: Bootstrap internal validation of the refined Cox model.
#
# The model was selected before validation using the Stage 5 diagnostics:
#   linear age
#   3-df natural spline for ejection fraction
#   log2 serum creatinine
#   linear serum sodium
#   sex
#
# Validation estimates:
#   1. optimism-corrected concordance,
#   2. bootstrap stability of interpretable hazard-ratio contrasts, and
#   3. out-of-bag calibration at 90 days.
#
# Set SURVIVAL_BOOTSTRAPS to change the number of resamples. The default is 500.

required_packages <- c(
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

library(dplyr)
library(ggplot2)
library(readr)
library(splines)
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

number_bootstraps <- suppressWarnings(
  as.integer(Sys.getenv("SURVIVAL_BOOTSTRAPS", "500"))
)

if (
  length(number_bootstraps) != 1L ||
    is.na(number_bootstraps) ||
    number_bootstraps < 50L
) {
  stop("SURVIVAL_BOOTSTRAPS must be one integer of at least 50.")
}

validation_time <- 90
random_seed <- 20260728

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

refined_formula <- Surv(followup_days, death) ~
  age_per_10_years +
  ns(ef_per_5_points, df = 3) +
  creatinine_per_doubling +
  sodium_per_5_units +
  sex_group

fit_refined_model <- function(data) {
  coxph(
    refined_formula,
    data = data,
    ties = "efron",
    x = TRUE,
    y = TRUE,
    model = TRUE
  )
}

model_concordance <- function(data, linear_predictor) {
  unname(
    concordance(
      Surv(followup_days, death) ~ linear_predictor,
      data = data,
      reverse = TRUE
    )$concordance
  )
}

predict_survival <- function(model, newdata, time_days) {
  baseline_hazard <- basehaz(model, centered = FALSE)
  available <- baseline_hazard$time <= time_days

  cumulative_hazard <- if (any(available)) {
    max(baseline_hazard$hazard[available])
  } else {
    0
  }

  linear_predictor <- predict(
    model,
    newdata = newdata,
    type = "lp",
    reference = "zero"
  )

  exp(-cumulative_hazard * exp(linear_predictor))
}

contrast_hazard_ratio <- function(model, comparison, reference) {
  comparison_lp <- predict(
    model,
    newdata = comparison,
    type = "lp",
    reference = "zero"
  )

  reference_lp <- predict(
    model,
    newdata = reference,
    type = "lp",
    reference = "zero"
  )

  exp(unname(comparison_lp - reference_lp))
}

refined_model <- fit_refined_model(heart)

apparent_linear_predictor <- predict(
  refined_model,
  newdata = heart,
  type = "lp",
  reference = "zero"
)

apparent_concordance <- model_concordance(
  heart,
  apparent_linear_predictor
)

apparent_survival_90 <- predict_survival(
  refined_model,
  heart,
  validation_time
)

# Reference profile for interpretable bootstrap contrasts. Other predictors are
# fixed at sample medians and female sex. They cancel from pairwise contrasts.
reference_profile <- tibble(
  age_per_10_years = median(heart$age_per_10_years),
  ef_per_5_points = 40 / 5,
  creatinine_per_doubling = median(heart$creatinine_per_doubling),
  sodium_per_5_units = median(heart$sodium_per_5_units),
  sex_group = factor("Female", levels = levels(heart$sex_group))
)

ef_profile <- function(ejection_fraction) {
  reference_profile |>
    mutate(ef_per_5_points = ejection_fraction / 5)
}

full_sample_contrasts <- tibble(
  contrast = c(
    "Age, per 10-year increase",
    "EF 20% versus EF 40%",
    "EF 30% versus EF 40%",
    "EF 50% versus EF 40%",
    "EF 60% versus EF 40%",
    "Serum creatinine, per doubling",
    "Serum sodium, per 5-mEq/L increase",
    "Male versus female"
  ),
  full_sample_hazard_ratio = c(
    exp(coef(refined_model)["age_per_10_years"]),
    contrast_hazard_ratio(
      refined_model,
      ef_profile(20),
      reference_profile
    ),
    contrast_hazard_ratio(
      refined_model,
      ef_profile(30),
      reference_profile
    ),
    contrast_hazard_ratio(
      refined_model,
      ef_profile(50),
      reference_profile
    ),
    contrast_hazard_ratio(
      refined_model,
      ef_profile(60),
      reference_profile
    ),
    exp(coef(refined_model)["creatinine_per_doubling"]),
    exp(coef(refined_model)["sodium_per_5_units"]),
    exp(coef(refined_model)["sex_groupMale"])
  )
)

# Bootstrap validation --------------------------------------------------------

set.seed(random_seed)

n <- nrow(heart)
bootstrap_results <- vector("list", number_bootstraps)
oob_survival_predictions <- matrix(
  NA_real_,
  nrow = n,
  ncol = number_bootstraps
)

for (bootstrap_index in seq_len(number_bootstraps)) {
  sampled_rows <- sample.int(n, size = n, replace = TRUE)
  bootstrap_data <- heart[sampled_rows, , drop = FALSE]
  out_of_bag_rows <- setdiff(seq_len(n), unique(sampled_rows))

  bootstrap_fit <- tryCatch(
    suppressWarnings(fit_refined_model(bootstrap_data)),
    error = function(error) NULL
  )

  if (is.null(bootstrap_fit)) {
    bootstrap_results[[bootstrap_index]] <- tibble(
      bootstrap = bootstrap_index,
      fit_succeeded = FALSE
    )
    next
  }

  bootstrap_training_lp <- predict(
    bootstrap_fit,
    newdata = bootstrap_data,
    type = "lp",
    reference = "zero"
  )

  original_test_lp <- predict(
    bootstrap_fit,
    newdata = heart,
    type = "lp",
    reference = "zero"
  )

  training_concordance <- model_concordance(
    bootstrap_data,
    bootstrap_training_lp
  )

  test_concordance <- model_concordance(
    heart,
    original_test_lp
  )

  if (length(out_of_bag_rows) > 0L) {
    oob_survival_predictions[
      out_of_bag_rows,
      bootstrap_index
    ] <- predict_survival(
      bootstrap_fit,
      heart[out_of_bag_rows, , drop = FALSE],
      validation_time
    )
  }

  bootstrap_results[[bootstrap_index]] <- tibble(
    bootstrap = bootstrap_index,
    fit_succeeded = TRUE,
    training_concordance = training_concordance,
    test_concordance = test_concordance,
    optimism = training_concordance - test_concordance,
    `Age, per 10-year increase` =
      exp(coef(bootstrap_fit)["age_per_10_years"]),
    `EF 20% versus EF 40%` = contrast_hazard_ratio(
      bootstrap_fit,
      ef_profile(20),
      reference_profile
    ),
    `EF 30% versus EF 40%` = contrast_hazard_ratio(
      bootstrap_fit,
      ef_profile(30),
      reference_profile
    ),
    `EF 50% versus EF 40%` = contrast_hazard_ratio(
      bootstrap_fit,
      ef_profile(50),
      reference_profile
    ),
    `EF 60% versus EF 40%` = contrast_hazard_ratio(
      bootstrap_fit,
      ef_profile(60),
      reference_profile
    ),
    `Serum creatinine, per doubling` =
      exp(coef(bootstrap_fit)["creatinine_per_doubling"]),
    `Serum sodium, per 5-mEq/L increase` =
      exp(coef(bootstrap_fit)["sodium_per_5_units"]),
    `Male versus female` =
      exp(coef(bootstrap_fit)["sex_groupMale"])
  )
}

bootstrap_results <- bind_rows(bootstrap_results)
successful_results <- bootstrap_results |>
  filter(fit_succeeded)

if (nrow(successful_results) < 0.90 * number_bootstraps) {
  stop("Fewer than 90% of bootstrap model fits succeeded.")
}

write_csv(
  bootstrap_results,
  file.path("outputs", "tables", "bootstrap-resample-results.csv")
)

mean_optimism <- mean(successful_results$optimism)
optimism_corrected_concordance <- apparent_concordance - mean_optimism

concordance_summary <- tibble(
  statistic = c(
    "Requested bootstrap resamples",
    "Successful bootstrap fits",
    "Random seed",
    "Apparent concordance",
    "Mean bootstrap training concordance",
    "Mean bootstrap test concordance",
    "Mean estimated optimism",
    "Optimism-corrected concordance",
    "Bootstrap test concordance 2.5th percentile",
    "Bootstrap test concordance 97.5th percentile"
  ),
  value = c(
    number_bootstraps,
    nrow(successful_results),
    random_seed,
    apparent_concordance,
    mean(successful_results$training_concordance),
    mean(successful_results$test_concordance),
    mean_optimism,
    optimism_corrected_concordance,
    quantile(
      successful_results$test_concordance,
      0.025,
      names = FALSE
    ),
    quantile(
      successful_results$test_concordance,
      0.975,
      names = FALSE
    )
  )
)

write_csv(
  concordance_summary,
  file.path("outputs", "tables", "bootstrap-concordance-summary.csv")
)

# Bootstrap stability of hazard-ratio contrasts ------------------------------

contrast_names <- full_sample_contrasts$contrast

contrast_stability <- bind_rows(lapply(
  contrast_names,
  function(contrast_name) {
    values <- successful_results[[contrast_name]]

    tibble(
      contrast = contrast_name,
      full_sample_hazard_ratio =
        full_sample_contrasts$full_sample_hazard_ratio[
          full_sample_contrasts$contrast == contrast_name
        ],
      bootstrap_median = median(values, na.rm = TRUE),
      bootstrap_2.5_percentile = quantile(
        values,
        0.025,
        na.rm = TRUE,
        names = FALSE
      ),
      bootstrap_97.5_percentile = quantile(
        values,
        0.975,
        na.rm = TRUE,
        names = FALSE
      ),
      proportion_above_1 = mean(values > 1, na.rm = TRUE)
    )
  }
))

write_csv(
  contrast_stability,
  file.path("outputs", "tables", "bootstrap-contrast-stability.csv")
)

# Out-of-bag 90-day calibration ----------------------------------------------

oob_prediction_counts <- rowSums(!is.na(oob_survival_predictions))
oob_survival_90 <- rowMeans(
  oob_survival_predictions,
  na.rm = TRUE
)

if (any(oob_prediction_counts == 0L) || any(!is.finite(oob_survival_90))) {
  stop("At least one patient received no valid out-of-bag prediction.")
}

calibration_summary <- function(data, predictions, method_label) {
  calibration_data <- data |>
    mutate(
      predicted_survival = predictions,
      calibration_group = factor(
        ntile(predicted_survival, 5),
        levels = 1:5
      )
    )

  predicted_by_group <- calibration_data |>
    group_by(calibration_group) |>
    summarise(
      patients = n(),
      mean_predicted_survival = mean(predicted_survival),
      .groups = "drop"
    )

  calibration_fit <- survfit(
    Surv(followup_days, death) ~ calibration_group,
    data = calibration_data,
    conf.type = "log"
  )

  observed <- summary(
    calibration_fit,
    times = validation_time,
    extend = TRUE,
    data.frame = TRUE
  )

  observed_by_group <- tibble(
    calibration_group = factor(
      sub("^[^=]+=", "", observed$strata),
      levels = 1:5
    ),
    observed_survival = observed$surv,
    observed_lower_95 = observed$lower,
    observed_upper_95 = observed$upper,
    n_risk_at_90_days = observed$n.risk
  )

  predicted_by_group |>
    left_join(observed_by_group, by = "calibration_group") |>
    mutate(
      method = method_label,
      validation_time_days = validation_time,
      .before = 1
    )
}

apparent_calibration <- calibration_summary(
  heart,
  apparent_survival_90,
  "Apparent"
)

oob_calibration <- calibration_summary(
  heart,
  oob_survival_90,
  "Out-of-bag bootstrap"
)

calibration_results <- bind_rows(
  apparent_calibration,
  oob_calibration
)

write_csv(
  calibration_results,
  file.path("outputs", "tables", "bootstrap-calibration-90-days.csv")
)

write_csv(
  tibble(
    row_id = heart$row_id,
    apparent_predicted_survival_90 = apparent_survival_90,
    oob_predicted_survival_90 = oob_survival_90,
    oob_prediction_count = oob_prediction_counts
  ),
  file.path("outputs", "tables", "bootstrap-oob-predictions.csv")
)

# Validation figures ---------------------------------------------------------

concordance_plot <- ggplot(
  successful_results,
  aes(x = test_concordance)
) +
  geom_histogram(
    bins = 30,
    fill = "#A9BEE2",
    color = "white"
  ) +
  geom_vline(
    xintercept = apparent_concordance,
    linewidth = 0.8,
    color = "#B0483F"
  ) +
  geom_vline(
    xintercept = optimism_corrected_concordance,
    linewidth = 0.8,
    linetype = "dashed",
    color = "#2457A7"
  ) +
  labs(
    title = "Bootstrap validation of model concordance",
    subtitle = paste0(
      "Red: apparent C = ",
      round(apparent_concordance, 3),
      "; blue dashed: optimism-corrected C = ",
      round(optimism_corrected_concordance, 3)
    ),
    x = "Concordance when bootstrap model is evaluated on original data",
    y = "Number of bootstrap resamples"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

ggsave(
  file.path("outputs", "figures", "bootstrap-concordance.png"),
  concordance_plot,
  width = 9,
  height = 6,
  dpi = 300,
  bg = "white"
)

calibration_plot <- ggplot(
  calibration_results,
  aes(
    x = mean_predicted_survival,
    y = observed_survival
  )
) +
  geom_abline(
    intercept = 0,
    slope = 1,
    linetype = "dashed",
    linewidth = 0.6,
    color = "#666666"
  ) +
  geom_errorbar(
    aes(
      ymin = observed_lower_95,
      ymax = observed_upper_95
    ),
    width = 0.01,
    linewidth = 0.6,
    color = "#2457A7"
  ) +
  geom_point(
    size = 3,
    color = "#2457A7"
  ) +
  geom_text(
    aes(label = calibration_group),
    nudge_y = 0.025,
    size = 3.3
  ) +
  facet_wrap(vars(method)) +
  coord_equal(
    xlim = c(0.45, 1),
    ylim = c(0.45, 1)
  ) +
  scale_x_continuous(labels = scales::label_percent(accuracy = 1)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  labs(
    title = "Calibration of predicted 90-day survival",
    subtitle = "Points are prediction quintiles; vertical lines are KM 95% CIs",
    x = "Mean predicted survival",
    y = "Kaplan–Meier observed survival"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot"
  )

ggsave(
  file.path("outputs", "figures", "bootstrap-calibration-90-days.png"),
  calibration_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

message("Bootstrap internal validation complete.")
message(
  "Successful fits: ",
  nrow(successful_results),
  "/",
  number_bootstraps
)
message(
  "Apparent concordance: ",
  round(apparent_concordance, 3)
)
message(
  "Mean optimism: ",
  round(mean_optimism, 3)
)
message(
  "Optimism-corrected concordance: ",
  round(optimism_corrected_concordance, 3)
)
message(
  "Out-of-bag predictions per patient: ",
  min(oob_prediction_counts),
  " to ",
  max(oob_prediction_counts)
)
message("Tables: outputs/tables/")
message("Figures: outputs/figures/")
