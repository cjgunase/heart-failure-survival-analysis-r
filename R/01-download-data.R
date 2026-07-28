# Download the Heart Failure Clinical Records dataset from the official
# UCI Machine Learning Repository.
#
# Source: https://archive.ics.uci.edu/dataset/519/heart
# License: CC BY 4.0

source(file.path("R", "functions-data.R"))

message("Downloading data from UCI...")

output_file <- download_heart_failure_data()
heart_failure <- read.csv(output_file, check.names = FALSE)

message("Saved: ", output_file)
message(
  "Rows: ",
  nrow(heart_failure),
  "; columns: ",
  ncol(heart_failure)
)
message("MD5: ", unname(tools::md5sum(output_file)))
