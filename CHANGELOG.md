# Changelog

This project uses `MAJOR.MINOR.PATCH` version labels as a practical release
convention for the analysis and its reproducibility infrastructure.

## [0.2.0] - 2026-07-28

### Added

- Seventy-seven automated expectations for data, estimators, models, EDA
  functions, and pipeline helpers.
- An `renv` lockfile recording R 4.5.2 and the complete package dependency
  graph.
- A 27-target pipeline spanning official data download through Markdown and
  HTML report rendering.
- GitHub Actions continuous integration on `main`, `develop`, and pull
  requests targeting either branch.
- Clean Ubuntu validation, including the required GLPK system library.
- Uploaded tutorial artifacts from every CI run.
- Beginner-oriented lessons on testing, Git workflows, dependency locking,
  pipelines, CI, and releases in `notes.md`.

### Changed

- Refactored data ingestion and exploratory analysis into reusable functions.
- Kept numbered scripts as manual entry points backed by the shared functions.
- Adopted feature, integration, temporary release, and stable branch roles.

### Validation

- All 77 software expectations pass locally and in GitHub Actions.
- All 27 pipeline targets rebuild from an empty cache.
- All 500 bootstrap model fits complete successfully.
- Markdown and HTML tutorials render on a clean Ubuntu runner.

## [0.1.0] - 2026-07-28

### Added

- UCI Heart Failure Clinical Records download and exploratory analysis.
- Kaplan–Meier estimation and manual estimator validation.
- Grouped survival comparisons and log-rank tests.
- Prespecified and refined Cox proportional-hazards models.
- Proportional-hazards, nonlinearity, residual, and influence diagnostics.
- Bootstrap internal validation and 90-day calibration.
- Worked R Markdown tutorial and living learning notes.

[0.2.0]: https://github.com/cjgunase/heart-failure-survival-analysis-r/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/cjgunase/heart-failure-survival-analysis-r/releases/tag/v0.1.0
