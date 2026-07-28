# Exploratory analysis for the UCI Heart Failure Clinical Records dataset.
#
# This script checks data quality, creates descriptive summaries, and saves
# exploratory figures. It does not fit survival models yet.

required_packages <- c("dplyr", "ggplot2", "readr", "broom")
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

raw_file <- file.path(
  "data",
  "raw",
  "heart_failure_clinical_records_dataset.csv"
)

if (!file.exists(raw_file)) {
  stop("Raw data not found. Run R/01-download-data.R first.")
}

dir.create(file.path("data", "processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("outputs", "figures"), recursive = TRUE, showWarnings = FALSE)

heart <- read_csv(raw_file, show_col_types = FALSE) |>
  rename(
    followup_days = time,
    death = DEATH_EVENT
  ) |>
  mutate(
    death_label = factor(
      death,
      levels = c(0, 1),
      labels = c("Censored", "Death observed")
    ),
    sex_label = factor(
      sex,
      levels = c(0, 1),
      labels = c("Female", "Male")
    ),
    anaemia_label = factor(
      anaemia,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    diabetes_label = factor(
      diabetes,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    high_bp_label = factor(
      high_blood_pressure,
      levels = c(0, 1),
      labels = c("No", "Yes")
    ),
    smoking_label = factor(
      smoking,
      levels = c(0, 1),
      labels = c("No", "Yes")
    )
  )

if (any(!heart$death %in% c(0, 1))) {
  stop("The event indicator contains values other than 0 and 1.")
}

if (any(heart$followup_days <= 0, na.rm = TRUE)) {
  stop("Follow-up time must be positive.")
}

write_csv(
  heart |>
    select(
      age,
      anaemia,
      creatinine_phosphokinase,
      diabetes,
      ejection_fraction,
      high_blood_pressure,
      platelets,
      serum_creatinine,
      serum_sodium,
      sex,
      smoking,
      followup_days,
      death
    ),
  file.path("data", "processed", "heart_failure_clean.csv")
)

data_quality <- tibble(
  metric = c(
    "Rows",
    "Analysis columns",
    "Duplicate rows",
    "Missing cells",
    "Observed deaths",
    "Censored observations",
    "Death proportion",
    "Minimum follow-up days",
    "Median follow-up days",
    "Maximum follow-up days"
  ),
  value = c(
    nrow(heart),
    13,
    sum(duplicated(heart)),
    sum(is.na(heart)),
    sum(heart$death == 1),
    sum(heart$death == 0),
    mean(heart$death),
    min(heart$followup_days),
    median(heart$followup_days),
    max(heart$followup_days)
  )
)

write_csv(
  data_quality,
  file.path("outputs", "tables", "data-quality-summary.csv")
)

continuous_variables <- c(
  "age",
  "creatinine_phosphokinase",
  "ejection_fraction",
  "platelets",
  "serum_creatinine",
  "serum_sodium",
  "followup_days"
)

continuous_summary <- bind_rows(lapply(continuous_variables, function(variable) {
  values <- heart[[variable]]
  tibble(
    variable = variable,
    n = sum(!is.na(values)),
    missing = sum(is.na(values)),
    mean = mean(values, na.rm = TRUE),
    standard_deviation = sd(values, na.rm = TRUE),
    minimum = min(values, na.rm = TRUE),
    q1 = quantile(values, 0.25, na.rm = TRUE, names = FALSE),
    median = median(values, na.rm = TRUE),
    q3 = quantile(values, 0.75, na.rm = TRUE, names = FALSE),
    maximum = max(values, na.rm = TRUE)
  )
}))

write_csv(
  continuous_summary,
  file.path("outputs", "tables", "continuous-summary.csv")
)

binary_variables <- c(
  "anaemia",
  "diabetes",
  "high_blood_pressure",
  "sex",
  "smoking",
  "death"
)

binary_summary <- bind_rows(lapply(binary_variables, function(variable) {
  heart |>
    count(level = .data[[variable]], name = "n") |>
    mutate(
      variable = variable,
      proportion = n / sum(n)
    ) |>
    select(variable, level, n, proportion)
}))

write_csv(
  binary_summary,
  file.path("outputs", "tables", "binary-summary.csv")
)

followup_plot <- ggplot(
  heart,
  aes(x = followup_days, fill = death_label)
) +
  geom_histogram(
    bins = 25,
    position = "identity",
    alpha = 0.60
  ) +
  facet_wrap(vars(death_label), ncol = 1) +
  labs(
    title = "Observed follow-up time",
    subtitle = "Censored observations are not the same as survivors",
    x = "Observed follow-up time (days)",
    y = "Number of patients",
    fill = "Follow-up outcome"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

ggsave(
  file.path("outputs", "figures", "followup-distribution.png"),
  followup_plot,
  width = 8,
  height = 6,
  dpi = 300
)

key_markers <- heart |>
  select(
    ejection_fraction,
    serum_creatinine,
    serum_sodium
  ) |>
  stack() |>
  rename(value = values, marker = ind)

marker_plot <- ggplot(key_markers, aes(x = value)) +
  geom_histogram(bins = 25, fill = "#4472C4", color = "white") +
  facet_wrap(
    vars(marker),
    scales = "free",
    ncol = 1,
    labeller = as_labeller(c(
      ejection_fraction = "Ejection fraction (%)",
      serum_creatinine = "Serum creatinine (mg/dL)",
      serum_sodium = "Serum sodium (mEq/L)"
    ))
  ) +
  labs(
    title = "Distributions of key clinical markers",
    x = NULL,
    y = "Number of patients"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  file.path("outputs", "figures", "clinical-marker-distributions.png"),
  marker_plot,
  width = 8,
  height = 8,
  dpi = 300
)

message("Exploratory analysis complete.")
message("Clean data: data/processed/heart_failure_clean.csv")
message("Tables: outputs/tables/")
message("Figures: outputs/figures/")
