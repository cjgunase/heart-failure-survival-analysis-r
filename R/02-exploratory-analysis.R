# Exploratory analysis for the UCI Heart Failure Clinical Records dataset.
#
# This manual entry point calls the same reusable functions as the targets
# pipeline. It checks data quality, creates summaries, and saves figures.

required_packages <- c("dplyr", "ggplot2", "readr")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "Install missing packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

source(file.path("R", "functions-data.R"))
source(file.path("R", "functions-eda.R"))

raw_file <- file.path(
  "data",
  "raw",
  "heart_failure_clinical_records_dataset.csv"
)

if (!file.exists(raw_file)) {
  stop("Raw data not found. Run R/01-download-data.R first.")
}

heart <- prepare_heart_failure_data(raw_file)

write_clean_heart_failure_data(
  heart,
  file.path("data", "processed", "heart_failure_clean.csv")
)

write_eda_table(
  summarize_data_quality(heart),
  file.path("outputs", "tables", "data-quality-summary.csv")
)

write_eda_table(
  summarize_continuous_variables(heart),
  file.path("outputs", "tables", "continuous-summary.csv")
)

write_eda_table(
  summarize_binary_variables(heart),
  file.path("outputs", "tables", "binary-summary.csv")
)

save_eda_plot(
  plot_followup_distribution(heart),
  file.path("outputs", "figures", "followup-distribution.png"),
  width = 8,
  height = 6
)

save_eda_plot(
  plot_clinical_marker_distributions(heart),
  file.path("outputs", "figures", "clinical-marker-distributions.png"),
  width = 8,
  height = 8
)

message("Exploratory analysis complete.")
message("Clean data: data/processed/heart_failure_clean.csv")
message("Tables: outputs/tables/")
message("Figures: outputs/figures/")
