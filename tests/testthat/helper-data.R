project_root <- Sys.getenv("SURVIVAL_PROJECT_ROOT")

if (!nzchar(project_root) || !dir.exists(project_root)) {
  stop("SURVIVAL_PROJECT_ROOT does not identify the repository root.")
}

project_file <- function(...) {
  file.path(project_root, ...)
}

clean_data_file <- project_file(
  "data",
  "processed",
  "heart_failure_clean.csv"
)

if (!file.exists(clean_data_file)) {
  stop(
    "Clean analysis data is missing. Run ",
    "Rscript R/01-download-data.R and Rscript R/02-exploratory-analysis.R."
  )
}

heart_test_data <- read.csv(clean_data_file, check.names = FALSE)
