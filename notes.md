# Survival Analysis Learning Notes

These are my living study notes for the Heart Failure Survival Analysis in R
project. I will update them as the project progresses.

## Project question

Which baseline patient characteristics are associated with time to death among
patients with heart failure?

This is a **prognostic association** question. The current dataset cannot show
that a characteristic causes death or that changing it would improve survival.

## Why survival analysis?

Ordinary analysis might record only whether someone died:

```text
96 deaths / 299 patients = 32.1%
```

That calculation ignores:

- when each death occurred;
- how long each patient was followed;
- patients whose final death time is unknown.

Survival analysis uses both the event status and observed follow-up time.

## The two essential variables

Each patient contributes:

```text
(observed follow-up time, event indicator)
```

In this project:

- `followup_days` is the observed follow-up time;
- `death = 1` means death was observed;
- `death = 0` means the observation was censored.

`followup_days` is not necessarily time to death. For a censored patient, it is
the last time the patient was known to be under observation.

## Censoring

A patient censored at day 100 tells us:

\[
T > 100
\]

The patient survived for at least 100 days, but the eventual death time is
unknown.

Censoring does not mean:

- the patient survived forever;
- the event could never happen;
- the observation should be deleted;
- the censored patient should be counted as a death.

A censored patient contributes information until the censoring time and then
leaves later risk sets.

### Independent-censoring assumption

Kaplan–Meier estimation assumes censoring is not systematically related to
unobserved future event risk, after considering relevant available information.

If the sickest patients systematically disappeared from follow-up, estimated
survival could be too optimistic.

## Exploratory data findings

The UCI Heart Failure Clinical Records dataset contains:

- 299 patients;
- 13 analysis variables;
- 96 observed deaths;
- 203 censored observations;
- no missing cells;
- no duplicate rows;
- follow-up from 4 to 285 days;
- median observed follow-up of 115 days.

The observed death proportion is 32.1%, but this proportion alone is not a
survival estimate.

Important distributional findings:

- creatinine phosphokinase is strongly right-skewed;
- serum creatinine is strongly right-skewed;
- median ejection fraction is 38%;
- extreme values should be investigated rather than automatically deleted.

## Creating a survival outcome in R

```r
library(survival)

survival_outcome <- with(
  heart,
  Surv(followup_days, death)
)
```

`Surv()` combines observed time and event status. It represents the outcome but
does not itself fit a model.

Censored observations are commonly printed with a `+`:

```text
100+  means censored after 100 days
100   means the event was observed at 100 days
```

## Survival function

Let \(T\) represent time to death. The survival function is:

\[
S(t) = P(T > t)
\]

It is the probability of remaining event-free beyond time \(t\).

Properties:

- \(S(0)\) usually begins at 1;
- it cannot increase;
- it falls when events occur;
- censoring does not directly make it fall;
- it may not reach zero during observed follow-up.

Example:

\[
\hat S(90) = 0.763
\]

This means the estimated probability of surviving beyond 90 days is 76.3%.

## Risk set

The risk set at time \(t\) contains patients who:

- have not previously experienced death; and
- have not previously been censored.

At event time \(t_j\):

- \(n_j\) is the number at risk immediately before \(t_j\);
- \(d_j\) is the number of deaths at \(t_j\).

Numbers at risk matter because estimates near the end of follow-up may be based
on very few patients.

## Kaplan–Meier estimator

The conditional probability of surviving event time \(t_j\) is:

\[
p_j = \frac{n_j-d_j}{n_j}
\]

Kaplan–Meier multiplies these conditional probabilities:

\[
\hat S(t) =
\prod_{t_j \leq t}
\left(1-\frac{d_j}{n_j}\right)
\]

This is a nonparametric estimator: it does not require survival times to follow
a normal or another named probability distribution.

### Worked calculation from this dataset

At day 4:

```text
n = 299
deaths = 1
```

\[
\hat S(4)=\frac{298}{299}=0.9967
\]

At day 6:

```text
n = 298
deaths = 1
```

\[
\hat S(6)
=
\frac{298}{299}
\times
\frac{297}{298}
=
0.9933
\]

