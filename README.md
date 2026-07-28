# Heart Failure Survival Analysis in R

An educational, reproducible survival-analysis project using the UCI Heart
Failure Clinical Records dataset.

## Current stage

Stage 1 downloads the data from its official source and performs exploratory
analysis. Survival models will be added in later stages.

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

## Run stage 1

Run these commands from the repository root:

```r
source("R/01-download-data.R")
source("R/02-exploratory-analysis.R")
```

Or from a terminal:

```bash
Rscript R/01-download-data.R
Rscript R/02-exploratory-analysis.R
```

The exploratory script requires `dplyr`, `ggplot2`, and `readr`.

## Outputs

- Clean analysis data: `data/processed/heart_failure_clean.csv`
- Data-quality summary: `outputs/tables/data-quality-summary.csv`
- Continuous-variable summary: `outputs/tables/continuous-summary.csv`
- Binary-variable summary: `outputs/tables/binary-summary.csv`
- Exploratory figures: `outputs/figures/`

## Planned stages

1. Data download and exploratory analysis
2. Kaplan–Meier estimation
3. Group comparisons and log-rank tests
4. Cox proportional-hazards regression
5. Model diagnostics and communication of results
