# Fitting Log

Track of all fitting runs, parameters tried, results, and observations.

---

## [2026-05-07] Twitch fitting — 3-state and 4-state control

**Target data:** Control_c8_2 force waveform
**Protocol:** 1000 equilibration steps (pCa=8.0) + 2056 Ca²⁺ transient steps (dt=0.486ms)
**Passive offset:** 490 N/m² (passive_k_linear=14, hs_length=1300, slack=1265)
**Ca²⁺ input:** Ca_transients2.mat, column 1

### Run 1 — 3-state (exp_k4), 3 parameters
- **Model:** `update_3state_with_SRX_and_exp_k4.m`
- **Parameters fit:** k_3, k_on, k_off
- **Error:** 0.0238
- **Sim peak force:** ~1250 N/m²
- **Notes:** k_off hit upper bound

### Run 2 — 4-state (exp_k7), 3 parameters
- **Model:** `update_4state_with_SRX_and_exp_k7.m`
- **Parameters fit:** k_3, k_on, k_off
- **Error:** 0.0422
- **Sim peak force:** ~1148 N/m²
- **Notes:** k_off hit upper bound

### Run 3 — 3-state (exp_k4), 5 parameters
- **Model:** `update_3state_with_SRX_and_exp_k4.m`
- **Parameters fit:** k_3, k_on, k_off, k_4_0, k_coop
- **Best p_values:** k_3=0.375, k_on=0.885, k_off=1.000, k_4_0=0.658, k_coop=0.552
- **Best actual values:** k_3=13.34, k_on=3.47e9, k_off=1000, k_4_0=430.1, k_coop=4.52
- **Error:** 0.0199
- **Notes:** k_off hit upper bound (p=1.0). k_on very high — upper bound may need widening.
- **Best fit file:** `twitch_3state_control/temp/best/best_3state_control.json`

### Run 4 — 4-state (exp_k7), 5 parameters
- **Model:** `update_4state_with_SRX_and_exp_k7.m`
- **Parameters fit:** k_3, k_on, k_off, k_7_0, k_coop
- **Best p_values:** k_3=0.519, k_on=0.724, k_off=1.000, k_7_0=0.455, k_coop=0.376
- **Best actual values:** k_3=36.0, k_on=7.87e8, k_off=1000, k_7_0=66.1, k_coop=1.35
- **Error:** 0.0417
- **Notes:** k_off hit upper bound (p=1.0). 4-state peak is shifted right relative to data.
- **Best fit file:** `twitch_4state_control/temp/best/best_4state_control.json`

### Summary
| Model | Params | Error | Notes |
|-------|--------|-------|-------|
| 3-state | 3 | 0.0238 | k_off bound |
| 4-state | 3 | 0.0422 | k_off bound |
| 3-state | 5 | 0.0199 | k_off bound |
| 4-state | 5 | 0.0417 | k_off bound |

**Key finding:** 3-state consistently outperforms 4-state. k_off hitting its upper bound in all runs — consider widening range from max=3 (1000) to max=4 (10000) in future runs.

### Output figures
- `code/demos/fitting/twitch_fit_comparison_light.png` — 3-param comparison, light mode
- `code/demos/fitting/twitch_fit_5param_light.png` — 5-param comparison, light mode
- `code/demos/fitting/twitch_fit_comparison.png` — 3-param comparison, dark mode
- `code/demos/fitting/twitch_fit_5param.png` — 5-param comparison, dark mode
- `code/demos/fitting/twitch_fit_all_models.png` — all models, dark mode

---

## [2026-05-06] tension-pCa fitting — two_condition demo

**Model:** 3-state with SRX
**Result:** k2 multiplier ~0.487 (condition 2 k2 is ~half of condition 1)
**Status:** Completed, presented to PI
**Bugs fixed:** 4 bugs in run_batch.m, summary_stats.m, fit_controller.m, draw_figure_current_fit.m

---

---

## [2026-05-08] 6-state model development and fitting setup

**Model:** `update_6state_with_SRX_and_titin.m` (new file, built from scratch)

### Architecture
```
M1 (SD) <-> M2 (DD) -> M3 (A0)     <- top row, non-titin-coupled
  |            |           |         <- vertical: k_H=18 s^-1, k_-H=1.8 s^-1
M4 (ST) <-> M5 (DT) -> M6 (AT)     <- bottom row, titin-coupled
```
- Vertical rates fixed from Jezek et al. (nihms-2138115) Table 2
- M3 (A0): polynomial detachment (k_4_0 + k_4_1*x^4), NOT exponential
- M6 (AT): exponential detachment (k_7_0 * exp(...)), follows 4-state r7 formula
- y_length = 2*no_x + 6 (vs 3-state: no_x + 4)
- Population conservation verified = 1.000000 at every timestep

### Smoke test result
- Max active force with default params: 11488 N/m^2 (unfit, expected to be high)
- Final equilibrium M1:M4 ratio = 0.89:0.09, consistent with k_H/k_-H = 18/1.8 = 10

### Files modified to register new scheme
- `evolve_kinetics.m` — added dispatch case
- `half_sarcomere.m` — added y-vector initialization
- `implement_time_step.m` — added state_pops storage
- `update_forces.m` — added M3+M6 force calculation
- `check_new_force.m` — added M3+M6 force check
- `move_cb_distribution.m` — added M3, M6 interpolation
- `simulation.m` — added M1-M6 output init and time-loop storage