At day 7, two of 297 at-risk patients died:

\[
\hat S(7)
=
0.9933
\times
\frac{295}{297}
=
0.9866
\]

The probabilities are multiplied because survival at a later time requires
surviving every earlier event time.

## What censoring does to the curve

At day 12:

```text
At risk = 285
Deaths = 0
Censored = 1
```

\[
\frac{285-0}{285}=1
\]

The survival curve does not fall. The censored patient is removed from future
risk sets.

Core rule:

> Events lower estimated survival. Censoring reduces the information available
> for later estimates.

## Kaplan–Meier estimation in R

```r
km_fit <- survfit(
  Surv(followup_days, death) ~ 1,
  data = heart,
  conf.type = "log"
)

print(km_fit)
summary(km_fit)
```

In the formula:

- the left side is the survival outcome;
- `~ 1` requests one overall curve;
- later, a grouping variable can replace `1`.

Our manual risk-set calculation matched `survfit()` exactly.

## Current Kaplan–Meier results

| Time | Number at risk | Survival | 95% confidence interval |
|---:|---:|---:|---:|
| 30 days | 264 | 88.2% | 84.6%–92.0% |
| 60 days | 239 | 81.7% | 77.4%–86.3% |
| 90 days | 189 | 76.3% | 71.5%–81.3% |
| 180 days | 106 | 65.4% | 59.6%–71.9% |
| 270 days | 6 | 57.6% | 50.1%–66.1% |

A rigorous interpretation is:

> The Kaplan–Meier estimated probability of surviving beyond 90 days was 76.3%
> (95% CI: 71.5%–81.3%).

It is better not to say “76.3% of patients were alive,” because Kaplan–Meier is
an estimate that accounts for censored observations.

## Reading the Kaplan–Meier graph

- A horizontal segment means no observed deaths occurred.
- A downward step means one or more deaths occurred.
- A larger step generally means more events relative to the risk set.
- A `+` mark indicates censoring.
- Dashed lines show the 95% confidence interval.
- The risk table shows how many patients still support the estimate.

At day 270, only six patients remain at risk. The tail should therefore be
interpreted cautiously.

## Median survival

Median survival is the first time at which:

\[
\hat S(t) \leq 0.50
\]

The curve remained above 50%, so median survival was **not reached**.

This does not mean median survival is infinite. It means the study did not
observe enough follow-up and events to estimate it.

## Survival probability versus hazard

Survival probability asks:

> What is the probability of remaining event-free beyond a time?

Hazard asks:

> Among people who have survived until now, how rapidly are events occurring
> now?

Hazard is a rate, not a probability. A hazard ratio must not be interpreted as
a direct percentage difference in survival probability.

## Modeling roadmap

```text
Kaplan–Meier
  describes survival over time

Grouped Kaplan–Meier
  visually compares survival between groups

Log-rank test
  tests for an overall difference between survival curves

Cox proportional-hazards regression
  estimates adjusted associations as hazard ratios

Model diagnostics
  check whether the Cox-model assumptions are reasonable
```

## Common mistakes to avoid

1. Treating censored observations as deaths.
2. Treating censored observations as permanent survivors.
3. Comparing only the percentage with an event.
4. Ignoring differences in follow-up time.
5. Reporting late survival estimates without numbers at risk.
6. Calling association causation.
7. Saying “median survival is infinite” when the median is not reached.
8. Interpreting a hazard ratio as a direct difference in survival probability.
9. Removing extreme clinical values without investigation.
10. Fitting many predictors simply because they are available.

## Files created so far

- `R/01-download-data.R`: downloads and validates the official dataset.
- `R/02-exploratory-analysis.R`: checks and explores the data.
- `R/03-kaplan-meier.R`: performs manual and package Kaplan–Meier estimation.
- `outputs/tables/kaplan-meier-event-table.csv`: complete risk-set arithmetic.
- `outputs/figures/overall-kaplan-meier.png`: overall curve and risk table.

## Questions I can now answer

