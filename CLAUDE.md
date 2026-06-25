# MATMyoSim Project — CLAUDE.md

## Who I am
Freshman BME undergrad, University of Michigan, Vander Roest Lab. Computational biology role. PI is Vander Roest.

## Project Goal
Develop and validate a 6-state myosin kinetic model in MATMyoSim, compare it against 2/3/4-state models using the Akaike Information Criterion (AIC), and identify parameter changes that produce increased force in twitch simulations — to feed into Julia's multiscale heart geometry model.

## Big Picture
The lab studies SRX/DRX regulation in HCM. Julia (another lab member) is modeling how contraction timing and geometry of the heart change at the organ scale. This project bridges the two scales: find what crossbridge-level parameters drive increased force, then pass that to Julia's model.

## Specific Tasks (from lab meeting notes)

### 1. Build the 6-state model
- Modify the kinetic scheme in `code/@half_sarcomere/`
- Reference existing files:
  - `update_3state_with_SRX_and_exp_k4.m` — example of exponential k4
  - `update_4state_with_SRX_and_exp_k7.m` — 4-state starting point
- The 6-state model adds states beyond the 4-state scheme
- Key change from Beard: revise interactions so m4/m7 interact with m1/m6 instead of current components — need to update the equations accordingly

### 2. Run twitch simulations
- Use existing MATMyoSim twitch demo data as baseline
- Fit the 6-state model to twitch data
- Goal: match the twitch waveform (force vs time curve)

### 3. Compare models with AIC
- Compare 2, 3, 4, and 6-state models
- AIC penalizes extra parameters, so 6-state must fit meaningfully better to be justified
- 3 and 4-state are well established baselines

### 4. Find force-increasing parameters
- Identify which parameter changes in the 6-state model produce increased force
- Report these to Julia so she can use them as inputs to her heart geometry model

## Kinetic Schemes (from lab notes IMG_7629)

### 3-state: S ↔ D ↔ A
- SRX (S), DRX (D), Attached (A)
- Rates: k2, k3, k4, ke

### 4-state: S ↔ D → A1 → A2
- Two attached states (A1, A2)
- Exponential detachment: dA/dt = θ(t) · k_A0 · e^(-k4·t)

### 6-state: parallel pathway (mechanism TBD with PI)
- Top row: SD ↔ DD → A0
- Bottom row: ST ↔ DT → AT
- Vertical transitions: SD↔ST, DD↔DT, A0↔AT
- Effectively two parallel pathways through attached states

### Beard model state mapping (m1-m7):
- m1, m2 ↔ r2, m3
- m4 ↔ r4, m5 → m6
- m5 → m7
- Task: revise so m4/m7 interact with m1/m6 instead of current partners

## Target Waveform (from IMG_7630 — Julia's slide)
Slide title: "How do coordinated sarcomeric contractions across a cell relate to mechanical efficiency?"

The wave to match is the **oscillating force vs time twitch curve**:
- Control: regular force oscillations with sarcomere shortening
- H251N (HCM mutation): more chaotic/irregular oscillations, larger sarcomere strain swings

Key comparison metric: **Work index** — constructive vs wasted work
- HCM shows more "wasted" work (heart works harder but less efficiently)
- Force-sarcomere strain loop shows constructive (useful) vs wasted work area

**Goal:** 6-state model should reproduce the increased and dysregulated force seen in H251N vs control. Parameters that increase force in the model = what drives the HCM phenotype.

## Julia's Model Context
- Julia OOT May 15-22
- ODE multi actin/fiber model with penalty function, fibrosis
- Needs force parameters from crossbridge model as input
- Formula in notes: I = ¼(10R² + r²mL²), R=30cm, L=3

## Key Files
- `code/@half_sarcomere/update_3state_with_SRX_and_exp_k4.m`
- `code/@half_sarcomere/update_4state_with_SRX_and_exp_k7.m`
- `code/@half_sarcomere/half_sarcomere.m`
- `code/demos/twitches/twitch_1/` — twitch demo data

## Key Parameter Mapping (paper → MATMyoSim)
- k_-SRX = k_1 (SRX exit rate, dominant HCM driver)
- k_+SRX = k_2 (SRX entry rate)
- k_A = k_3 (attachment rate)
- k_0 / δ = k_4_0 / k_4_1 (detachment / load sensitivity)
- k_on, k_off, k_coop = thin filament Ca²⁺ activation

## 6-State Model Understanding
The 6-state model is an expansion of the 3-state model where each state gets a coupled partner:
- Top row: SD ↔ DD → A0 (original pathway)
- Bottom row: ST ↔ DT → AT (new coupled pathway)
- Vertical transitions: SD↔ST, DD↔DT, A0↔AT
- Uses exponential detachment: dA/dt = θ(t) · k_A0 · e^(-k4·t)
- Whether BOTH A0 and AT use exponential detachment is TBD — ask PI
- Whether coupling mechanism is titin-driven is TBD — ask PI
- New parameters = vertical transition rates (these are what AIC will penalize)

## Difference from tension-pCa work
- tension-pCa (done): steady state, optimizer-based fitting, final force values only
- Twitch (next): time domain, full force waveform dynamics, match rise/peak/fall shape
- 6-state kinetic scheme does not exist yet in codebase — must be built from scratch

