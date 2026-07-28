library(targets)

source(file.path("R", "functions-data.R"))

tar_option_set(
  packages = c("dplyr", "readr")
)

list(
  tar_target(
    dataset_url,
    heart_failure_dataset_url
  ),
  tar_target(
    raw_data_file,
    download_heart_failure_data(dataset_url),
    format = "file"
  ),
  tar_target(
    clean_data_file,
    write_clean_heart_failure_data(
      prepare_heart_failure_data(raw_data_file)
    ),
    format = "file"
  ),
  tar_target(
    clean_data,
    readr::read_csv(clean_data_file, show_col_types = FALSE)
  )
)
