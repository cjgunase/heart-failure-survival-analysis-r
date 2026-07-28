# Heart Failure Survival Analysis in R

An educational, reproducible survival-analysis project using the UCI Heart
Failure Clinical Records dataset.

The continuously updated [learning notes](notes.md) explain the concepts,
equations, R code, interpretations, and common mistakes covered in each stage.

The complete [worked tutorial](report/survival-analysis-tutorial.md) connects
the project from censoring and Kaplan–Meier estimation through Cox regression,
diagnostics, and bootstrap validation.

## Current stage

Stages 1–6 download and explore the data, estimate overall survival, compare
prespecified groups, model adjusted prognostic associations, assess model
diagnostics, and perform bootstrap internal validation.

## Research question

Which baseline patient characteristics are associated with time to death among
patients with heart failure?

This project examines prognostic associations. It does not estimate causal
treatment effects and must not be used for clinical decisions.

## Data

- Source: [UCI Heart Failure Clinical Records](https://archive.ics.uci.edu/dataset/519/heart)
- DOI: [10.24432/C5Z89R](https://doi.org/10.24432/C5Z89R)
- License: CC BY 4.0
- Sample: 299 patients
- Survival outcome: follow-up time in days and observed death indicator

## Run the completed stages

Run these commands from the repository root:

```r
source("R/01-download-data.R")
source("R/02-exploratory-analysis.R")
source("R/03-kaplan-meier.R")
source("R/04-group-comparisons.R")
source("R/05-cox-regression.R")
source("R/06-model-diagnostics.R")
source("R/07-bootstrap-validation.R")
```

Or from a terminal:

```bash
Rscript R/01-download-data.R
Rscript R/02-exploratory-analysis.R
Rscript R/03-kaplan-meier.R
Rscript R/04-group-comparisons.R
Rscript R/05-cox-regression.R
Rscript R/06-model-diagnostics.R
Rscript R/07-bootstrap-validation.R
```

The scripts require `dplyr`, `ggplot2`, `patchwork`, `readr`, `scales`, and
`survival`.

## Outputs

- Clean analysis data: `data/processed/heart_failure_clean.csv`
- Data-quality summary: `outputs/tables/data-quality-summary.csv`
- Continuous-variable summary: `outputs/tables/continuous-summary.csv`
- Binary-variable summary: `outputs/tables/binary-summary.csv`
- Exploratory figures: `outputs/figures/`
- Full Kaplan–Meier risk-set calculation:
  `outputs/tables/kaplan-meier-event-table.csv`
- Survival estimates at selected times:
  `outputs/tables/kaplan-meier-selected-times.csv`
- Manual-versus-package validation:
  `outputs/tables/kaplan-meier-validation.csv`
- Overall Kaplan–Meier figure:
  `outputs/figures/overall-kaplan-meier.png`
- Group checks and log-rank results: `outputs/tables/`
- Grouped Kaplan–Meier figures for ejection fraction and sex:
  `outputs/figures/`
- Univariable and adjusted Cox results: `outputs/tables/cox-*.csv`
- Adjusted hazard-ratio forest plot:
  `outputs/figures/cox-adjusted-forest-plot.png`
- Cox diagnostic tables: `outputs/tables/diagnostic-*.csv`
- Schoenfeld, deviance-residual, and DFBETAS figures:
  `outputs/figures/cox-*.png`
- Bootstrap concordance, contrast-stability, calibration, and out-of-bag
  prediction results: `outputs/tables/bootstrap-*.csv`
- Bootstrap concordance and 90-day calibration figures:
  `outputs/figures/bootstrap-*.png`

## Planned stages

1. Data download and exploratory analysis — complete
2. Kaplan–Meier estimation — complete
3. Group comparisons and log-rank tests — complete
4. Cox proportional-hazards regression — complete
5. Model diagnostics — complete
6. Internal validation — complete
7. Reproducible tutorial report — complete
