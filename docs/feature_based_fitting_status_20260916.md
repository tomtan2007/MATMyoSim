# Feature-based twitch fitting status — 2026-09-16

## Implemented objective

The prototype optimizer scores nine interpretable twitch features:

1. peak amplitude
2. force-onset delay
3. 20% to 50% activation interval
4. time to peak
5. duration above 50% amplitude
6. 95% peak-plateau duration
7. peak-to-50% relaxation
8. peak-to-90% relaxation (10% force remaining)
9. positive AUC from force onset through 50% relaxation, divided by peak

An experimental feature that cannot be observed before the recording ends is
excluded rather than imputed. A missing model feature is penalized. The score
is the mean weighted squared residual after division by explicit tolerances.

Current tolerances are provisional. Timing floors are no tighter than 32.1 ms,
approximately one sample in the source Mava workbook. They must be replaced
with population variability when individual-cell normalized data are available.

## Optimizer integration

- New fit mode: `fit_twitch_features`
- Existing `fit_in_time_domain` behavior is unchanged.
- Feature-fit AIC is deliberately reported as `NaN`. The features are correlated
  summary statistics, so the pointwise waveform AIC formula is not valid.
- A population-error likelihood and feature covariance/variance model are needed
  before using AIC for feature-based model comparison.

## Verification completed

- Perfect synthetic model/target pair has zero feature error.
- A lower, delayed, broader synthetic twitch scores worse.
- Unobserved experimental relaxation is excluded.
- Real 6-state simulation runs through the new objective.
- Legacy time-fit and fit-controller regression tests still pass.

## Capped prototype fits

All fits below are single-start exploratory runs stopped by their evaluation
budget. They are not converged multistart estimates and do not support driver
claims.

| Condition | Free parameters | Evaluations | Feature error | Interpretation |
|---|---|---:|---:|---|
| Control acute | `k_1, k_3, k_5_0` | 30 | 5.74 | Best small Control prototype |
| Control acute | `k_1, k_3, k_5_0, k_4_0, k_7_3` | 50 | 6.20 | No improvement at this budget |
| H251N acute | `k_1, k_3, k_5_0` | 30 | 10.47 | Duration/relaxation remain poor |
| H251N acute | `k_1, k_3, k_5_0, k_4_0, k_7_3` | 50 | 2.91 | Large exploratory improvement |

### Residual pattern

- Control amplitude, rise interval, time-to-peak, and bounded AUC can be matched.
- Control force onset remains about 186 ms too early, and the simulated plateau
  remains too broad.
- H251N onset, rise interval, plateau, and 50% relaxation improve in the 5-parameter
  prototype.
- H251N amplitude is about 23% high; peak timing and 90% relaxation remain too fast.

The Control onset result depends on the unresolved stimulus-alignment question.
The source workbook does not state whether all six traces share an absolute
electrical/calcium stimulus time. Do not interpret onset parameter effects until
that metadata question is answered.

## Next execution gate

1. Import the normalized workbook and identify its normalization rule.
2. Determine whether it contains individual-cell traces or only condition means.
3. Estimate feature variability/covariance where population data permit.
4. Confirm the alignment policy for onset-related features.
5. Freeze the objective specification.
6. Run multiple starts for the 3- and 5-parameter prototypes.
7. Extend the frozen objective to 3-, 4-, and 6-state comparisons.

The existing whole-waveform AIC results remain separate and authoritative until
a statistically valid feature likelihood is defined.