### Run 5 — 6-state (titin), 5 parameters [COMPLETE]
- **Model:** `update_6state_with_SRX_and_titin.m`
- **Parameters fit:** k_3, k_on, k_off, k_4_0, k_7_0
- **Bounds:** k_3 log(0-3), k_on log(6-10), k_off log(1-4), k_4_0 log(0-4), k_7_0 log(0-4)
- **Best p_values:** k_3=0.7118, k_on=0.9890, k_off=0.9179, k_4_0=0.8334, k_7_0=1.111
- **Error:** 0.02245 (hit MaxFunEvals limit, not fully converged)
- **Notes:** k_on near upper bound again. k_7_0 = 1.11 (outside [0,1]) → 10^4.44 ≈ 27,800 s⁻¹ — optimizer killed bottom row
- **Best file:** temp/best/best_6state_control.json

### Run 6 — 6-state (titin), 7 parameters, floating k_H and k_minus_H [COMPLETE]
- **Model:** `update_6state_with_SRX_and_titin.m`
- **Parameters fit:** k_3, k_on, k_off, k_4_0, k_7_0, k_H, k_minus_H
- **Purpose:** Test whether fixed Filip paper vertical rates were limiting the fit
- **Error:** ~0.0224 (no improvement over fixed-kH run)
- **Conclusion:** Vertical rates are NOT the limiting factor — floating them made no difference
- **Best file:** temp/best/best_6state_float_kH.json

### AIC Comparison — all models, 5 params each [COMPLETE 2026-05-08]
| Model | Error (normalized) | ΔAIC | Result |
|-------|-------------------|------|--------|
| 3-state exp_k4 | 0.1409 | 0.0 | **BEST** |
| 6-state titin  | 0.1511 | +424.9 | Strong evidence against |
| 4-state exp_k7 | 0.2041 | +2264.4 | Very strong evidence against |

- Note: errors here normalized by max(active force) ≈ 310 N/m² vs fitting log which used max(total force) ≈ 800 N/m² — relative ordering is what matters
- Comparison figure: `code/demos/fitting/twitch_all_models_comparison.png`

**Caveat — original AIC was not apples-to-apples:**
6-state used polynomial r4 (`k_4_0 + k_4_1*x^4`) per PI guidance, but 3-state baseline uses exponential r4 (`k_4_0 * exp(-k_4_1*x)`). Verified via decoupling test (k_-H=0): with polynomial r4 the 6-state differs from 3-state by 7%, with exponential r4 the 6-state matches 3-state to zero force difference. Code is mathematically correct in both modes (mass conservation 1e-14, M4=M5=M6 exactly 0 when decoupled).

### Run 7 — 6-state (titin) with EXPONENTIAL r4, 6 parameters [COMPLETE 2026-05-08]
- **Model:** `update_6state_with_SRX_and_titin.m` with `r4_form="exp"` toggle (mirrors 3-state r4)
- **Parameters fit:** k_3, k_on, k_off, k_4_0, k_coop, k_7_0 (= 3-state's 5 + k_7_0 for bottom row)
- **Best p_values:** k_3=0.7395, k_on=1.0042, k_off=0.8145, k_4_0=1.0458, k_coop=0.5541, k_7_0=0.9548
- **Best actual values:** k_3≈166, k_on≈1.0e10 (above bound), k_off≈2780, k_4_0≈15,250 (above bound), k_coop≈4.59, k_7_0≈6594
- **Error:** 0.0192 (fit_worker), 0.1413 (active-normalized) — **essentially tied with 3-state's 0.1409**
- **k_7_0 = 6594 s⁻¹** → M6 detaches almost instantly → bottom row still suppressed
- **Best file:** temp/best/best_6state_control_exp.json
- **Note:** fminsearch pushed k_on and k_4_0 above their max bounds (fminsearch doesn't enforce); k_coop converged to 4.59 ≈ 3-state's 4.52

### Fair AIC Comparison — exponential r4 throughout [2026-05-08]
| Model | Params | Error | ΔAIC | Verdict |
|-------|--------|-------|------|---------|
| 3-state exp_k4    | 5 | 0.1409 | 0.0 | **BEST** |
| 6-state titin (exp r4) | 6 | 0.1413 | +20.2 | Strong evidence against |
| 6-state titin (poly r4) | 5 | 0.1511 | +424.9 | Strong evidence against |
| 4-state exp_k7    | 5 | 0.2041 | +2264.4 | Very strong evidence against |

- Comparison figure: `code/demos/fitting/twitch_all_models_comparison_fair.png`

**Key findings (now with fair comparison):**
- The 6-state with exp r4 fits the control data essentially as well as 3-state (Δerr only 0.0004) — but uses 1 extra parameter and that parameter (k_7_0) just gets pushed to ~6600 to suppress M6.
- The bottom row provides NO meaningful improvement for control twitch data; AIC penalizes the unused complexity.
- Verified mathematically: code reduces exactly to 3-state when k_-H=0 with exp r4 (zero force diff, conservation 8e-15).
- Earlier Filip-rate floating run and Ca-column tests had already ruled out those as causes.
- **Conclusion stands: 3-state is the correct model for control twitch. 6-state's bottom row should help on HCM data — that's the next test.**

---

## To Do / Future Runs
- [ ] Record 6-state Run 5 result when fit completes
- [ ] Plot 6-state vs 3-state vs 4-state comparison figure
- [ ] Compute AIC for all models (3-state 5p, 4-state 5p, 6-state 5p)
- [ ] Widen k_off upper bound for 3-state/4-state too (try max=4) and rerun for fair AIC comparison
- [ ] Fit HCM (P710R) data once experimental data labeling is resolved with PI
