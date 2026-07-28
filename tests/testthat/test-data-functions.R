source(project_file("R", "functions-data.R"))

testthat::test_that("preparation preserves rows and creates survival outcome", {
  raw_file <- project_file(
    "data",
    "raw",
    "heart_failure_clinical_records_dataset.csv"
  )

  prepared <- prepare_heart_failure_data(raw_file)

  testthat::expect_equal(nrow(prepared), 299L)
  testthat::expect_true(
    all(heart_failure_analysis_columns %in% names(prepared))
  )
  testthat::expect_equal(prepared$followup_days, heart_test_data$followup_days)
  testthat::expect_equal(prepared$death, heart_test_data$death)
})

testthat::test_that("clean writer creates the documented analysis schema", {
  raw_file <- project_file(
    "data",
    "raw",
    "heart_failure_clinical_records_dataset.csv"
  )
  temporary_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temporary_file), add = TRUE)

  returned_file <- write_clean_heart_failure_data(
    prepare_heart_failure_data(raw_file),
    temporary_file
  )
  written_data <- read.csv(returned_file, check.names = FALSE)

  testthat::expect_true(file.exists(returned_file))
  testthat::expect_identical(
    names(written_data),
    heart_failure_analysis_columns
  )
  testthat::expect_equal(written_data, heart_test_data)
})

testthat::test_that("preparation rejects an unexpected source schema", {
  malformed_file <- tempfile(fileext = ".csv")
  on.exit(unlink(malformed_file), add = TRUE)
  malformed_data <- read.csv(
    project_file(
      "data",
      "raw",
      "heart_failure_clinical_records_dataset.csv"
    ),
    check.names = FALSE
  )
  names(malformed_data)[1] <- "unexpected_age_name"
  utils::write.csv(malformed_data, malformed_file, row.names = FALSE)

  testthat::expect_error(
    prepare_heart_failure_data(malformed_file),
    "Raw columns do not match"
  )
})
