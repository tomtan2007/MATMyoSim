# MATMyoSim meeting update — September 9, 2026

## Purpose

Use the six-state myosin model to explain Control versus H251N twitch force,
identify robust force and timing sensitivities, and provide defensible
crossbridge-level inputs for Julia's multiscale heart model. The BPS story is
the six-state model, matched model selection, and sensitivity analysis.
Mavacamten is a perturbation-based validation study, not yet the headline.

## Completed six-state twitch result

The implemented kinetic cycle is:

`SRXD -> DRXD -> AD <-> AT -> DRXT -> SRXT -> SRXD`.

It includes force-dependent SRX exit, an explicit power stroke, and
strain-dependent detachment. The current matched ten-parameter fits are:

| Condition | Normalized error | AIC | Interpretation |
| --- | ---: | ---: | --- |
| Control | 0.00517 | -5082.25 | Matches rise, peak, and relaxation well. |
| H251N | 0.00551 | -5072.65 | Reproduces the larger HCM twitch. |

The 6-state model has won AIC versus the 3- and 4-state alternatives in the
current matched comparisons. However, the 30-restart analysis found practical
non-identifiability: parameter values can differ substantially among similarly
good fits. Do not present `k_1` or `k_7_1` as a unique HCM driver. Across the
tested directions, increasing `k_5_0` is the consistent way to reproduce a
higher-force phenotype.

The underlying fit records are
`Code/Fitting/twitch_6state_control/temp/best/fit_results.json` and
`Code/Fitting/twitch_6state_HCM/temp/best/fit_results.json`. A visual fit
comparison is in `Code/Fitting/fit_comparison_figures/best_fit_overlay_6state.png`.

## Mavacamten validation study

The acute experimental effect is substantial: peak force is about 35% of
Before in Control and 33% of Before in H251N. The active analysis compares
four nested models, with four deterministic multistarts each:

| Stage | Parameters allowed to change |
| --- | --- |
| `k123` | `k_1`, `k_2`, `k_3` |
| `plus_k50` | `k_1`, `k_2`, `k_3`, `k_5_0` |
| `plus_k40` | previous parameters plus `k_4_0` |
| `plus_k73` | previous parameters plus `k_7_3` |

Completed, reproducible evidence so far:

| Group | Stage | Best normalized error | Best AIC | Readout |
| --- | --- | ---: | ---: | --- |
| Control, shared alignment | `k123` | 0.31547 | -1154.62 | Four starts converge to the same poor fit: the three-rate model is inadequate. |
| Control, shared alignment | `plus_k50` | 0.02520 | -3695.12 | Adding power-stroke capacity gives a large improvement. |
| Control, shared alignment | `plus_k40` | 0.02487 | -3706.38 | `k_4_0` gives a smaller additional improvement. |
| Control, shared alignment | `plus_k73` | 0.02487 | -3704.39 | No improvement over `plus_k40` in the completed earlier capsule. |
| H251N, shared alignment | `k123` | 0.18576 | -1505.60 | The three-rate model is inadequate. |
| H251N, shared alignment | `plus_k50` | 0.00280 | -5270.18 | Adding `k_5_0` gives a large improvement. |

The first Control `k123` stage was rerun in the fresh Windows production
capsule and independently reproduced the same best error and AIC across all
four starts. The remaining stages are still running in that capsule, so the
last five rows are preliminary until the full signed summary is generated.

## Boundaries on interpretation

- AIC may be compared only within one genotype, target, and alignment policy.
- The independently fitted `k_2/k_1` ratio is diagnostic only; it is not a
  biological mavacamten conclusion.
- The workbook has no confirmed stimulus or calcium timestamps. Control timing
  conclusions remain provisional until the PI confirms whether recordings share
  a common stimulus clock.
- Practical multistart identifiability is not structural identifiability.

## Current execution and next deliverables

`mava_seq_20260908_windows` is the active immutable 48-fit capsule: three
alignment/genotype groups, four stages, and four starts per stage. After it
finishes, its signed summarizer will produce restart, stage, waveform,
boundary, identifiability, and provenance tables plus five figures. If the
diagnostics request additional final-stage restarts, those will be run before
selecting an authoritative result.

The direct question for the PI is: **Do all six before/acute/24-hour force
traces share the same electrical or calcium-stimulus clock, or can export
offsets differ between traces?**
