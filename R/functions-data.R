# Reusable data-ingestion functions for manual scripts and the targets pipeline.

heart_failure_dataset_url <- paste0(
  "https://archive.ics.uci.edu/static/public/519/",
  "heart+failure+clinical+records.zip"
)

heart_failure_raw_columns <- c(
  "age",
  "anaemia",
  "creatinine_phosphokinase",
  "diabetes",
  "ejection_fraction",
  "high_blood_pressure",
  "platelets",
  "serum_creatinine",
  "serum_sodium",
  "sex",
  "smoking",
  "time",
  "DEATH_EVENT"
)

heart_failure_analysis_columns <- c(
  "age",
  "anaemia",
  "creatinine_phosphokinase",
  "diabetes",
  "ejection_fraction",
  "high_blood_pressure",
  "platelets",
  "serum_creatinine",
  "serum_sodium",
  "sex",
  "smoking",
  "followup_days",
  "death"
)

download_heart_failure_data <- function(
    dataset_url = heart_failure_dataset_url,
    output_file = file.path(
      "data",
      "raw",
      "heart_failure_clinical_records_dataset.csv"
    )) {
  output_dir <- dirname(output_file)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  temporary_zip <- tempfile(fileext = ".zip")
  temporary_dir <- tempfile(pattern = "heart-failure-")
  dir.create(temporary_dir)

  on.exit(
    {
      unlink(temporary_zip)
      unlink(temporary_dir, recursive = TRUE)
    },
    add = TRUE
  )

  download.file(dataset_url, temporary_zip, mode = "wb", quiet = TRUE)

  archive_contents <- unzip(temporary_zip, list = TRUE)
  csv_member <- archive_contents$Name[
    grepl(
      "heart_failure_clinical_records_dataset\\.csv$",
      archive_contents$Name
    )
  ]

  if (length(csv_member) != 1L) {
    stop("Could not identify exactly one dataset CSV in the UCI archive.")
  }

  unzip(
    temporary_zip,
    files = csv_member,
    exdir = temporary_dir,
    overwrite = TRUE
  )

  copied <- file.copy(
    from = file.path(temporary_dir, csv_member),
    to = output_file,
    overwrite = TRUE
  )

  if (!copied) {
    stop("The dataset was downloaded but could not be copied to data/raw.")
  }

  raw_data <- read.csv(output_file, check.names = FALSE)

  if (nrow(raw_data) != 299L) {
    stop("Expected 299 rows, but downloaded ", nrow(raw_data), ".")
  }

  if (!identical(names(raw_data), heart_failure_raw_columns)) {
    stop("Downloaded columns do not match the expected UCI schema.")
  }

  normalizePath(output_file, winslash = "/", mustWork = TRUE)
}

prepare_heart_failure_data <- function(raw_file) {
  raw_data <- readr::read_csv(raw_file, show_col_types = FALSE)

  if (nrow(raw_data) != 299L) {
    stop("Expected 299 rows, but found ", nrow(raw_data), ".")
  }

  if (!identical(names(raw_data), heart_failure_raw_columns)) {
    stop("Raw columns do not match the expected UCI schema.")
  }

  heart <- raw_data |>
    dplyr::rename(
      followup_days = time,
      death = DEATH_EVENT
    ) |>
    dplyr::mutate(
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

  if (anyNA(heart)) {
    stop("Prepared data contain missing values.")
  }

  if (any(!heart$death %in% c(0, 1))) {
    stop("The event indicator contains values other than 0 and 1.")
  }

  if (any(heart$followup_days <= 0)) {
    stop("Follow-up time must be positive.")
  }

  heart
}

write_clean_heart_failure_data <- function(
    heart,
    output_file = file.path(
      "data",
      "processed",
      "heart_failure_clean.csv"
    )) {
  clean_data <- dplyr::select(
    heart,
    dplyr::all_of(heart_failure_analysis_columns)
  )

  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(clean_data, output_file)

  normalizePath(output_file, winslash = "/", mustWork = TRUE)
}
