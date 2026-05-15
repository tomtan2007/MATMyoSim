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

---

## [2026-05-13] Major rework of fitting infrastructure (HCM = H251N target)

**Note:** A prior session between 2026-05-08 and 2026-05-13 rebuilt the 6-state
model as a clockwise cycle with an explicit power stroke (M1→M2→M3↔M4→M5→M6→M1),
added HCM demos, and switched the HCM target to H251N. Conversation lost — see
CLAUDE.md Progress Log for the recovered summary.

### Issues identified
1. All demos were using `sim_input/ca_protocol.txt`, generated by `rebuild_all_demos.m`. PI: this protocol had bad/square-wave Ca and was the source of poor results.
2. Control's 6-state template had `k_13 = 1`, making R13 (M5→M2) a dead end. The M2345 productive cycle could not close, so flux had to take the long M123456 loop, which is much slower and gave the wrong twitch shape.
3. R13 and R14 were not floated in the optimizer — they were stuck at template values.
4. `evaluate_time_fit.m` computed error over the *entire* 1486-row window, including 352 rows of flat passive baseline. Optimizer was wasting effort fitting the passive region, compromising the active-twitch fit. Visually: the simulated curve made two distinct changes (first to fit passive, then to fit active) instead of one clean alignment with the twitch.
5. `update_json_model_file.m` used `strfind` (substring match) for parameter names — so `parameters.k_1` also matched `k_10`, `k_11`, `k_12`, `k_13`, `k_14`. Crashed any fit that floated k_1.

### Fixes applied
1. **Protocol**: switched all 6 demos (`twitch_{3,4,6}state_{HCM,control}`) to `code/demos/twitches/twitch_1/protocols/protocol_1s.txt` — smooth experimental Ca, 1486 rows at dt=0.001 s, Ca onset row ~353. Path in optimization.json: `../../twitches/twitch_1/protocols/protocol_1s.txt`.
2. **Targets rebuilt** (1486 rows) from `~/Downloads/Updated cell trace data.xlsx`. Spreadsheet col 1 = Control_c48, col 2 = H251N_c63. Baseline-subtracted (mean of first 3 points), interpolated onto protocol_1s.txt time axis. HCM demos use `H251N_target.txt`, control demos use `Con_target.txt`.
3. **k_13 = 100** in `twitch_6state_control/sim_input/model_template.json` (was 1). HCM already had 100.
4. **6-state opt.json (both control and HCM)**: added k_1 (bounds log 0–3), k_13 (log 0–4), k_14 (log -1–2). Now floating 12 params: k_1, k_3, k_on, k_off, k_4_0, k_5_0, k_7_0, k_2, k_9, k_11, k_13, k_14.
5. **`evaluate_time_fit.m` rewritten**: now finds activation onset (first index where target > 5% above min), uses pre-activation rows only to compute baseline shift (sim - baseline_y + baseline_t), and computes SSE only from activation onset to end of trace.
6. **`update_json_model_file.m`**: replaced `strfind`-based match with `endsWith(field, '.' par_string) || strcmp(field, par_string)` — exact suffix match.

### Smoke test (6-state HCM with all fixes)
- Initial particleswarm evals showed errors dropping rapidly: 1.89 → 0.40 → 0.27 → 0.19 → 0.15 within ~20 evaluations.
- Active-only error means these numbers are NOT comparable to the old 0.14 number from the previous full-window fits — the normalization differs.

### Fits launched 2026-05-13
- 3-state HCM (5 params: k_3, k_on, k_off, k_4_0, k_coop) — background task `bohdr9rp9`
- 4-state HCM (5 params: k_3, k_on, k_off, k_7_0, k_coop) — background task `bkty0mf7u`
- 6-state HCM (12 params, see above) — background task `bur13vx59`
- All using protocol_1s.txt + H251N_target.txt + active-only error window.
- Results pending. Record final errors and AIC when fits complete.

