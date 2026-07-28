source(project_file("R", "functions-pipeline.R"))

testthat::test_that("stage runner returns every declared output", {
  script_file <- tempfile(fileext = ".R")
  output_file <- tempfile(fileext = ".txt")
  on.exit(unlink(c(script_file, output_file)), add = TRUE)

  writeLines(
    sprintf("writeLines('built', %s)", deparse(output_file)),
    script_file
  )

  returned_file <- run_analysis_stage(
    script_file,
    upstream = "ready",
    output_files = output_file
  )

  testthat::expect_true(file.exists(returned_file))
  testthat::expect_equal(readLines(returned_file), "built")
})

testthat::test_that("stage runner rejects a missing script", {
  testthat::expect_error(
    run_analysis_stage(
      tempfile(fileext = ".R"),
      upstream = "ready",
      output_files = tempfile()
    ),
    "Analysis script does not exist"
  )
})

testthat::test_that("stage runner rejects undeclared missing outputs", {
  script_file <- tempfile(fileext = ".R")
  on.exit(unlink(script_file), add = TRUE)
  writeLines("invisible(TRUE)", script_file)

  testthat::expect_error(
    run_analysis_stage(
      script_file,
      upstream = "ready",
      output_files = tempfile()
    ),
    "did not create its declared output"
  )
})