## Reading Order for Kinetic Scheme Files
1. `update_3state_with_SRX_and_exp_k4.m` — direct starting template
2. `update_4state_with_SRX_and_exp_k7.m` — reference for how to add states
3. `update_beard_atp.m` — reference for vertical transition rate equations

## 6-State Model Architecture
Starting from `update_3state_with_SRX_and_exp_k4.m` and expanding.

Structure — each original state gets a coupled partner:
```
M1 (SD) ↔ M2 (DD) → M3 (A0)    <- original 3-state (top row)
 ↕             ↕            ↕         <- NEW vertical coupling rates
M4 (ST) ↔ M5 (DT) → M6 (AT)    <- NEW coupled row (bottom row)
```
- SD = SRX no-coupling, ST = SRX coupled
- DD = DRX no-coupling, DT = DRX coupled
- A0 = Attached no-coupling, AT = Attached coupled
- M3 and M6 are arrays across x-bins (crossbridge positions)
- Coupling mechanism (titin vs other) TBD with PI

What needs to be added to the code:
1. Add M4, M5, M6 state indices (like M3_indices in 4-state file)
2. Keep original r1-r4 for top row
3. Add new horizontal rates for bottom row (ST↔DT→AT)
4. Add vertical rates for titin coupling (M1↔M4, M2↔M5, M3↔M6)
5. Only AT (M6) uses exponential detachment — follow r7 equation from 4-state model
   A0 (M3) does NOT use exponential detachment — M3 transitions via r5 and r6
6. Add new flux terms J5-J10 (or similar) for new transitions
7. Update all ODEs to include new flux terms

PI ANSWERS (lab meeting 2026-05-07):
1. Control_c4 vs Control_c8_2: not sure, may be overwritten — still unresolved
2. Ca_transients2.mat: no longer needed — using protocol_1s.txt Ca transient instead
3. Parallel pathway: YES, titin-driven confirmed
4. Vertical transition rates: CONSTANT — from Ježek et al. (nihms-2138115), Table 2:
   - k_H = 18 s⁻¹ (forward: SD→ST and DD→DT, ATP hydrolysis direction)
   - k_-H = 1.8 s⁻¹ (reverse: ST→SD and DT→DD)
   - These are "fixed parameters" in the paper — same across all model variants
5. Exponential detachment: AT (M6) only — follow r7 from 4-state; A0 (M3) uses r5/r6 transitions instead
6. Beard rewiring: not answered
7. Fit order: not answered
8. Parameters for fitting: "varies" — TBD

## Filip Paper Rate Constants (Ježek et al. nihms-2138115, Table 2)
Fixed (constant across all conditions):
- k_H = 18 s⁻¹ → vertical forward rate (SD→ST, DD→DT)
- k_-H = 1.8 s⁻¹ → vertical reverse rate (ST→SD, DT→DD)
- k_R = 16 s⁻¹ → R to D_T (ATP rebinding / rigor recovery)

Optimized in paper (use as starting values for fitting):
- k_leak ≈ 26×10⁻³ s⁻¹ → ADP-Pi release from DD (attachment triggering)
- k_DT ≈ 26×10⁻³ s⁻¹ → DT→ST (DRX to SRX entry for bottom row)
- k_S ≈ 4.7×10⁻³ s⁻¹ → ST→DT (SRX exit for bottom row)

STILL NEEDED:
- Beard rewiring details
- Fit order (control first vs HCM in parallel)

Beard model role: NOT the starting point, but reference for how vertical
transition rates might be formulated mathematically.