- Why is ordinary event percentage insufficient?
- What does censoring mean?
- What is a risk set?
- What does \(S(t)\) represent?
- How is Kaplan–Meier calculated?
- Why do events lower the curve but censoring does not?
- Why are numbers at risk important?
- Why might median survival be unavailable?

## Stage 3: Grouped Kaplan–Meier analysis

The overall Kaplan–Meier curve describes the complete sample. A grouped curve
asks whether survival patterns differ between levels of a baseline variable.

The primary educational comparison was:

```r
heart <- heart |>
  mutate(
    ef_group = factor(
      if_else(ejection_fraction < 40, "EF < 40%", "EF ≥ 40%")
    )
  )

ef_km <- survfit(
  Surv(followup_days, death) ~ ef_group,
  data = heart
)
```

The right side of the formula now contains `ef_group`, so `survfit()` estimates
one curve for each group.

### Check the groups before comparing them

| Group | Patients | Deaths | Censored |
|---|---:|---:|---:|
| EF below 40% | 182 | 73 | 109 |
| EF at least 40% | 117 | 23 | 94 |

The observed death percentages differ, but grouped Kaplan–Meier analysis also
accounts for when deaths and censoring occurred.

### Selected survival estimates

| Time | EF below 40% | EF at least 40% |
|---:|---:|---:|
| 30 days | 86.7% | 90.6% |
| 90 days | 71.3% | 84.0% |
| 180 days | 58.7% | 77.2% |

The ejection-fraction curves separate during follow-up. The lower-ejection-
fraction group has lower estimated survival in this sample.

### Log-rank test

The log-rank test compares observed deaths in each group with the deaths that
would be expected if the groups shared the same survival experience.

```r
ef_log_rank <- survdiff(
  Surv(followup_days, death) ~ ef_group,
  data = heart
)
```

Hypotheses:

- \(H_0\): the groups have the same survival experience;
- \(H_1\): their survival experiences differ.

For ejection fraction:

```text
Chi-square = 9.47
Degrees of freedom = 1
p = 0.0021
```

This is evidence against equal survival curves. It does not measure the size of
the association and does not show that ejection fraction causes the difference.

### Secondary sex comparison

```text
Log-rank chi-square = 0.004
p = 0.950
```

The female and male survival estimates were nearly identical:

| Time | Female | Male |
|---:|---:|---:|
| 30 days | 90.3% | 87.1% |
| 90 days | 76.2% | 76.3% |
| 180 days | 66.0% | 65.0% |

A large p-value is not proof that the groups are identical. It means the data do
not provide evidence of an overall survival difference.

### Limitations of grouped analysis

- Dividing a continuous measurement at a cutpoint loses information.
- Results can change if a different cutpoint is selected.
- The log-rank test provides a p-value but not an adjusted effect estimate.
- Other characteristics may differ between the groups.
- Testing many possible groups increases the chance of false-positive results.
- Kaplan–Meier comparisons describe association, not causation.

The ejection-fraction grouping is useful for teaching and visualization. The Cox
model should retain ejection fraction as a continuous measurement.

### New interpretation template

> Estimated survival was lower for patients with baseline ejection fraction
> below 40% than for patients with ejection fraction of at least 40%. The
> log-rank test provided evidence of an overall difference between the curves
> (\(\chi^2=9.47\), \(p=0.0021\)). This unadjusted association should not be
> interpreted as causal.

## Stage 4: Cox proportional-hazards regression

Kaplan–Meier describes survival, and the log-rank test compares unadjusted
curves. Cox regression estimates the association between predictors and the
event hazard while accounting for observed follow-up and censoring.

The model is:

\[
h(t\mid X)=h_0(t)\exp(\beta_1X_1+\cdots+\beta_pX_p)
\]

Where:

- \(h(t\mid X)\) is the hazard for a patient with characteristics \(X\);
- \(h_0(t)\) is an unspecified baseline hazard;
- each \(\beta\) represents a predictor's association with log hazard;
- \(\exp(\beta)\) is a hazard ratio.

The Cox model does not need to specify the shape of the baseline hazard.

### How the Cox model learns

