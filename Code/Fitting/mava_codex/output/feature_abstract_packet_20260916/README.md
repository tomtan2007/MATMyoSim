# Feature-based twitch prototype — PI review packet

## Main result

The feature objective now runs end-to-end with the 6-state simulator while the
existing pointwise fitting path remains unchanged. The present fits are capped,
single-start diagnostics using averaged traces; they are not population fits or
converged parameter estimates.

- Acute mavacamten peak force was 30% of the paired Before trace in Control and
  33% in H251N in the source-scale averages.
- The 3-parameter prototype (`k_1`, `k_3`, `k_5_0`) had feature errors of 5.74
  for Control and 10.47 for H251N.
- Adding `k_4_0` and `k_7_3` reduced the H251N error to 2.91 but did not improve
  Control at the current budget (6.20).
- Control onset remained approximately 186 ms too early in the model. This
  should not be interpreted mechanistically until stimulus alignment is known.
- These runs do not support a unique kinetic-driver claim.

## Figure caption

**Feature-based fitting isolates interpretable twitch mismatches.** (A) Peak
force in the averaged source traces, normalized to the paired Before condition.
(B) Mean squared standardized feature error for exploratory three- and
five-parameter 6-state fits. (C) Five-parameter residuals relative to provisional
feature tolerances. (D-E) Waveform context for the Control and H251N acute fits;
the waveform itself was not the pointwise objective. Fits were single-start and
stopped at 30 or 50 function evaluations. Feature AIC was not calculated because
the summary features are correlated and population variance is not yet known.

## Next gate

Import the individual-cell normalized workbook, estimate feature variability
and covariance, confirm stimulus alignment, freeze the objective, and only then
run multistart comparisons. The generated `prepared_data/` directory is a
reproducibility input for the displayed simulations, not a population dataset.