## Progress Log
- [2026-05-06] Ran and debugged two_condition_tension_pCa fitting demo (4 bugs fixed). Demo ran successfully, curves fit well, k2 multiplier ~0.487 (condition 2 k2 is ~half of condition 1).
- [2026-05-06] Presented results to PI in lab meeting.
- [2026-05-07] Ran twitch fitting for 3-state and 4-state models. See FITTING_LOG.md for full results.
- [2026-05-07] Prepared presentation slides for lab meeting. Graphs saved as twitch_fit_comparison_light.png and twitch_fit_5param_light.png.
- [2026-05-07] Confirmed Ca_transients2.mat has two distinct columns. PI says col2=c10, col1=blue/mutant — using col1 for control (needs clarification).
- [2026-05-07] Lab meeting: confirmed 6-state is titin-driven, vertical rates are constant (get from Philip paper), only AT uses exponential detachment.
- [2026-05-08] Read Ježek et al. (nihms-2138115) Table 2. Vertical rates: k_H=18 s⁻¹ (forward), k_-H=1.8 s⁻¹ (reverse). Also k_R=16 s⁻¹, k_leak≈0.026 s⁻¹, k_DT≈0.026 s⁻¹, k_S≈0.0047 s⁻¹.
- [2026-05-08] Built update_6state_with_SRX_and_titin.m. Registered scheme in evolve_kinetics, half_sarcomere, implement_time_step, update_forces, check_new_force, move_cb_distribution, simulation. Smoke test passed: population conservation = 1.000000, M1:M4 equilibrium ratio = 10:1 (matches k_H/k_-H).
- [2026-05-08] Set up twitch_6state_control/ fitting demo (5 params: k_3, k_on, k_off, k_4_0, k_7_0). Fitting run launched — in progress.
- [2026-05-08] 6-state fit completed (Run 5, e=0.02245). Ran Run 6 floating k_H/k_-H — no improvement (e=0.0224). Ruled out Filip paper vertical rates as limiting factor.
- [2026-05-08] AIC comparison (5 params each): 3-state ΔAIC=0 (best), 6-state ΔAIC=424.9, 4-state ΔAIC=2264.4. 3-state is correct model for control twitch. Root cause: optimizer suppresses bottom row (k_7_0→27,800 s⁻¹) because control data has no features requiring titin-coupled pathway.
- [2026-05-08] Generated twitch_all_models_comparison.png — 3-panel comparison showing all models vs data. 6-state shows staircase artifact in fall phase.
- [2026-05-08] Code verification: with k_minus_H=0 (bottom row decoupled) and polynomial r4, 6-state differs from 3-state by 7% — diagnosed as the r4 functional form difference (3-state baseline uses exponential r4). Added `r4_form` toggle to `update_6state_with_SRX_and_titin.m`. With `r4_form="exp"` and k_minus_H=0, 6-state matches 3-state to ZERO force difference. Code mathematically verified.
- [2026-05-08] Re-fit 6-state with exp r4 (6 params: k_3, k_on, k_off, k_4_0, k_coop, k_7_0). Result: error 0.1413 vs 3-state's 0.1409 — essentially tied. ΔAIC = +20.2 for 6-state (penalty for extra parameter). k_7_0 still pushed to ~6600 s⁻¹ → bottom row still suppressed. Confirmed: bottom row provides no benefit on control data even with fair comparison.
- [2026-05-08] Cleaned up comments in update_6state_with_SRX_and_titin.m — concise header, removed verbose inline explanations. Fixed state label A0 → AD throughout.
- [2026-05-08] PI confirmed: AD (M3, top row) uses polynomial detachment, NOT exponential. 3-state uses exponential; 6-state uses polynomial for AD. AIC comparison mixes detachment form difference with kinetic scheme difference — need to clarify with PI whether 3-state should also be refit with polynomial for fair comparison.
- [2026-05-08] MATLAB confirmed accessible at /Applications/MATLAB_R2026a.app/bin/matlab via -batch mode (~60s startup).
- [2026-05-08 → 2026-05-11] (gap — previous Claude Code session was closed accidentally, full conversation not recoverable). Major changes done in that session, recovered via git diff and file inspection:
  - **6-state model redesigned** from parallel pathway with Filip vertical rates → **clockwise cycle with explicit power stroke**. Architecture: M1(SRXD)→M2(DRXD)→M3(AD)↔(R5/R6 power stroke)↔M4(AT)→M5(DRXT)→M6(SRXT)→M1. Code in `update_6state_with_SRX_and_titin.m`. New params: k_5_0/k_5_1 (power stroke), k_6_0/k_6_1 (reverse stroke), k_8 (M5→M4 direct attach, default 0), k_9–k_14 (transitions).
  - Added `beard_atp_revised` kinetic scheme + `twitch_beard_control` demo (Beard rewiring task — testing m4/m7 → m1/m6).
  - Set up HCM fitting demos for 3/4/6-state vs **H251N** data (not P710R — H251N is the new HCM target).
  - Committed as 36e50a2.
- [2026-05-13] Picked up where left off. Identified and fixed several issues with HCM fitting setup:
  - **Protocol fix**: `ca_protocol.txt` generated by `rebuild_all_demos.m` was broken (PI: had square-wave Ca). Switched all 6 fitting demos to `code/demos/twitches/twitch_1/protocols/protocol_1s.txt` (smooth experimental Ca, 1486 rows at dt=0.001 s, Ca onset at row 353). **Never use ca_protocol.txt** going forward.
  - **Targets rebuilt** from `Updated cell trace data.xlsx` (Downloads), 1486 rows each, baseline-subtracted, aligned to protocol_1s.txt time axis. H251N peak ~9055 N/m², Control peak ~4368 N/m². Spreadsheet col 1=Control_c48, col 2=H251N_c63.
  - **k_13 fix**: control template had `k_13 = 1` which made R13 (M5→M2) effectively a dead end. Changed to **k_13 = 100** in control template (HCM was already 100). This is critical — without it the M2345 cycle cannot close.
  - **Added k_1, k_13, k_14** to both 6-state optimization.json files. 6-state now floats 12 params: k_1, k_3, k_on, k_off, k_4_0, k_5_0, k_7_0, k_2, k_9, k_11, k_13, k_14.
  - **Active-only error window** (`code/fit/evaluate_time_fit.m`): rewrote so SSE is computed only over rows from activation onset (target>5% above min) to end. Pre-activation rows are used only to baseline-shift sim to match target's passive level. **This fixes the "two-stage curve change" problem** — previously the optimizer was wasting effort fitting the flat passive region; now it focuses entirely on the twitch shape.
  - **Bug fix in `update_json_model_file.m`**: parameter matching used `strfind` (substring), so `parameters.k_1` matched `k_10, k_11, k_12, k_13, k_14` → "found more than once" error. Changed to exact-suffix match (`endsWith(field, '.' + needle)`). Without this fix the 6-state fit crashes immediately.
  - **k_7_0 in HCM template**: changed 104 → 100 (consistency with R3/R5 starting values). Control template still 104 — flag for review.
  - **Removed stale Stop hook** from `.claude/settings.json` (referenced non-existent /Users/tcbnu/... paths).
  - Launched 3/4/6-state HCM fits. Initial 6-state evals: e dropped from 1.89 → 0.15 quickly. Fits still running in background as of session close.