At each death time, the Cox partial likelihood compares the patient who died
with all patients who were still in the risk set. Predictor values associated
with earlier deaths receive coefficients corresponding to higher hazard.

Censored patients contribute to risk sets until their censoring times but never
appear as observed deaths.

### Predictor units used

Predictors were scaled into interpretable units:

```r
heart <- heart |>
  mutate(
    age_per_10_years = age / 10,
    ef_per_5_points = ejection_fraction / 5,
    creatinine_per_doubling = log2(serum_creatinine),
    sodium_per_5_units = serum_sodium / 5
  )
```

- age: hazard ratio per 10-year increase;
- ejection fraction: hazard ratio per 5-point increase;
- creatinine: hazard ratio per doubling;
- sodium: hazard ratio per 5-mEq/L increase;
- sex: male compared with female.

Scaling changes interpretation but does not change the underlying model fit.
The log2 transformation makes a right-skewed creatinine measurement
interpretable as a doubling.

### Univariable versus multivariable models

A univariable model contains one predictor:

```r
coxph(
  Surv(followup_days, death) ~ age_per_10_years,
  data = heart
)
```

A multivariable model estimates each association conditional on the other
included predictors:

```r
adjusted_model <- coxph(
  Surv(followup_days, death) ~
    age_per_10_years +
    ef_per_5_points +
    creatinine_per_doubling +
    sodium_per_5_units +
    sex_group,
  data = heart,
  ties = "efron"
)
```

This model has 96 deaths and five coefficients, or approximately 19.2 observed
events per coefficient.

### Adjusted model results

| Predictor and unit | Hazard ratio | 95% confidence interval | p-value |
|---|---:|---:|---:|
| Age, per 10 years | 1.52 | 1.28–1.82 | <0.001 |
| Ejection fraction, per 5 points | 0.81 | 0.73–0.90 | <0.001 |
| Creatinine, per doubling | 1.85 | 1.40–2.46 | <0.001 |
| Sodium, per 5 mEq/L | 0.88 | 0.70–1.10 | 0.263 |
| Male versus female | 0.82 | 0.53–1.25 | 0.350 |

Interpretations:

- Each 10-year increase in age was associated with approximately 52% higher
  instantaneous mortality hazard, conditional on the included predictors.
- Each 5-point increase in ejection fraction was associated with approximately
  19% lower hazard.
- A doubling of serum creatinine was associated with approximately 85% higher
  hazard.
- Sodium and sex confidence intervals included 1, so this model did not provide
  clear evidence of adjusted associations for those predictors.

These percentages describe relative hazard, not absolute survival probability.

### Why adjustment changes results

Serum sodium had a univariable hazard ratio of 0.71 with a confidence interval
excluding 1. After adjustment, its hazard ratio became 0.88 with a confidence
interval containing 1.

This means some of sodium's unadjusted association was shared with information
in age, ejection fraction, creatinine, or sex. It does not prove which variable
confounded or mediated the relationship.

### Confidence intervals and the null value

The null hazard ratio is 1:

- an interval entirely above 1 supports a higher-hazard association;
- an interval entirely below 1 supports a lower-hazard association;
- an interval containing 1 includes no association among its plausible values.

The confidence interval communicates both direction and precision and is more
informative than the p-value alone.

### Model concordance

The adjusted model's concordance was:

\[
C=0.724
\]

Informally, among comparable patient pairs, the model assigned higher predicted
risk to the patient with the earlier observed death about 72% of the time.

Concordance measures discrimination. It does not prove that predicted survival
probabilities are well calibrated, clinically useful, or externally valid.

### Proportional-hazards assumption

The basic Cox model assumes each hazard ratio is approximately constant over
follow-up:

\[
\frac{h_1(t)}{h_0(t)}=HR
\]

The assumption was tested using scaled Schoenfeld residuals:

```r
ph_check <- cox.zph(adjusted_model)
```

Results:

```text
Global p-value = 0.233
Ejection-fraction p-value = 0.060
All other predictor p-values > 0.30
```

