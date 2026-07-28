library(targets)

source(file.path("R", "functions-data.R"))
source(file.path("R", "functions-eda.R"))

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
  )
)