- [2026-05-15] Completed HCM twitch fitting for all three models against H251N_target.txt. Final results:
  - 3-state (5p): e=0.03206, ΔAIC=+221
  - 4-state (5p): e=0.00561, ΔAIC=+20
  - 6-state (8p): e=0.00155, ΔAIC=0 (winner)
  - 6-state free params: k_1, k_on, k_off, k_7_0, k_3, k_2, k_4_0, k_coop. k_13 fixed at 5000 in template.
  - Best fit values: k_1≈3.7 s⁻¹, k_on≈4.45×10⁶ M⁻¹s⁻¹, k_off≈1 s⁻¹, k_7_0≈28 s⁻¹, k_3≈16 s⁻¹, k_2≈252 s⁻¹, k_4_0≈30 s⁻¹, k_coop≈249.
  - Progressive fitting strategy: started 3p, added k_3, then k_2+k_4_0, then k_coop. Each addition mechanistically justified.
  - k_13 fixed at 5000 (removing it from free params improved fit: e 0.00288→0.00231).
  - Cleaned fit_controller.m (removed stale particleswarm block, MaxFunEvals→5000), evaluate_time_fit.m (concise comment), update_json_model_file.m.
  - Committed as edacd1a. Pushed to fork (tomtan2007/MATMyoSim) and Julia's repo (juliasyh/MATmyosim_6state), both on 6state-model branch.
- [2026-05-15] Known caveats in HCM fit results — bring up with PI:
  - k_2≈252 s⁻¹ is implausible for SRX entry (Filip paper k_DT≈0.026 s⁻¹, ~10,000× smaller). Likely optimizer artifact.
  - k_off≈1 s⁻¹ at lower bound — cardiac troponin should be 10–100 s⁻¹. Do NOT expand lower bound further.
  - k_coop≈249 is very high (typical cardiac: single digits to low tens). May be compensating for something structural.
  - Detachment form inconsistency: 3-state uses polynomial k_4_0, 4/6-state use exponential k_7_0. AIC comparison is not fully apples-to-apples.
  - Different search bounds across models (3-state has wider k_on/k_off range than 4-state).
  - fminsearch is local — single starting point, may not be global optimum.
  - Single cell data (H251N_c63) — no validation across cells.
  - 6-state wins but AIC margin is uncertain until detachment forms are made consistent.
- Next: bring fit caveats to PI; consider constraining k_2 upper bound (max_value=2 → ≤100 s⁻¹) and rerunning; refit 3-state with polynomial detachment for fair AIC comparison; run control twitch fits with same pipeline; clarify Beard rewiring.
- [2026-06-01] Diagnosed bad May 31 fits: k_on/k_off starting points (p=0.5) placed Ca affinity at pCa 5.5, outside the experimental range (pCa 6.72→6.12). Fix: use p_on=0.75, p_off=0.02 → Kd ≈ pCa 6.48 (correct window). This produces real twitch shapes instead of linear ramps.
- [2026-06-01] Refitted 4-state control/HCM and 6-state control/HCM with corrected starting points. Results:
  - 4-state control: e=0.025 (was 0.119) — dramatic improvement, real twitch shape
  - 4-state HCM: e=0.202 (was 0.259) — still poor; architectural limitation (k_4_0=10 fixed)
  - 6-state control: e=0.021 (was 0.013) — slightly worse, different local min
  - 6-state HCM: e=0.047 (was 0.067) — improved
  - 3-state still wins AIC both conditions. ΔAIC(3s vs 6s HCM) = 908.
- [2026-06-01] Generated parameter sweep figures for all 6 models (original style: force+SRX vs param, log x-axis). Scripts: parameter_sweep_*.m, plot_all_params_spaced.m, plot_sweeps_interactive.m.
- [2026-06-02] Major repo cleanup:
  - Deleted unused kinetic schemes (2-state, 3-state basic variants, 4-state basic, old Beard)
  - Deleted unused demos (getting_started, ramps, myofibrils, pCa demos, time_domain demos)
  - Deleted unused fit functions (Nyquist, XML, sinusoidal), tools/, batch/, generate_protocols/
  - Archived logs, old figures, diagnostic scripts to archive/ dirs
  - Cleaned stale files from twitch_* dirs (ca_protocol.txt, P710R targets, smoke tests, optimization_p*.json)
  - Repo now contains only active files for 6-state HCM fitting project

- [2026-06-07] Major repo reorganization and cleanup:
  - Moved engine files from `code/@*/` → `Code/System/@*/` and `Code/System/fit/`
  - Moved fitting demos from `code/demos/fitting/` → `Code/Fitting/`
  - Consolidated shared data: `System/protocols/protocol_1s.txt`, `System/target_data/`, `System/experimental_data/`
  - Consolidated all archive/results folders into single top-level `Archive/`
  - Fixed all path references across all optimization.json, demo scripts, parameter sweep scripts, plot scripts
  - Fixed bug: `plot_all_fits.m` target path still pointed to deleted per-demo `target/` folders — fixed to `System/target_data/`
  - Fixed bug: demo scripts defaulted to `optimization.json` but file is in `sim_input/` — fixed to `sim_input/optimization.json`
  - All 33 critical file references verified with Python path checker — zero issues
  - Committed (751 files, commit 15f47e0) and pushed to juliasyh/MATmyosim_6state (6state-model branch), no Claude attribution
