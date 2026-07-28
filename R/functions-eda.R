# Reusable exploratory-analysis functions.

add_eda_labels <- function(heart) {
  heart |>
    dplyr::mutate(
      death_label = factor(
        death,
        levels = c(0, 1),
        labels = c("Censored", "Death observed")
      ),
      sex_label = factor(
        sex,
        levels = c(0, 1),
        labels = c("Female", "Male")
      ),
      anaemia_label = factor(
        anaemia,
        levels = c(0, 1),
        labels = c("No", "Yes")
      ),
      diabetes_label = factor(
        diabetes,
        levels = c(0, 1),
        labels = c("No", "Yes")
      ),
      high_bp_label = factor(
        high_blood_pressure,
        levels = c(0, 1),
        labels = c("No", "Yes")
      ),
      smoking_label = factor(
        smoking,
        levels = c(0, 1),
        labels = c("No", "Yes")
      )
    )
}

summarize_data_quality <- function(heart) {
  dplyr::tibble(
    metric = c(
      "Rows",
      "Analysis columns",
      "Duplicate rows",
      "Missing cells",
      "Observed deaths",
      "Censored observations",
      "Death proportion",
      "Minimum follow-up days",
      "Median follow-up days",
      "Maximum follow-up days"
    ),
    value = c(
      nrow(heart),
      13,
      sum(duplicated(heart)),
      sum(is.na(heart)),
      sum(heart$death == 1),
      sum(heart$death == 0),
      mean(heart$death),
      min(heart$followup_days),
      stats::median(heart$followup_days),
      max(heart$followup_days)
    )
  )
}

summarize_continuous_variables <- function(heart) {
  continuous_variables <- c(
    "age",
    "creatinine_phosphokinase",
    "ejection_fraction",
    "platelets",
    "serum_creatinine",
    "serum_sodium",
    "followup_days"
  )

  dplyr::bind_rows(lapply(continuous_variables, function(variable) {
    values <- heart[[variable]]
    dplyr::tibble(
      variable = variable,
      n = sum(!is.na(values)),
      missing = sum(is.na(values)),
      mean = mean(values, na.rm = TRUE),
      standard_deviation = stats::sd(values, na.rm = TRUE),
      minimum = min(values, na.rm = TRUE),
      q1 = stats::quantile(
        values,
        0.25,
        na.rm = TRUE,
        names = FALSE
      ),
      median = stats::median(values, na.rm = TRUE),
      q3 = stats::quantile(
        values,
        0.75,
        na.rm = TRUE,
        names = FALSE
      ),
      maximum = max(values, na.rm = TRUE)
    )
  }))
}

summarize_binary_variables <- function(heart) {
  binary_variables <- c(
    "anaemia",
    "diabetes",
    "high_blood_pressure",
    "sex",
    "smoking",
    "death"
  )

  dplyr::bind_rows(lapply(binary_variables, function(variable) {
    heart |>
      dplyr::count(
        level = .data[[variable]],
        name = "n"
      ) |>
      dplyr::mutate(
        variable = variable,
        proportion = n / sum(n)
      ) |>
      dplyr::select(variable, level, n, proportion)
  }))
}

plot_followup_distribution <- function(heart) {
  ggplot2::ggplot(
    heart,
    ggplot2::aes(x = followup_days, fill = death_label)
  ) +
    ggplot2::geom_histogram(
      bins = 25,
      position = "identity",
      alpha = 0.60
    ) +
    ggplot2::facet_wrap(ggplot2::vars(death_label), ncol = 1) +
    ggplot2::labs(
      title = "Observed follow-up time",
      subtitle = "Censored observations are not the same as survivors",
      x = "Observed follow-up time (days)",
      y = "Number of patients",
      fill = "Follow-up outcome"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "none")
}

plot_clinical_marker_distributions <- function(heart) {
  key_markers <- heart |>
    dplyr::select(
      ejection_fraction,
      serum_creatinine,
      serum_sodium
    ) |>
    stack() |>
    dplyr::rename(value = values, marker = ind)

  ggplot2::ggplot(key_markers, ggplot2::aes(x = value)) +
    ggplot2::geom_histogram(
      bins = 25,
      fill = "#4472C4",
      color = "white"
    ) +
    ggplot2::facet_wrap(
      ggplot2::vars(marker),
      scales = "free",
      ncol = 1,
      labeller = ggplot2::as_labeller(c(
        ejection_fraction = "Ejection fraction (%)",
        serum_creatinine = "Serum creatinine (mg/dL)",
        serum_sodium = "Serum sodium (mEq/L)"
      ))
    ) +
    ggplot2::labs(
      title = "Distributions of key clinical markers",
      x = NULL,
      y = "Number of patients"
    ) +
    ggplot2::theme_minimal(base_size = 12)
}

write_eda_table <- function(table, output_file) {
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(table, output_file)
  normalizePath(output_file, winslash = "/", mustWork = TRUE)
}

save_eda_plot <- function(plot, output_file, width, height) {
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(
    output_file,
    plot,
    width = width,
    height = height,
    dpi = 300
  )
  normalizePath(output_file, winslash = "/", mustWork = TRUE)
}
