testthat::test_that("manual Kaplan-Meier calculation agrees with survival", {
  testthat::skip_if_not_installed("survival")

  time_summary <- aggregate(
    death ~ followup_days,
    data = heart_test_data,
    FUN = function(event) {
      c(events = sum(event == 1), censored = sum(event == 0))
    }
  )

  event_counts <- time_summary$death[, "events"]
  risk_counts <- vapply(
    time_summary$followup_days,
    function(time) sum(heart_test_data$followup_days >= time),
    integer(1)
  )
  manual_survival <- cumprod(1 - event_counts / risk_counts)

  package_fit <- survival::survfit(
    survival::Surv(followup_days, death) ~ 1,
    data = heart_test_data
  )

  testthat::expect_equal(
    manual_survival,
    unname(package_fit$surv),
    tolerance = 1e-12
  )
  testthat::expect_true(all(diff(manual_survival) <= 0))
  testthat::expect_true(all(manual_survival >= 0 & manual_survival <= 1))
})

testthat::test_that("prespecified Cox model fits and returns valid estimates", {
  testthat::skip_if_not_installed("survival")

  model_data <- transform(
    heart_test_data,
    age_per_10_years = age / 10,
    ef_per_5_points = ejection_fraction / 5,
    creatinine_per_doubling = log2(serum_creatinine),
    sodium_per_5_units = serum_sodium / 5,
    sex_group = factor(
      sex,
      levels = c(0, 1),
      labels = c("Female", "Male")
    )
  )

  fit <- survival::coxph(
    survival::Surv(followup_days, death) ~
      age_per_10_years +
      ef_per_5_points +
      creatinine_per_doubling +
      sodium_per_5_units +
      sex_group,
    data = model_data,
    ties = "efron"
  )

  confidence_intervals <- exp(stats::confint(fit))
  hazard_ratios <- exp(stats::coef(fit))

  testthat::expect_equal(fit$nevent, sum(model_data$death))
  testthat::expect_length(stats::coef(fit), 5L)
  testthat::expect_true(all(is.finite(hazard_ratios)))
  testthat::expect_true(all(hazard_ratios > 0))
  testthat::expect_true(all(confidence_intervals[, 1] > 0))
  testthat::expect_true(
    all(confidence_intervals[, 1] < confidence_intervals[, 2])
  )
})

testthat::test_that("saved Cox results have a valid reporting structure", {
  results_file <- project_file(
    "outputs",
    "tables",
    "cox-adjusted-results.csv"
  )
  testthat::expect_true(file.exists(results_file))

  results <- read.csv(results_file, check.names = FALSE)
  expected_columns <- c(
    "predictor",
    "hazard_ratio",
    "lower_95",
    "upper_95",
    "p_value"
  )

  testthat::expect_identical(names(results), expected_columns)
  testthat::expect_equal(nrow(results), 5L)
  testthat::expect_true(all(results$hazard_ratio > 0))
  testthat::expect_true(all(results$lower_95 < results$upper_95))
  testthat::expect_true(all(results$p_value >= 0 & results$p_value <= 1))
})