- [2026-06-07] Read Lewalle et al. 2024 (Biophysical Journal): "Cardiac LDA driven by force-dependent thick-filament dynamics." Key finding: total force feedback on SRX→DRX transition (K_OFF = K_OFF⁰ × (1 + k_force × F_total)) can alone account for Frank-Starling. Mechanism already implemented in 6-state model as r1 = k_1 × (1 + k_force × hs_force). k_force currently fixed at 5e-4 — could be floated as free param to test if HCM needs higher feedback gain.

- [2026-06-08] PI meeting feedback processed. Implemented the following changes to fitting pipeline:
  - **Optimization bounds**: k_coop max_value 2→1 (≤10); k_on p_value starting point → 0.9515 (=8×10⁷); k_4_0 removed from 3-state free params; k_7_0 removed from 4-state HCM and 6-state HCM free params; k_1 lower bound restored in 6-state HCM; k_off min_value unified to 1 across all models.
  - **Parameter sweep fix**: all 6 `parameter_sweep_*.m` scripts now center sweep on each param's optimal p_value (±0.25 around p_opt, clamped to [0.05, 0.95]) instead of fixed p=[0.1…0.5].
  - **Sequential ctrl→HCM fitting**: new `Code/Fitting/update_hcm_bounds_from_ctrl.py` sets each HCM parameter's search range to [ctrl_best ÷ 10, ctrl_best × 10] (±1 log unit) after ctrl fit completes. Enforces PI's ≤10× ctrl/HCM ratio constraint by construction. Shell script `/tmp/run_all_6fits.sh` updated for sequential pairs.
  - **Optimizer boundary enforcement**: added quadratic penalty in `fit_worker.m` (`1e4 × (p-1)²` above p=1, `1e4 × p²` below p=0). fminsearch is unconstrained — penalty makes cost blow up outside [0,1], keeping simplex in bounds.
  - **Bug fixes (critical)**:
    - Renamed `@run_fit_*.m` → `demo_fit_*.m` in all 6 demo folders — MATLAB couldn't find functions because filename ≠ function name.
    - Removed stale `run_batch(opt_structure)` call from `fit_worker.m` — old worktree version had a bug (`{i}` using MATLAB's imaginary unit) that crashed every fit.
    - Added `addpath(genpath(fullfile(repo_root,'Code','System')))` to all 6 demo run scripts — `.claude/worktrees/` were shadowing Code/System/fit/ functions (fit_worker, evaluate_time_fit, update_json_model_file) with old broken versions.
    - VS Code MATLAB extension: set `matlab.matlabInstallPath` in settings.json.
  - **MATLAB license issue**: macOS keychain broken after root password change. Workaround: open MATLAB GUI to re-authenticate (credentials stay in MathWorks Service Host for current session). License backup file at `~/Desktop/matlab_license_backup.mwlicx` — import via Help→Licensing→Activate Software for permanent fix.
- [2026-06-08] Fit results (penalty-bounded, sequential ctrl→HCM):
  - 4-state ctrl: e=0.014, AIC=-4090 (WINNER control)
  - 6-state ctrl: e=0.017, AIC=-3935
  - 3-state ctrl: e=0.038, AIC=-3163
  - 6-state HCM: e=0.114, AIC=-2115 (WINNER HCM)
  - 3-state HCM: e=0.143, AIC=-1891
  - 4-state HCM: e=0.368, AIC=-966 (4-state fails HCM completely)
  - **Key finding**: 6-state is the only model that fits both conditions reasonably. HCM driver: k_3 ~3× higher than control (attachment rate), thin filament params (k_on, k_off, k_5_0) essentially unchanged.
- [2026-06-08] Read Ježek et al. (nihms-2138115) Table 2 and Campbell 2018 (PIIS0006349518307707). Key comparison:
  - k_off: Campbell fixes at 100 s⁻¹ (our floor 10 s⁻¹ is 10× too low — **raise min_value to 1.7, i.e. ≥50 s⁻¹**)
  - k_on: Campbell fitted ~2×10⁷ (our template 8×10⁷ — 4× higher, but fitted values land in plausible range)
  - k_coop: Campbell fitted 5.7 (our fits find 0.1–1 — too low; ceiling of 10 is correct)
  - k_cb = 0.001 N/m, N_0 = 6.9×10¹⁶ m⁻² — exact match ✅
  - Ježek SRX/DRX rates (k_H=18, k_-H=1.8 s⁻¹) are NOT directly comparable to twitch rates — different experimental context (unloaded biochemical vs active contraction)
- [2026-06-08] Remaining action items for next session:
  - Raise k_off lower bound to 50 s⁻¹ (min_value=1.7) in all optimization.json files ✓ DONE
  - Clarify Ca transient with PI (our protocol_1s.txt: onset 0.48s, duration ~400ms — PI says may be too slow)
  - Run final fits with k_off floor fix and check k_coop values (expect ~5 based on Campbell)
  - Commit all code changes to git
- [2026-06-08] Batch optimization.json / sweep script fixes (this session):
  - **Sweep clipping fixed** (all 6 parameter_sweep_*.m): was clipping to [0.05, 0.95], now [0, 1.0]. Bug: k_1 and k_on in 3-state ctrl had p_opt=1.0 → sweep [0.75,0.95] missed optimal point.
  - **k_off floor** → 50 s⁻¹ (min_value=1.7): applied to all 6 optimization.json. Previous fits: 4-state ctrl k_off=10.3, 4-state HCM=10, 6-state ctrl=10 (all were at old floor).
  - **k_coop max** → 0.85 (cap ≈7 s⁻¹): applied to all 6 optimization.json. Previous: 4-state ctrl/HCM hitting ceiling of 10; 6-state ctrl=7.6; 6-state HCM=8.0.
  - **k_on starting point** → p_value=0.5 (=10^7 M⁻¹s⁻¹): was 0.9515 (near upper boundary) in 3-state ctrl, 4-state ctrl, 6-state ctrl.
  - **k_7_0 removed from 4-state ctrl free params**: fixed at template value 104 s⁻¹. Reduces free params from 7→6, reduces AIC penalty. User wants to keep measured paper values for detachment rates.
  - **k_7_0 fixed for 6-state ctrl and HCM**: removed from free params; templates set to 16 s⁻¹ from Ježek et al. Table 2 (k_R = 16 s⁻¹, R→D_T transition = M4(AT)→M5(DRXT)). Old values: ctrl 104, HCM 438.
  - **Pending**: After current 6-state ctrl fit (PID 83259) completes, re-run update_hcm_bounds_from_ctrl.py → then re-run all 6 fits.

- [2026-06-10] Session work: passive baseline fix, sweep redesign, repo cleanup, parameter verification.
  - **Passive force baseline fix** (`Code/Fitting/run_desktop_models.m`): old code used `mean(mf(1:pre_n))` — includes initialization ramp (muscle_force starts ~1241, ramps to ~4655 by row ~100), leaving ~300 N/m² residual. Fixed to `mean(mf(onset_idx-50:onset_idx-1))` (50 rows just before Ca onset = equilibrated flat region). Title changed to "Slow vs normal protocol".
  - **k_7_0 paper value decision**: tested Ježek 16 s⁻¹ vs Campbell 104 s⁻¹ empirically. Campbell 104 gave e=0.057 vs Ježek 16 gave e=0.083 (214 AIC units better). Fixed at 104 s⁻¹ for 4-state ctrl and 6-state ctrl/HCM. 4-state HCM model_best.json still has old value 438 — template was not updated, needs refit.
  - **Parameter sweep redesigned** (all 6 `parameter_sweep_*.m` scripts): changed from p-space linspace (clipped) to log-spaced actual values: `actual_vals = actual_best * 10.^linspace(-1, 1, 5)`. Sweeps 0.1× to 10× best-fit in 5 equal log steps regardless of bounds. This is purely for sensitivity analysis; PI confirmed sweep both directions even if hitting bounds.
  - **Sweep titles updated**: all 6 scripts now use `sgtitle('N-State [Control|HCM]', ...)` format.
  - **SRX=NaN fix** (3-state and 4-state sweep scripts): scripts were missing `addpath(genpath(fullfile(repo_root,'Code','System')))` — `.claude/worktrees/` was shadowing old kinetic scheme files that don't output M1 correctly. Added explicit addpath to all 4 scripts.
  - **Repo cleanup**: deleted ~20+ stale PNGs, redundant plot scripts, scratch/diagnostic files.
  - **Parameter table verified** (read directly from model_best.json):

    | Param | 3s-ctrl | 3s-HCM | 4s-ctrl | 4s-HCM | 6s-ctrl | 6s-HCM |
    |-------|---------|--------|---------|--------|---------|--------|
    | k_1 (s⁻¹) | 1.22 | 8.93 | 16.9 | 4.99 | 100⚠️ | 100⚠️ |
    | k_3 (s⁻¹) | 27.7 | 216 | 10.3 | 50.5 | 67.4 | 148 |
    | k_on (M⁻¹s⁻¹) | 1.67e7 | 2.30e6 | 3.95e7 | 1.99e7 | 1.56e7 | 4.66e6 |
    | k_off (s⁻¹) | 97.8 | 64.0 | 86.4 | 50.1 | 100⚠️ | 69.0 |
    | k_5_0 (s⁻¹) | — | — | 1000⚠️ | 1000⚠️ | 476 | 4726⚠️ |
    | k_7_0 (s⁻¹) | — | — | 104🔒 | 438❌ | 104🔒 | 104🔒 |
    | k_coop | 0.1⚠️ | 0.1⚠️ | 0.1⚠️ | 0.32 | 1.38 | 0.14⚠️ |
    | k_4_0 (s⁻¹) | 100🔒 | 100🔒 | 10🔒 | 10🔒 | 10🔒 | 10🔒 |

    Note: k_2 = 10×k_1 always (hardcoded ratio in model, not independently fitted). ⚠️=at bound, ❌=known bug, 🔒=fixed.

  - **Open items carried forward**:
    - Fix 4-state HCM template k_7_0: 438 → 104, then refit
    - k_5_0 hitting ceiling (1000 or 4726 s⁻¹) in 4-state ctrl/HCM and 6-state HCM — discuss with PI
    - k_1 at ceiling (100 s⁻¹) in 6-state ctrl/HCM — discuss with PI
    - k_coop at floor (0.1) in 3/4-state ctrl/HCM and 6-state HCM — expect ~5 from Campbell
    - Ca transient timing: confirm with PI (protocol_1s.txt onset 0.48s, duration ~400ms)
    - Commit all pending code changes to git

- [2026-06-24] Final fit run for this round: floated k_7_1 (detachment strain sensitivity, per PI 6/22 request) and released k_4_0 in 6-state ctrl/HCM (8 free params total). Fixed 4-state HCM template bug (k_7_0 438→104) and refit. Results:
  - 6-state ctrl: e=0.0237, AIC=-3610.4 (winner, ΔAIC vs 4-state +741, vs 3-state +911)
  - 6-state HCM: e=0.0425, AIC=-3075.4 (winner, ΔAIC vs 3-state +250, vs 4-state +992)
  - 4-state HCM improved e=0.154→0.118 from template fix alone, but still loses decisively to 6-state and 3-state
  - k_1 ceiling issue resolved — fitted values now 6.76 (ctrl) and 11.6 (HCM) s⁻¹, well inside [0.1,100] bound, HCM>ctrl as mechanistically expected
  - k_7_1 shows large ctrl→HCM increase (0.116→0.806, ~7×) — candidate force/HCM-driving parameter alongside k_1, both directionally consistent and worth reporting to Julia pending PI review
  - New flags: k_coop pinned at ceiling (10) in 6-state HCM; k_4_0 pinned at ceiling (100) in 6-state HCM — both newly active/released params, may need wider bounds in next round
  - All 6 model fits (3/4/6-state × ctrl/HCM) now complete and consistent (same protocol_1s.txt, same active-window error metric, k_7_0 bug fixed everywhere)
- Next: bring k_coop/k_4_0 ceiling hits and the k_7_1 HCM finding to PI; consider widening k_4_0 and k_coop upper bounds; run parameter sweeps on k_7_1 and k_4_0 to visualize force sensitivity; package k_1 and k_7_1 ctrl-vs-HCM deltas as the force-increasing parameter set for Julia's model.

## Key Technical Rules (always apply these)

### MATLAB
- **Max 2 MATLAB instances** simultaneously — 3+ silently crashes (license limit; log stays at 0 bytes)
- **Wait for cross-shell MATLAB**: use `while kill -0 $PID 2>/dev/null; do sleep 10; done` — `bash wait` only works for child processes of the same shell
- **Absolute paths in sweep scripts**: `mkdir('temp/sweeps_all')` silently fails in batch mode. Always use `fileparts(mfilename('fullpath'))` to anchor paths
- **nanmean removed in R2026a**: use `mean(X, dim, 'omitnan')` instead
- **k_2 is NOT a free parameter**: `update_json_model_file.m` auto-sets k_2 = 10×k_1 after writing all params. Never add k_2 to optimization parameter list
- **plot_all_fits.m must mirror evaluate_time_fit.m**: optimizer takes LAST n rows of simulation. Use `sim_window = sim_all(end - n_tgt + 1 : end)` then align late passive region — NOT mean of first rows

### MATLAB path / worktrees shadowing
`.claude/worktrees/` sorts before `Code/` alphabetically — old engine files shadow current ones. All demo and sweep scripts must include:
```matlab
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
```
AFTER the main genpath call. Demo scripts must be named `demo_fit_*.m` (not `@run_fit_*.m`).

### Optimizer bounds
- **Use quadratic penalty in fit_worker.m** — NOT fmincon (fails on ODE sims, gradient≈0) and NOT clamping alone (simplex escapes to p=42):
  ```matlab
  boundary_penalty = 1e4 * (sum(max(0, p_vector - 1).^2) + sum(max(0, -p_vector).^2));
  ```
- **k_on/k_off starting points**: Kd = k_off/k_on must fall inside pCa 6.72→6.12. Use p_on=0.75, p_off=0.02 → Kd ≈ pCa 6.48. Default p=0.5 gives Kd≈pCa 5.5 (outside window → optimizer produces ramp not twitch)
- **HCM starting points**: always bias k_1 starting point above ctrl best-fit value — starting below ctrl puts optimizer in wrong basin (k_5_0 hits ceiling instead)

### Figure display
- View figures: `open path/to/figure.png` (opens Preview immediately)
- Keep MATLAB plots live: `open -a /Applications/MATLAB_R2026a.app --args -r "script_name"` (not -batch)
- Multiple figures: `open fig1.png fig2.png fig3.png fig4.png`
- Helper: `Code/Fitting/open_all_figures.m` opens all 4 diagnostic figures

---

## Key Papers

| Paper | Key Finding | Relevance |
|---|---|---|
| Vander Roest 2021 PNAS | P710R HCM: 12.9× k_-SRX increase; 27% SRX vs WT; SRX disruption = hypercontractility | Justifies k_1↑ as primary HCM mechanism |
| Lewalle 2024 Biophys J | Force-dependent SRX→DRX (total force, Paradigm A) explains Frank-Starling; k_force=1.48e-4 Pa⁻¹ | Validates titin-coupled 6-state; Tom's k_force=5e-4 is 3× higher |
| Jezek/Beard 2026 poster | 6-state (DT,DD,A1,A2,ST,SD); ATP/ADP/Pi explicit; RV trabeculae 2 vs 8 mM ATP: ~20 kPa difference | Beard Lab (same building) parallel work — confirms architecture |
| Pilagov 2025 JMRCM | Cy3-ATP pulse-chase: porcine myofibrils baseline 68% DRX; mavacamten→5.2% DRX; dATP→84.8% DRX | Ground truth DRX/SRX ratio; mavacamten = pharmacological inverse of HCM |

Paper files: `~/Downloads/PIIS0006349524003527.pdf` (Lewalle), `~/Downloads/2026-myofilament-poster-v5.pdf` (Jezek), `~/Downloads/s10974-025-09712-z.pdf` (Pilagov)

---

## Current Fit State (as of 2026-06-24)

Floating k_7_1 (strain sensitivity of detachment) and releasing k_4_0 (per PI 6/22 request) resolved the k_1-ceiling bottleneck. 4-state HCM k_7_0 template bug fixed (438→104) and refit. **All final fits complete — 6-state now wins AIC decisively in both conditions.**

| Model | Error | AIC | ΔAIC (within condition) | Notes |
|---|---|---|---|---|
| **Control** | | | | |
| 6-state ctrl | 0.0237 | -3610.4 | 0 (winner) | k_1 off ceiling (6.76 s⁻¹) |
| 4-state ctrl | 0.0511 | -2869.5 | +741.0 | |
| 3-state ctrl | 0.0611 | -2699.2 | +911.2 | |
| **HCM** | | | | |
| 6-state HCM | 0.0425 | -3075.4 | 0 (winner) | k_1 off ceiling (11.6 s⁻¹) |
| 3-state HCM | 0.0553 | -2825.0 | +250.4 | |
| 4-state HCM | 0.1176 | -2083.2 | +992.2 | improved from e=0.154 after k_7_0 template fix |

**6-state free params (8): k_1, k_3, k_on, k_off, k_5_0, k_coop, k_7_1, k_4_0**

Key fitted values (6-state):
| Param | ctrl | HCM | Notes |
|---|---|---|---|
| k_1 (s⁻¹) | 6.76 | 11.6 | off ceiling now; HCM > ctrl as expected (k_-SRX driver) |
| k_3 (s⁻¹) | 169 | 117 | |
| k_on (M⁻¹s⁻¹) | 1.24e7 | 8.45e7 | HCM near upper bound — flag |
| k_off (s⁻¹) | 50.1 | 50.1 | both at floor (min_value=1.7→50 s⁻¹) — flag |
| k_4_0 (s⁻¹) | 71.4 | 100 ⚠️ | HCM at ceiling — newly released param, may need wider bound |
| k_5_0 (s⁻¹) | 633 | 812 | both elevated, no hard ceiling hit |
| k_7_1 | 0.116 | 0.806 ⚠️ | ~7× higher in HCM — large load-sensitivity increase; newly floated param, drives much of the fit improvement |
| k_coop | 0.330 | 9.999 ⚠️ | HCM at ceiling (cap=10) — flag, expect ~5 per Campbell 2018 |

**Open issues / flags for PI:**
1. k_coop pinned at ceiling (10) for 6-state HCM — consider raising cap or check if this is compensating for something structural
2. k_4_0 at ceiling (100 s⁻¹) for 6-state HCM — newly released param, may need wider upper bound
3. k_7_1 jumps ~7× (0.116→0.806) ctrl→HCM — biologically this says HCM heads are far more load-sensitive in detachment; worth flagging as a candidate "force-increasing parameter" for Julia, pending PI sanity check
4. k_off at floor (50 s⁻¹) in both 6-state conditions — same value both conditions, so not HCM-discriminating
5. k_on near upper bound in 6-state HCM (8.45e7, bound max 1e8) — check headroom
6. 4-state HCM still loses badly (ΔAIC +992) — architecture genuinely cannot capture HCM phenotype even with bug fixes
7. Candidate force/HCM-driving parameters to report to Julia: k_1 (SRX exit), k_7_1 (load-sensitivity of detachment) — both show clear, consistent ctrl→HCM shifts in the same direction across fits

---

## Lab Meeting Notes

### 2026-05-07
- Lab meeting at 2pm
- Beard collaboration: revise m4/m7 interactions → m1/m6

### 2026-06-22
- **Ca transient does play a role** — PI confirmed. Align timing better: compare protocol_1s.txt Ca onset (row 353, t=0.353s) against experimental cell traces; adjust protocol file or add time offset to fitting.
- **k_4_0 upper limit** — PI asked if k_4_0 can be released. Currently fixed at 10 s⁻¹ (4/6-state). Try floating it with upper bound ~100 s⁻¹ and see if HCM fits improve.
- **k_7_0 vs k_7_1 difference** — r7 = k_7_0 × exp(−k_cb × x × k_7_1 / kT). k_7_0 = base detachment rate at zero strain (s⁻¹, currently 104). k_7_1 = dimensionless strain sensitivity — higher value = faster drop in detachment rate as x increases (load-sensitive). Positive x (post-power-stroke) → lower r7 → heads stay attached longer.
- **Force calculation** — cb_force = k_cb × 1e-9 × sum((x + x_ps) × M_attached). k_cb [N/m] × (x + x_ps) [nm] × population. x_ps=5nm shifts reference so M4 heads are at positive extension. Verify k_cb=0.001 N/m and cb_number_density=6.9×10¹⁶ m⁻² reproduce experimental peak force (~4000–9000 N/m²).
- **Floating k_7_1 → better results** — Action: add k_7_1 to optimization.json free params for 6-state models and refit.
