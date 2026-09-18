# Non-Mava joint feature-fit screen — 2026-09-18

## Data verification

No Mavacamten data were used. `Updated cell trace data.xlsx` is the force/time authority because it contains all 36 samples and their original timestamps. Its Control force column contains `Con_C4_D96_c48b.mat` as rows 4–34 (31 samples; maximum absolute difference `4.78e-7` N/m²) and its H251N column contains `H251N_C3_D96_c63b.mat` as rows 3–34 (32 samples; `4.98e-7` N/m²). `cell_time_trace.mat` is a different 34-point normalized time vector and was not paired with either named MAT force trace.

`Ca_transients2.mat` was inspected but not substituted for the PI-approved `Code/System/protocols/protocol_1s.txt`. The calcium reference is 0.480 s. Both force traces keep their original spreadsheet timestamps; force onset is independently detected for each trace relative to that reference.

## Objective

The joint objective is the mean of Control and H251N mean squared standardized residuals for nine features: peak amplitude, force-onset delay, 20–50% activation rise time, time to peak, duration above 50% peak, peak-plateau duration, peak-to-50% relaxation, peak-to-90% relaxation, and normalized positive-force AUC. Smoothing identifies landmarks only. Amplitude is a robust top-of-peak statistic from the original signal and AUC uses the original signal. Sustained crossings and a contiguous dominant-peak band reject isolated spikes and minor secondary peaks.

## Numerical screen

Four deterministic bounded starts, capped at 100 function evaluations each, were used per stage. `k_on`, `k_off`, and `k_coop` were fixed identically at the Control template values. `k_2` was not free and was automatically tied to `10*k_1`.

| Stage | Best error | Median restart error | Decision |
| --- | ---: | ---: | --- |
| `k_1`, `k_3`, `k_5_0` | 0.5433 | 1.5989 | Initial screen |
| Core + `k_4_0` | 0.5424 | 0.9859 | Rejected: 0.16% best-case improvement, not consistent across starts |
| Core + `k_7_3` | 0.5425 | 0.7344 | Rejected: 0.15% best-case improvement; late timing residuals remained |

The best core fit captures amplitude, rise, width, plateau, and normalized AUC reasonably, but leaves H251N time-to-peak and the two relaxation landmarks outside their provisional feature tolerances. See `output/core_k1_k3_k50_r4/` and `output/stage_comparison.csv`.

## Limits

These are single-Control/single-H251N numerical results, not a unique mutation mechanism. One of four core starts was within 10% of the best objective, and the parameter table shows broad between-start variation. No feature-based AIC was calculated: the nine correlated summary features do not provide independent pointwise residuals or population feature variances. The 100-evaluation caps also mean this is a bounded multistart screen, not proof of a global optimum.
