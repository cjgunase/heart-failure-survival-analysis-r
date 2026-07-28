# Download the Heart Failure Clinical Records dataset from the official
# UCI Machine Learning Repository.
#
# Source: https://archive.ics.uci.edu/dataset/519/heart
# License: CC BY 4.0

dataset_url <- paste0(
  "https://archive.ics.uci.edu/static/public/519/",
  "heart+failure+clinical+records.zip"
)

raw_dir <- file.path("data", "raw")
output_file <- file.path(
  raw_dir,
  "heart_failure_clinical_records_dataset.csv"
)

dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

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

message("Downloading data from UCI...")
download.file(dataset_url, temporary_zip, mode = "wb", quiet = TRUE)

archive_contents <- unzip(temporary_zip, list = TRUE)
csv_member <- archive_contents$Name[
  grepl("heart_failure_clinical_records_dataset\\.csv$", archive_contents$Name)
]

if (length(csv_member) != 1L) {
  stop("Could not identify exactly one dataset CSV inside the UCI archive.")
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

heart_failure <- read.csv(output_file, check.names = FALSE)

expected_columns <- c(
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

if (nrow(heart_failure) != 299L) {
  stop("Expected 299 rows, but downloaded ", nrow(heart_failure), ".")
}

if (!identical(names(heart_failure), expected_columns)) {
  stop("Downloaded columns do not match the expected UCI schema.")
}

message("Saved: ", output_file)
message("Rows: ", nrow(heart_failure), "; columns: ", ncol(heart_failure))
message("MD5: ", unname(tools::md5sum(output_file)))