The global test did not provide clear evidence of a proportional-hazards
violation. A large p-value does not prove the assumption, and ejection fraction
should receive visual residual assessment because its p-value was relatively
close to 0.05.

### What this model does not establish

- The associations are not necessarily causal.
- “Holding other variables constant” is a model interpretation, not physical
  control of patients.
- Linear predictor terms assume a particular functional shape.
- Internal concordance can be optimistic without validation.
- Results from 299 patients may not generalize to another population.
- The model must not be used for clinical decisions.

### New interpretation template

> In the multivariable Cox model, a five-point increase in baseline ejection
> fraction was associated with a 19% lower mortality hazard (HR 0.81, 95% CI
> 0.73–0.90), conditional on age, serum creatinine, serum sodium, and sex. This
> observational prognostic association should not be interpreted as causal.

## Stage 5: Cox-model diagnostics

A fitted model can produce coefficients and p-values even when its assumptions
are inadequate. Diagnostics ask whether the model is a reasonable summary of
the observed data.

Diagnostic flags are prompts for investigation. They are not automatic reasons
to remove observations or select a more complicated model.

### Proportional hazards

Scaled Schoenfeld values were plotted against transformed follow-up time. After
centering each series on its fitted coefficient, a horizontal pattern around
zero supports a time-constant coefficient. A systematic trend may suggest that
the coefficient changes over time.

```text
Global proportional-hazards p-value = 0.233
Ejection-fraction p-value = 0.060
```

The global test did not provide clear evidence against proportional hazards.
Ejection fraction showed the strongest possible time trend, but the evidence
was not definitive. Tests and plots should be considered together.

A large p-value does not prove proportional hazards, especially in a small
sample where a test may have limited power.

### Functional-form assumption

The original model assumes each continuous predictor has a straight-line
relationship with log hazard:

\[
\log h(t\mid X)=\log h_0(t)+\beta X
\]

Natural splines allow smooth curvature. Each continuous linear term was
compared with a natural spline using three degrees of freedom while the other
terms remained unchanged.

| Predictor | Nonlinearity p-value |
|---|---:|
| Age | 0.067 |
| Ejection fraction | 0.0013 |
| Serum creatinine after log2 transformation | 0.861 |
| Serum sodium | 0.815 |

The diagnostic suggests that the linear ejection-fraction term is too simple.
The evidence for age curvature is weaker. There was no nonlinearity signal for
transformed creatinine or sodium.

Comparing all continuous spline terms with the linear model gave:

```text
Likelihood-ratio chi-square = 20.96
Additional degrees of freedom = 8
p = 0.0073

Linear model AIC = 957.6
All-spline model AIC = 952.6
```

The improvement is primarily driven by ejection fraction. Adding splines for
every predictor would consume eight additional parameters without evidence
that each is needed.

### Ejection-fraction spline

A three-degree-of-freedom natural spline was fitted for ejection fraction,
adjusting for the same other predictors. Ejection fraction of 40% was used as
the reference.

The estimated hazard rose sharply at very low ejection fractions. Around and
above 40%, the curve was relatively flat, with increasingly wide confidence
intervals at sparse high values.

For illustration, EF around 20% had an estimated adjusted hazard ratio of about
4.6 relative to EF 40%. This estimate should be interpreted cautiously because
it depends on model shape and fewer observations support extreme values.

The spline curve demonstrates why one hazard ratio per five-point increase can
be misleading: a five-point difference may not have the same association at EF
20% as at EF 50%.

### Deviance residuals

Deviance residuals summarize disagreement between observed outcomes and fitted
risk. Large positive residuals often represent earlier-than-expected events.
Large negative residuals can represent unexpectedly long event-free follow-up.

One observation exceeded the exploratory absolute threshold of 3:

```text
Dataset row 2
Death observed at day 6
Deviance residual = 3.11
```

This patient experienced a very early death despite predictor values that did
not lead the model to assign extremely high risk. The row should be checked for
data errors and scientific plausibility, not automatically deleted.

### DFBETAS

DFBETAS approximate how much each coefficient changes when one observation is
removed.

The screening threshold used was:

