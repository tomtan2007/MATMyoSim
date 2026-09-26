# PI meeting brief — Mavacamten sequential analysis

Date: 2026-09-14  
Authoritative run: `mava_seq_20260908_v2`  
Remote result commit: `edc5292`

## One-sentence result

Acute mavacamten reduces peak force to about one-third of baseline in both Control and H251N, and this suppression cannot be reproduced by changing only SRX/DRX and attachment rates; allowing the forward power-stroke parameter `k_5_0` to decrease produces the dominant fit improvement, but individual parameter magnitudes remain practically non-identifiable.

## Experimental effect

| Genotype | Before peak (N/m^2) | Acute peak (N/m^2) | Acute / Before | 24 h peak (N/m^2) | 24 h / Before |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control | 4,367.66 | 1,516.41 | 34.7% | 2,004.62 | 45.9% |
| H251N | 9,055.37 | 2,994.61 | 33.1% | 4,828.25 | 53.3% |

The fits in this capsule use the acute traces. The 24-hour values are descriptive evidence of partial recovery and were not fitted.

## Nested-model results

Reported optimization error is squared NRMSE, so the table below reports `sqrt(error)` as NRMSE.

| Group | Stage | Free treatment parameters | NRMSE | AIC | AIC improvement from prior stage |
| --- | --- | --- | ---: | ---: | ---: |
| Control, shared timing | `k123` | `k_1, k_2, k_3` | 56.2% | -1,154.62 | — |
|  | `plus_k50` | previous + `k_5_0` | 15.9% | -3,695.12 | 2,540.50 |
|  | `plus_k40` | previous + `k_4_0` | 15.8% | -3,706.38 | 11.26 |
|  | `plus_k73` | previous + `k_7_3` | 15.8% | -3,704.39 | -1.99 |
| H251N, shared timing | `k123` | `k_1, k_2, k_3` | 43.1% | -1,505.60 | — |
|  | `plus_k50` | previous + `k_5_0` | 5.24% | -5,287.85 | 3,782.25 |
|  | `plus_k40` | previous + `k_4_0` | 3.79% | -5,866.21 | 578.36 |
|  | `plus_k73` | previous + `k_7_3` | 3.75% | -5,883.95 | 17.75 |
| Control, independent timing | `k123` | `k_1, k_2, k_3` | 46.1% | -1,436.24 | — |
|  | `plus_k50` | previous + `k_5_0` | 10.5% | -4,180.50 | 2,744.26 |
|  | `plus_k40` | previous + `k_4_0` | 10.1% | -4,253.04 | 72.53 |
|  | `plus_k73` | previous + `k_7_3` | 10.1% | -4,253.18 | 0.15 |

### Interpretation

- `k123` is inadequate in every group.
- Adding `k_5_0` is the dominant improvement in every group.
- Adding `k_4_0` is supported, especially in H251N and independently aligned Control.
- `k_7_3` is supported in H251N only. It is unsupported in shared Control and essentially tied with the simpler `plus_k40` stage in independent Control.
- AIC is comparable only within the same genotype and alignment policy.

## Representative acute/Before parameter ratios

| Group | `k_1` | `k_2` | `k_3` | `k_5_0` | `k_4_0` | `k_7_3` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Shared Control, `plus_k40` | 0.137x | 1.26x | 10.0x | **0.170x** | 0.637x | — |
| Shared H251N, `plus_k73` | 0.267x | 0.627x | 7.10x | **0.229x** | 10.0x | 0.622x |
| Independent Control, `plus_k73` | 3.97x | 10.0x | 0.392x | **0.400x** | 0.100x | 0.889x |

Do not present these as identified biological fold changes. The consistent directional candidate is decreased `k_5_0`; the other estimates change strongly with alignment and optimizer basin. Free `k_2` is diagnostic only and conflicts with the standard model constraint `k_2 = 10*k_1`.

## Fit-quality details

| Group | Selected stage | Model peak error | Target vs model Ca-to-force lag | Target vs model FWHM | Readout |
| --- | --- | ---: | --- | --- | --- |
| Shared Control | `plus_k40` | -34.5% | 208 vs 0 ms | 608 ms vs unavailable | The model cannot reproduce the delayed, irregular Control trace. |
| Shared H251N | `plus_k73` | +2.8% | 4 vs 18 ms | 385 vs 378 ms | Excellent waveform agreement. |
| Independent Control | `plus_k73` | -19.2% | 15 vs 0 ms | 608 vs 676 ms | Better than shared timing, but still underestimates the peak. |

## Identifiability boundary

- All 60 fits completed and converged numerically.
- Numerical convergence does not establish a unique biological solution.
- Every parameter in every selected final-stage ensemble is classified as practically non-identifiable.
- Each group has only one start within the near-optimal AIC threshold.
- Best solutions reach important bounds: shared Control `k_3 = 10x`; H251N `k_4_0 = 10x`; independent Control `k_2 = 10x` and `k_4_0 = 0.1x`.
- The saved adaptive diagnostic therefore requests additional final-stage restarts for all three groups.

## Figures to show, in order

1. `figures/experimental_traces_and_alignment.png` — establish the 35%/33% acute effect and the unresolved Control timing shift.
2. `figures/k123_failed_fits.png` — demonstrate that SRX/DRX plus attachment changes alone cannot explain mavacamten.
3. `figures/sequential_error_aic.png` — show the dominant improvement after adding `k_5_0`, followed by genotype-specific evidence for later parameters.
4. `figures/best_fit_waveforms.png` — show excellent H251N agreement and the remaining Control mismatch.
5. `figures/boundary_identifiability.png` — end with the limit: mechanism class is supported, exact parameter values are not identified.

## Questions for the PI

1. Do all six force traces share the same electrical/calcium stimulus clock, or can each exported trace have an arbitrary time offset?
2. Should the apparent 145 ms acute Control delay be treated as biology or corrected by independent onset alignment?
3. Is the defensible statement—mavacamten requires reduced power-stroke capacity, while exact rates are non-identifiable—strong enough for the BPS abstract?
4. Should `k_2` be restored to the required `10*k_1` constraint for the next mechanistic analysis?
5. Should the 24-hour recovery traces be modeled next, or remain descriptive validation data?

## Recommended wording

> Acute mavacamten reduced peak force to 34.7% of baseline in Control and 33.1% in H251N. Models permitting changes only in SRX/DRX exchange and attachment kinetics failed to reproduce the acute waveforms. Allowing the forward power-stroke parameter `k_5_0` to decrease produced the dominant AIC improvement in every analysis. Exact kinetic fold changes remain practically non-identifiable, and the Control result depends on unresolved stimulus-time alignment.
