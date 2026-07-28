testthat::test_that("clean data has the documented schema", {
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
    "followup_days",
    "death"
  )

  testthat::expect_identical(names(heart_test_data), expected_columns)
  testthat::expect_equal(nrow(heart_test_data), 299L)
  testthat::expect_equal(ncol(heart_test_data), length(expected_columns))
})

testthat::test_that("survival outcome is valid", {
  testthat::expect_false(anyNA(heart_test_data$followup_days))
  testthat::expect_false(anyNA(heart_test_data$death))
  testthat::expect_true(all(heart_test_data$followup_days > 0))
  testthat::expect_setequal(unique(heart_test_data$death), c(0, 1))
  testthat::expect_equal(sum(heart_test_data$death), 96)
})

testthat::test_that("binary predictors contain only zero and one", {
  binary_predictors <- c(
    "anaemia",
    "diabetes",
    "high_blood_pressure",
    "sex",
    "smoking"
  )

  for (predictor in binary_predictors) {
    testthat::expect_false(anyNA(heart_test_data[[predictor]]))
    testthat::expect_setequal(
      unique(heart_test_data[[predictor]]),
      c(0, 1)
    )
  }
})

testthat::test_that("continuous model inputs are finite and plausible", {
  continuous_predictors <- c(
    "age",
    "ejection_fraction",
    "serum_creatinine",
    "serum_sodium"
  )

  for (predictor in continuous_predictors) {
    testthat::expect_false(anyNA(heart_test_data[[predictor]]))
    testthat::expect_true(
      all(is.finite(heart_test_data[[predictor]])),
      info = predictor
    )
  }

  testthat::expect_true(all(heart_test_data$age > 0))
  testthat::expect_true(
    all(heart_test_data$ejection_fraction > 0 &
      heart_test_data$ejection_fraction <= 100)
  )
  testthat::expect_true(all(heart_test_data$serum_creatinine > 0))
})

testthat::test_that("clean outcome columns preserve the raw source values", {
  raw_file <- project_file(
    "data",
    "raw",
    "heart_failure_clinical_records_dataset.csv"
  )
  testthat::expect_true(file.exists(raw_file))

  raw_data <- read.csv(raw_file, check.names = FALSE)

  testthat::expect_equal(heart_test_data$followup_days, raw_data$time)
  testthat::expect_equal(heart_test_data$death, raw_data$DEATH_EVENT)
})