\[
\frac{2}{\sqrt{n}}=\frac{2}{\sqrt{299}}=0.116
\]

Sixty-four patients exceeded this sensitive heuristic for at least one
coefficient. A high count does not mean 64 rows are invalid. The threshold is a
screening device, and several predictors contain extreme or sparse values.

The largest value occurred for row 229:

```text
Maximum absolute DFBETAS = 0.71
Follow-up = 207 days, censored
Age = 65
Ejection fraction = 25%
Serum creatinine = 5.0 mg/dL
Serum sodium = 130 mEq/L
```

This combination is influential because the patient had several high-risk
measurements but remained event-free through substantial follow-up.

### What was learned from diagnostics

- The proportional-hazards assumption was not clearly contradicted.
- A linear ejection-fraction coefficient oversimplifies its association.
- The log2 creatinine transformation appears reasonable from the current
  functional-form test.
- At least one outcome is poorly predicted by the model.
- Several observations influence individual coefficients.
- Influential or surprising observations are scientifically informative unless
  they are confirmed data errors.
- Model complexity must be balanced against only 96 observed deaths.

### Recommended model refinement

A sensible refined model would use:

- a spline for ejection fraction;
- linear age for parsimony, with spline age as a sensitivity analysis;
- log2-transformed creatinine;
- linear sodium;
- sex as a binary factor.

This refinement should be prespecified before validation rather than repeatedly
changed to optimize apparent performance.

## Stage 6: Bootstrap internal validation

Performance measured on the same patients used to fit a model is usually
optimistic. Internal validation estimates how much performance may deteriorate
for similar new patients from the same underlying population.

The refined model was fixed before validation:

```r
Surv(followup_days, death) ~
  age_per_10_years +
  ns(ef_per_5_points, df = 3) +
  creatinine_per_doubling +
  sodium_per_5_units +
  sex_group
```

The model uses 3 spline coefficients for ejection fraction and one coefficient
for each remaining predictor, for 7 coefficients total.

### Bootstrap algorithm

For each of 500 bootstrap resamples:

1. Sample 299 patients with replacement.
2. Fit the complete refined model in the bootstrap sample.
3. Measure concordance in that bootstrap training sample.
4. Apply the fitted bootstrap model to the original data.
5. Calculate training minus test concordance as estimated optimism.
6. Predict 90-day survival for patients not selected in that resample.
7. Record hazard-ratio coefficients and spline contrasts.

The random seed was fixed at `20260728`, making the results reproducible.

All 500 model fits succeeded.

### Optimism-corrected concordance

```text
Apparent concordance                    0.750
Mean bootstrap training concordance     0.755
Mean bootstrap test concordance         0.739
Mean estimated optimism                 0.016
Optimism-corrected concordance           0.735
```

The correction is:

\[
C_{\text{corrected}}
=
C_{\text{apparent}}
-
\overline{
  \left(
  C_{\text{bootstrap training}}
  -
  C_{\text{bootstrap test}}
  \right)
}
\]

The apparent value overstates expected ranking performance by approximately
0.016. Corrected concordance around 0.735 indicates useful but imperfect
discrimination in similar patients.

The 2.5th and 97.5th percentiles of bootstrap test concordance were 0.723 and
0.748. These describe the bootstrap distribution; they are not presented as a
formal external-performance confidence interval.

### Out-of-bag predictions

Because sampling is performed with replacement, about 36.8% of patients are
absent from any one bootstrap sample. These are **out-of-bag** patients for that
resample.

Each patient received between 143 and 227 predictions from models that were
fitted without that patient. Averaging these predictions provides a less
optimistic internal prediction than using the full-sample fitted value.

### Calibration at 90 days

Discrimination and calibration answer different questions:

- discrimination: are higher-risk patients ranked above lower-risk patients?
- calibration: do predicted probabilities agree with observed frequencies?

Patients were placed into quintiles of predicted 90-day survival. Within each
quintile:

- mean predicted survival was calculated;
- observed survival was estimated with Kaplan–Meier;
- predicted and observed survival were compared.

For the out-of-bag predictions:

