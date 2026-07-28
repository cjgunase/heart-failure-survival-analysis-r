library(targets)

source(file.path("R", "functions-data.R"))
source(file.path("R", "functions-eda.R"))
source(file.path("R", "functions-pipeline.R"))

tar_option_set(
  packages = c("dplyr", "ggplot2", "readr")
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
  ),
  tar_target(
    eda_data,
    add_eda_labels(clean_data)
  ),
  tar_target(
    data_quality_table,
    summarize_data_quality(clean_data)
  ),
  tar_target(
    data_quality_file,
    write_eda_table(
      data_quality_table,
      file.path("outputs", "tables", "data-quality-summary.csv")
    ),
    format = "file"
  ),
  tar_target(
    continuous_summary_table,
    summarize_continuous_variables(clean_data)
  ),
  tar_target(
    continuous_summary_file,
    write_eda_table(
      continuous_summary_table,
      file.path("outputs", "tables", "continuous-summary.csv")
    ),
    format = "file"
  ),
  tar_target(
    binary_summary_table,
    summarize_binary_variables(clean_data)
  ),
  tar_target(
    binary_summary_file,
    write_eda_table(
      binary_summary_table,
      file.path("outputs", "tables", "binary-summary.csv")
    ),
    format = "file"
  ),
  tar_target(
    followup_plot,
    plot_followup_distribution(eda_data)
  ),
  tar_target(
    followup_figure,
    save_eda_plot(
      followup_plot,
      file.path("outputs", "figures", "followup-distribution.png"),
      width = 8,
      height = 6
    ),
    format = "file"
  ),
  tar_target(
    marker_plot,
    plot_clinical_marker_distributions(eda_data)
  ),
  tar_target(
    marker_figure,
    save_eda_plot(
      marker_plot,
      file.path(
        "outputs",
        "figures",
        "clinical-marker-distributions.png"
      ),
      width = 8,
      height = 8
    ),
    format = "file"
  ),
  tar_target(
    km_script,
    file.path("R", "03-kaplan-meier.R"),
    format = "file"
  ),
  tar_target(
    km_outputs,
    run_analysis_stage(
      km_script,
      clean_data_file,
      c(
        file.path("outputs", "tables", "kaplan-meier-event-table.csv"),
        file.path("outputs", "tables", "kaplan-meier-validation.csv"),
        file.path("outputs", "tables", "kaplan-meier-selected-times.csv"),
        file.path("outputs", "tables", "kaplan-meier-summary.csv"),
        file.path("outputs", "tables", "numbers-at-risk.csv"),
        file.path("outputs", "figures", "overall-kaplan-meier.png")
      )
    ),
    format = "file"
  ),
  tar_target(
    group_comparison_script,
    file.path("R", "04-group-comparisons.R"),
    format = "file"
  ),
  tar_target(
    group_comparison_outputs,
    run_analysis_stage(
      group_comparison_script,
      clean_data_file,
      c(
        file.path("outputs", "tables", "log-rank-tests.csv"),
        file.path(
          "outputs",
          "tables",
          "ejection-fraction-group-summary.csv"
        ),
        file.path("outputs", "tables", "sex-group-summary.csv"),
        file.path(
          "outputs",
          "tables",
          "grouped-survival-selected-times.csv"
        ),
        file.path(
          "outputs",
          "figures",
          "kaplan-meier-ejection-fraction.png"
        ),
        file.path("outputs", "figures", "kaplan-meier-sex.png")
      )
    ),
    format = "file"
  ),
  tar_target(
    cox_script,
    file.path("R", "05-cox-regression.R"),
    format = "file"
  ),
  tar_target(
    cox_outputs,
    run_analysis_stage(
      cox_script,
      clean_data_file,
      c(
        file.path("outputs", "tables", "cox-univariable-results.csv"),
        file.path("outputs", "tables", "cox-adjusted-results.csv"),
        file.path("outputs", "tables", "cox-model-summary.csv"),
        file.path(
          "outputs",
          "tables",
          "cox-proportional-hazards-tests.csv"
        ),
        file.path(
          "outputs",
          "figures",
          "cox-adjusted-forest-plot.png"
        )
      )
    ),
    format = "file"
  ),
  tar_target(
    diagnostics_script,
    file.path("R", "06-model-diagnostics.R"),
    format = "file"
  ),
  tar_target(
    diagnostics_outputs,
    run_analysis_stage(
      diagnostics_script,
      cox_outputs,
      c(
        file.path(
          "outputs",
          "tables",
          "diagnostic-proportional-hazards.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "diagnostic-nonlinearity-tests.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "diagnostic-model-shape-comparison.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "diagnostic-ejection-fraction-spline.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "diagnostic-deviance-residuals.csv"
        ),
        file.path("outputs", "tables", "diagnostic-dfbetas.csv"),
        file.path(
          "outputs",
          "tables",
          "diagnostic-influence-summary.csv"
        ),
        file.path(
          "outputs",
          "figures",
          "cox-schoenfeld-residuals.png"
        ),
        file.path(
          "outputs",
          "figures",
          "cox-ejection-fraction-spline.png"
        ),
        file.path("outputs", "figures", "cox-deviance-residuals.png"),
        file.path("outputs", "figures", "cox-dfbetas.png")
      )
    ),
    format = "file"
  ),
  tar_target(
    validation_script,
    file.path("R", "07-bootstrap-validation.R"),
    format = "file"
  ),
  tar_target(
    validation_outputs,
    run_analysis_stage(
      validation_script,
      diagnostics_outputs,
      c(
        file.path(
          "outputs",
          "tables",
          "bootstrap-resample-results.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "bootstrap-concordance-summary.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "bootstrap-contrast-stability.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "bootstrap-calibration-90-days.csv"
        ),
        file.path(
          "outputs",
          "tables",
          "bootstrap-oob-predictions.csv"
        ),
        file.path(
          "outputs",
          "figures",
          "bootstrap-concordance.png"
        ),
        file.path(
          "outputs",
          "figures",
          "bootstrap-calibration-90-days.png"
        )
      )
    ),
    format = "file"
  ),
  tar_target(
    report_source,
    file.path("report", "survival-analysis-tutorial.Rmd"),
    format = "file"
  ),
  tar_target(
    report_outputs,
    render_tutorial_report(
      report_source,
      c(
        data_quality_file,
        continuous_summary_file,
        binary_summary_file,
        followup_figure,
        marker_figure,
        km_outputs,
        group_comparison_outputs,
        cox_outputs,
        diagnostics_outputs,
        validation_outputs
      ),
      c(
        file.path("report", "survival-analysis-tutorial.md"),
        file.path("report", "survival-analysis-tutorial.html")
      )
    ),
    format = "file"
  )
)
