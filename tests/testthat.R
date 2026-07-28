if (!requireNamespace("testthat", quietly = TRUE)) {
  stop(
    "The testthat package is required. Install it with ",
    "install.packages(\"testthat\")."
  )
}

Sys.setenv(
  SURVIVAL_PROJECT_ROOT = normalizePath(
    ".",
    winslash = "/",
    mustWork = TRUE
  )
)

testthat::test_dir(
  file.path("tests", "testthat"),
  reporter = "summary",
  stop_on_failure = TRUE
)
