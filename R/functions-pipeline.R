# Helpers for integrating the established analysis scripts into targets.

run_analysis_stage <- function(script_file, upstream, output_files) {
  force(upstream)

  if (!file.exists(script_file)) {
    stop("Analysis script does not exist: ", script_file)
  }

  stage_environment <- new.env(parent = globalenv())
  sys.source(script_file, envir = stage_environment)

  missing_outputs <- output_files[!file.exists(output_files)]
  if (length(missing_outputs) > 0L) {
    stop(
      "Analysis stage did not create its declared output(s): ",
      paste(missing_outputs, collapse = ", ")
    )
  }

  normalizePath(output_files, winslash = "/", mustWork = TRUE)
}

render_tutorial_report <- function(report_source, upstream, output_files) {
  force(upstream)

  if (!file.exists(report_source)) {
    stop("Report source does not exist: ", report_source)
  }

  rmarkdown::render(
    report_source,
    output_format = "all",
    quiet = TRUE
  )

  missing_outputs <- output_files[!file.exists(output_files)]
  if (length(missing_outputs) > 0L) {
    stop(
      "Report render did not create its declared output(s): ",
      paste(missing_outputs, collapse = ", ")
    )
  }

  normalizePath(output_files, winslash = "/", mustWork = TRUE)
}
