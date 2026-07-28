source(project_file("R", "functions-eda.R"))

eda_test_data <- add_eda_labels(heart_test_data)

testthat::test_that("EDA labels have documented levels", {
  testthat::expect_identical(
    levels(eda_test_data$death_label),
    c("Censored", "Death observed")
  )
  testthat::expect_identical(
    levels(eda_test_data$sex_label),
    c("Female", "Male")
  )
})

testthat::test_that("data-quality summary agrees with analysis data", {
  summary <- summarize_data_quality(heart_test_data)
  values <- stats::setNames(summary$value, summary$metric)

  testthat::expect_equal(unname(values["Rows"]), 299)
  testthat::expect_equal(unname(values["Analysis columns"]), 13)
  testthat::expect_equal(unname(values["Missing cells"]), 0)
  testthat::expect_equal(unname(values["Observed deaths"]), 96)
  testthat::expect_equal(unname(values["Censored observations"]), 203)
})

testthat::test_that("continuous summaries cover the documented variables", {
  summary <- summarize_continuous_variables(heart_test_data)

  testthat::expect_equal(nrow(summary), 7L)
  testthat::expect_true(all(summary$n == 299))
  testthat::expect_true(all(summary$missing == 0))
  testthat::expect_true(all(summary$minimum <= summary$median))
  testthat::expect_true(all(summary$median <= summary$maximum))
})

testthat::test_that("binary summaries contain valid proportions", {
  summary <- summarize_binary_variables(heart_test_data)
  proportion_sums <- aggregate(
    proportion ~ variable,
    data = summary,
    FUN = sum
  )

  testthat::expect_setequal(
    unique(summary$variable),
    c(
      "anaemia",
      "diabetes",
      "high_blood_pressure",
      "sex",
      "smoking",
      "death"
    )
  )
  testthat::expect_equal(
    proportion_sums$proportion,
    rep(1, nrow(proportion_sums))
  )
  testthat::expect_true(all(summary$proportion >= 0))
  testthat::expect_true(all(summary$proportion <= 1))
})

testthat::test_that("EDA plotting functions return ggplot objects", {
  testthat::skip_if_not_installed("ggplot2")

  testthat::expect_s3_class(
    plot_followup_distribution(eda_test_data),
    "ggplot"
  )
  testthat::expect_s3_class(
    plot_clinical_marker_distributions(eda_test_data),
    "ggplot"
  )
})