| Quintile | Predicted | KM observed |
|---:|---:|---:|
| 1, lowest predicted survival | 45.4% | 50.9% |
| 2 | 72.8% | 65.2% |
| 3 | 83.8% | 86.4% |
| 4 | 89.2% | 86.5% |
| 5, highest predicted survival | 93.6% | 93.1% |

Calibration is broadly reasonable, but the second quintile shows
overprediction of survival by about 7.6 percentage points. Confidence intervals
are wide because each quintile contains only about 60 patients.

Grouped calibration can hide disagreement within groups and depends on the
chosen follow-up time and number of groups.

### Bootstrap stability of model effects

Important bootstrap percentile ranges:

| Contrast | Full-sample HR | Bootstrap median | 2.5th–97.5th percentiles |
|---|---:|---:|---:|
| Age per 10 years | 1.57 | 1.58 | 1.32–1.94 |
| EF 20% versus 40% | 4.70 | 4.82 | 2.61–10.23 |
| EF 30% versus 40% | 1.37 | 1.41 | 0.89–2.28 |
| EF 50% versus 40% | 1.02 | 0.98 | 0.72–1.33 |
| Creatinine per doubling | 1.69 | 1.71 | 1.20–2.52 |
| Sodium per 5 mEq/L | 0.89 | 0.88 | 0.68–1.15 |
| Male versus female | 0.81 | 0.79 | 0.50–1.26 |

Age, very low EF, and creatinine associations were relatively consistent.
Spline contrasts around and above EF 40%, sodium, and sex varied across the null
value of 1.

The wide range for EF 20% reflects both a strong estimated association and
substantial uncertainty at the lower edge of the data.

### What internal validation does not prove

- It does not show performance in another hospital or country.
- It does not fix selection bias or measurement error.
- It does not establish causal effects.
- It does not prove clinical usefulness.
- It assumes future patients resemble the population that produced this
  dataset.

External validation on an independent dataset would be required before claiming
generalizability.

### What was learned from validation

- Apparent model performance is optimistic.
- Bootstrap resampling replays the entire model-fitting process.
- Out-of-bag predictions approximate predictions for unseen patients.
- Concordance measures ranking, while calibration measures probability
  accuracy.
- A model can discriminate reasonably while being miscalibrated in part of the
  risk range.
- Flexible spline effects can be stable in one region and uncertain elsewhere.

## Stage 7: Reproducible tutorial report

The complete analysis was assembled into:

```text
report/survival-analysis-tutorial.Rmd
```

R Markdown was used because Quarto was not installed in the working
environment. The same source renders:

- `survival-analysis-tutorial.md` for direct reading on GitHub;
- `survival-analysis-tutorial.html` as a self-contained interactive document
  with a table of contents and collapsible code.

Render both formats with:

```r
rmarkdown::render(
  "report/survival-analysis-tutorial.Rmd",
  output_format = "all"
)
```

The report separates:

- executable code;
- displayed results;
- statistical interpretation;
- assumptions and diagnostics;
- limitations;
- noncausal conclusions.

The modular scripts remain the source of generated tables and figures. The
report reads those outputs and refits the lightweight core models, while the
expensive 500-resample bootstrap is not rerun during every report render.

### Reporting lessons

- Begin with the scientific question, not the model.
- Explain what one data row represents.
- Define censoring before presenting a survival curve.
- Put effect estimates and confidence intervals before p-value discussion.
- Show numbers at risk beneath Kaplan–Meier curves.
- Report diagnostics that challenge the initial model.
- Distinguish discrimination from calibration.
- State clearly whether conclusions are descriptive, associational,
  predictive, or causal.
- Include enough code and provenance for another person to reproduce results.
- End with limitations that constrain the claims.

## Possible next steps

- Commit and publish Stages 2–7 to GitHub.
- Add an R package dependency lockfile with `renv`.
- Add GitHub Actions to render the tutorial automatically.
- Perform external validation if a genuinely comparable independent dataset is
  available.
- Avoid adding new models unless they answer a clearly defined scientific or
  educational question.