### Open questions
- k_7_0 = 100 in HCM 6-state template, 104 in control 6-state template — make consistent? (User flagged for review.)
- For AIC, the 6-state's 12 params is a much bigger penalty than 5; need to see whether the bottom row actually buys >7 params worth of fit improvement on HCM data.
- M2345 cycle dominance: with k_13=100 and k_9=5, ~95% of M5 flux goes back to M2 via R13 rather than to M6 via R9. Worth verifying this empirically in best-fit by plotting population trajectories.

---

## [2026-05-14] 6-state HCM fit diagnosis and relaunch

**Root cause of stuck-at-e=0.0218 problem:**
The 6-state template had `k_1=30, k_2=0.5` → 98.4% DRX at rest, vs 4-state `k_1=1, k_2=300` → 0.3% DRX. When the 4-state best-fit params (good starting seed) were applied to the 6-state, they produced 39,589 N/m² flat — 4x target, and a completely wrong waveform shape. Optimizer saw this as catastrophically bad and retreated to the zero-force trivial solution (e=0.0218 corresponds to nearly zero force vs H251N).

**Fixes applied:**
1. **Template fix:** `k_1=1, k_2=300` in `twitch_6state_HCM/sim_input/model_template.json`. Verified by diagnostic: force now peaks at 5,860 N/m² with real twitch shape (vs 39,589 flat before).
2. **Removed k_1 from optimizer:** k_1 is fixed at 1 in the template; floating it with p=0.40 → k_1=40 s⁻¹ (11.8% DRX, still too much). Now **6 params**: k_3, k_on, k_off, k_7_0, k_coop, k_13.
3. **k_14=0 in template, removed from optimizer:** M2→M5 direct bypass doesn't exist in Filip paper. Had been pushed to max by optimizer, draining DRX directly to DRXT without force.
4. **k_13=100 in template (confirmed):** Ensures M5→M2 recycling is fast; M2345 productive cycle can close.
5. **InitialSwarmMatrix seeding (fit_controller.m):** Added `'InitialSwarmMatrix', p_vector` so optimizer starts from 4-state-equivalent seed rather than random.

**Additional stale process kills:** PIDs 84095 (old 3-state) and 84215 (old 12-param 6-state) from prior session were still running and competing. Killed.

### Run 9 — 6-state HCM (6 params) [IN PROGRESS]
- **Model:** `update_6state_with_SRX_and_titin.m` (clockwise cycle)
- **Template:** k_1=1, k_2=300, k_13=100, k_14=0, k_4_0=10, k_5_0=100
- **Parameters fit:** k_3, k_on, k_off, k_7_0, k_coop, k_13
- **Bounds:** k_3 log(0–3), k_on log(6–11), k_off log(1–5), k_7_0 log(0–4), k_coop log(-1–2), k_13 log(0–4)
- **Seed p_values:** [0.729, 0.299, 0.001, 0.658, 1.000, 0.75] (4-state best)
- **Initial eval:** e=0.1765 (NOT stuck at 0.0218 — fix confirmed working)
- **Log:** `/tmp/6state_HCM_v9.log`
- **Status:** Running (PID 17853)

### 3-state HCM Run [IN PROGRESS, started 2026-05-13 session]
- **Model:** `update_3state_with_SRX_and_exp_k4.m`
- **Parameters fit:** k_3, k_on, k_off, k_4_0, k_coop (5 params)
- **Best so far:** e=0.01187 at iteration 23
- **Log:** `/tmp/3state_HCM_v2.log`
- **Status:** Running (PID 12786)

### 4-state HCM [COMPLETE, from 2026-05-13]
- **Error:** 0.03474 (best across all runs; log: `/tmp/4state_H251N_fit.log`, 357 iterations)
- **Params:** k_3, k_on, k_off, k_7_0, k_coop (5 params)
- **Best file:** `twitch_4state_HCM/temp/best/best_4state_HCM.json`
- **Note:** The value 0.0077 referenced in earlier session summaries was a hardcoded comment in a diagnostic script, not a real fit result — corrected here.
