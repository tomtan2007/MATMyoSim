# MATMyoSim Project — AGENTS.md

## Who I am
Freshman BME undergrad, University of Michigan, Vander Roest Lab. Computational biology role. PI is Vander Roest (she/her).

## Project Goal
Develop and validate a 6-state myosin kinetic model in MATMyoSim, compare it against 2/3/4-state models using the Akaike Information Criterion (AIC), and identify parameter changes that produce increased force in twitch simulations — to feed into Julia's multiscale heart geometry model.

## Big Picture
The lab studies SRX/DRX regulation in HCM. Julia (another lab member) is modeling how contraction timing and geometry of the heart change at the organ scale. This project bridges the two scales: find what crossbridge-level parameters drive increased force, then pass that to Julia's model.

## Specific Tasks (from lab meeting notes)

### 1. Build the 6-state model
- Modify the kinetic scheme in `Code/System/@half_sarcomere/` (moved here in the 2026-06-07 reorg — original task notes below said `code/@half_sarcomere/`, now stale)
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
> **Historical — describes the original parallel-pathway design.** The actual 6-state model was redesigned (2026-05-08→05-11) into a clockwise cycle with an explicit power stroke: M1(SRXD)→M2(DRXD)→M3(AD)↔(power stroke)↔M4(AT)→M5(DRXT)→M6(SRXT)→M1. See `Code/System/@half_sarcomere/update_6state_with_SRX_and_titin.m` for the current implementation.

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
- `Code/System/@half_sarcomere/update_3state_with_SRX_and_exp_k4.m`
- `Code/System/@half_sarcomere/update_4state_with_SRX_and_exp_k7.m`
- `Code/System/@half_sarcomere/update_6state_with_SRX_and_titin.m`
- `Code/System/@half_sarcomere/half_sarcomere.m`
- `Code/System/protocols/protocol_1s.txt` — Ca transient / protocol used by all current fitting demos
- `Code/System/target_data/` — twitch target data (control + H251N)
- `Code/Fitting/twitch_6state_control/`, `Code/Fitting/twitch_6state_HCM/` — current fitting demo dirs

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
> **Historical — this section documents the original design/build plan.** Superseded by the clockwise-cycle-with-power-stroke redesign (2026-05-08→05-11); see note above and `Code/System/@half_sarcomere/update_6state_with_SRX_and_titin.m` for what's actually implemented.

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

## Current Fit State
> **Do not hardcode fit numbers here — this section goes stale fast (it's been rewritten by nearly every session since June).** For the actual latest results, check the memory index (`MEMORY.md`) for the most recent dated entry — as of this edit that's `refit_rebaseline_20260720` (baseline/params) and `jeremiah_duration_diagnostics_20260804` (open diagnostic thread), but check the index for anything newer. The most recent full narrative is the 2026-08-04 entry in the Progress Log below.
>
> **Known-retracted claims — do not repeat these:** "k_1 is a 5.2× (or 10.5×) HCM driver" (superseded 2026-07-20 — real ratio ~3×, redistributed across k_1/k_7_1/k_5_0, and later shown non-identifiable at 30-restart scale, memory: `identifiability_multistart_20260729`). "k_7_1 jumps ~7× ctrl→HCM" (was an unphysical-basin artifact, corrected 2026-07-14/20).

Still generally true regardless of which fit run is current:
- 6-state model wins AIC over 3-state and 4-state in both control and HCM, across every rebaseline so far.
- 6-state free params (core 8): `k_1, k_3, k_on, k_off, k_5_0, k_coop, k_7_1, k_4_0` (+ `k_7_2, k_7_3` snapback params since 2026-07-20; `k_force` optional 9th).
- `k_2` is never a free parameter — it's auto-set to `10×k_1` by `update_json_model_file.m`.

---

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
- [2026-05-08 → 2026-05-11] (gap — previous Codex session was closed accidentally, full conversation not recoverable). Major changes done in that session, recovered via git diff and file inspection:
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
  - Committed (751 files, commit 15f47e0) and pushed to juliasyh/MATmyosim_6state (6state-model branch), no Codex attribution
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
  - **Pending**: after the current 6-state ctrl fit completes, re-run update_hcm_bounds_from_ctrl.py → then re-run all 6 fits.

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

- [2026-06-25 to 2026-06-28] Major bound-widening + basin-correction campaign.
  - **Bound widening (2026-06-25):** widened 4 bounds simultaneously — k_off floor 50→10 s⁻¹, k_coop ceiling 10→20, k_4_0 ceiling 100→316 s⁻¹, k_on ceiling 1e8→2e8. Major AIC improvement: 6-state ctrl -3610→-4449, HCM -3075→-4002. k_4_0 and k_on resolved (interior, not pinned): k_4_0 settled ~95 s⁻¹ (HCM)/~8 s⁻¹ (ctrl); k_on moved to a *lower* interior value (4e7) once given room past the old ceiling — both **keepers**.
  - **k_off/k_coop diagnostics:** lowering k_off floor further to 1 s⁻¹ found ctrl at an interior 13.4 s⁻¹ (a genuine plateau, not an artifact) with HCM still near 10 s⁻¹ — kept floor=1. k_coop keeps climbing at the ceiling in HCM (not plateauing): capping at ~10 costs ~0 AIC in ctrl but **+265 AIC in HCM**; Campbell 2018's ~5.7 is physiologically plausible but the optimizer wants >20 — **flagged for PI, ceiling kept at 20 pending discussion.**
  - **Ca timing "129ms lag" ruled out:** confirmed measurement artifact — real Ca→force lag is 26–36ms (physiological). Diagnostic shift test (protocol shifted 129 rows earlier) made AIC catastrophically worse (-4449→-1593). `protocol_1s.txt` is correct as-is.
  - **Unphysical basin fix (6/26-27):** HCM fit with k_off floor=1 found a degenerate solution (k_on at floor, k_off≈3, k_1 at lower bound) — good AIC, physically meaningless. Fixed by raising HCM-specific floors (k_off min→10 s⁻¹, k_on min→2e7) and biasing the k_1 starting point above ctrl's best-fit value. Found the correct physical basin.
  - **k_force exploration:** first attempt floated k_force with no extra floors — found AIC -5084 (ΔAIC -635) but via an unphysical basin (k_3≈1, k_off≈3, k_force 14× above Lewalle) where force-feedback was substituting for Ca activation rather than supplementing it. Fixed by adding physiological floors on k_3, k_4_0, k_off before floating k_force; **full refit (6/27) with those floors in place gave a real ~190 AIC improvement in both conditions** — k_force kept as a 9th free param going forward.
  - **CORRECTION — k_7_1 is NOT a HCM driver:** the prior session (commit 27255de) reported k_7_1 jumping ~7× ctrl→HCM (0.116→0.806) as a candidate driver — this was an artifact of the unphysical k_off basin above. With proper physiological constraints: ctrl k_7_1=0.228, HCM k_7_1=0.257 — essentially identical. **Do not report k_7_1 to Julia as an HCM driver.**
  - **New tool:** `Code/Fitting/plot_model_comparison.m` — overlay plot of all 3 models per condition, saves to `fit_comparison_figures/fits_overlay_{control,HCM}.png`, legend shows error values.

- [2026-07-07] Full sensitivity analysis of all 6 twitch models — addressed 5 PI items. New tools (UNTRACKED in `Code/Fitting/`): `sensitivity_all_params.m`, `k71_shape_analysis.m`, `passive_force_experiment.m`, writeup `sensitivity_report.md`. Metric = normalized local elasticity from ±10% step = (%Δforce)/(%Δparam) (the "rise over run" the PI asked for). Real `model_best.json` files NOT modified (passive experiment used scratch copies). Full writeup with all tables in `Code/Fitting/sensitivity_report.md`.
  - **Item 1 (k_force):** peak elasticity +0.50 (3-state) → +0.16 ctrl / +0.25 HCM (6-state), ~3× weaker in multi-state schemes. Gain knob, NOT an HCM driver (best ~1.5e-4 both conditions, at Lewalle 1.48e-4).
  - **Item 2 (k_7_1) — RECLASSIFIED:** peak elasticity ≈0 is a turning-point artifact, not unimportance. Real axis = relaxation (+0.22 6s-HCM, +0.42 4s-HCM). HCM fine sweep: net peak non-monotonic (hump max ~1.97× best); relaxation half-time 0.34→0.55 s then collapses past ~2.6× best. Cliff is PHYSICAL (positive-strain heads latch, r7→0), NOT the max_rate cap (0/200 bins capped at best fit; only 33–40/200 at 10×). **k_7_1 = falling-phase / relaxation control knob, NOT a peak or HCM force driver** (ctrl 0.228 vs HCM 0.257). Supersedes the earlier "flat passenger" label.
  - **Item 3 (cross-scheme + local rate):** rank order stable across schemes (passive_hsl_slack > k_off ≈ k_on > k_3 ≈ cb_number_density ≈ k_1 > detachment terms > titin/vertical ≈ 0); magnitudes shrink 3-state → 6-state (k_1 1.14→0.57) — adding states buffers each parameter (identifiability/AIC tradeoff quantified).
  - **Item 4 (cross-bridge terms):** cb_number_density peak elasticity +0.60 (4/6-state), NOT naive +1 — force-feedback pushes >1, series-compliance shortening pulls <1. k_cb (stiffness) only +0.14–0.26 because it also sits in the r7 detachment exponent → per-head force gain cancelled by faster strain-dependent detachment. Key insight: stiffness and detachment load-sensitivity entangled through k_cb. Consistency check: k_boltzmann ≡ temperature elasticity everywhere (only product kT enters).
  - **Item 5 (linear vs exponential passive, "rubber band"):** at physiological params exponential does NOT change twitch qualitatively; linear ≈ exp(σ=100, L=25) net twitch. Only short length constant L=10 nm matters (diastolic 1.7→3.5 kPa, net active −17%). Recommendation: keep linear for twitch fits; revisit exponential only for elevated diastolic tension (diastolic dysfunction regime).

- [2026-07-14] Length-shortening protocol investigation — diagnosed and fixed the "negative force" bug PI flagged, plus found/fixed an unrelated pipeline break.
  - **Protocol audit**: checked every protocol file in `Code/System/protocols/` and `~/Downloads/`. Only `protocol_1s_strain.txt` has a real length trajectory (`dhsl` ranges -0.485 to +0.284 nm/step, 968 unique values). `protocol_1s_slow.txt` and `protocol_exp_con2.txt` both have flat/zero `dhsl` despite plausible-looking names — NOT length protocols. `protocol_1s_strain.txt` duration is **1.8 s** (not 1 s despite the filename) — matches PI's "longer than 1 second" comment. Copied into repo at `Code/System/protocols/protocol_1s_strain.txt` (uncommitted).
  - **Root cause of negative force**: `Code/System/@half_sarcomere/return_passive_force.m` computed the passive (titin) spring symmetrically — resisting compression as hard as extension. Verified empirically: running the 6-state control best-fit model through `protocol_1s_strain.txt` gave force down to **-831 N/m²** (240/1800 rows negative) as hs_length shortened below `passive_hsl_slack` (1265 nm). Real titin only pulls in extension; it should contribute ~0 force below slack, not push back.
  - **Fix implemented**: added two new passive-force modes to `return_passive_force.m`: `linear_asymmetric` and `exponential_asymmetric` — identical to existing formulas above slack, return 0 below slack. Original `linear`/`exponential` modes untouched (no existing fits affected by the code change alone). Verified fix eliminates all negative force on the strain protocol for both control and HCM.
  - **Major discovery**: on the actual twitch-fitting protocol (`protocol_1s.txt`), hs_length is **below slack length for 100% of every row** in both control and HCM sims — the passive spring's wrong-sign behavior has been active in every twitch fit run so far, not just an edge case.
  - **Separate, pre-existing pipeline bug found and fixed**: `Code/System/fit/evaluate_single_trial.m` was never carried over during the 2026-06-07 repo reorg — `fit_worker.m` called a nonexistent function. **This means no refit has been runnable on this branch since 2026-06-07**, so all "current" fit results in this log predating that fix could not have been re-verified since. Recovered last version from git history (`code/fit/evaluate_single_trial.m` @ commit b93ac60), adapted signature to match current `fit_worker.m` calling convention (`options_file_string` → `simulation_driver`'s `options_json_file_string`; added `y_attempt` output via `evaluate_time_fit`). Saved to `Code/System/fit/evaluate_single_trial.m` (untracked, needs to be staged with the rest of `Code/System/fit/` which is itself still uncommitted from the reorg).
  - **Refit results testing the asymmetric fix** (scratch copies only — `twitch_6state_control_asym/` and `twitch_6state_HCM_asym/`, canonical `temp/best/model_best.json` in the real `twitch_6state_control/` and `twitch_6state_HCM/` dirs untouched):
    | | old `linear` | new `linear_asymmetric` |
    |---|---|---|
    | Control error / AIC | 0.0052 / -5081 | **0.0041 / -5312** (clear win) |
    | HCM error / AIC | 0.0059 / -5015 | 0.0147 / -4118 (still worse, after fixing a boundary-pinning issue) |
  - **Control: genuine improvement.** HCM: initially got a much worse result (0.0289, AIC -3452) because `k_1` and `k_7_1` were pinned exactly at their optimization.json floor bounds (`k_1` floor=10 s⁻¹ inherited from old-model calibration, no longer valid once control's new best-fit `k_1` dropped to 4.66). Widened both floors (`k_1` min_value 0.999978→-1, `k_7_1` min_value -1→-2 in both ctrl/HCM `_asym` optimization.json files) and reran — HCM improved to 0.0147/-4118 but is still ~2.5× worse error than old linear mode.
  - **Critical flag for PI, supersedes prior HCM-driver narrative**: with the corrected (asymmetric) passive force, HCM `k_1` (4.93) is barely different from control `k_1` (4.66) — ratio **~1.06×**, not the previously reported 5.2×. This calls into question whether `k_1` was ever the real HCM driver, or whether the old fits were using the passive-force bug as a compensating mechanism. **Do not report the 5.2× k_1 finding to Julia without PI review of this.** Also `k_7_1` keeps landing exactly on whatever floor is set (0.1, then 0.01) across all three HCM reruns — may be a genuine physical edge optimum (zero strain-dependence of detachment) or a sign of an unresolved fitting issue; needs multiple random restarts to disambiguate, not just further bound-widening.
  - **State left at end of session**: `return_passive_force.m` change and `evaluate_single_trial.m` restoration are real code fixes worth committing regardless of the fit-quality question. The `_asym` scratch refits should NOT replace canonical `model_best.json` files yet — HCM result is unresolved. `protocol_1s_strain.txt` copied into repo but uncommitted.
  - Next: bring the k_1-ratio-collapse finding to PI before any further HCM fitting; if PI wants to proceed, run multiple random-restart fits for HCM under `linear_asymmetric` (single fminsearch run is not reliable given the boundary-pinning history); decide whether to commit `Code/System/fit/` (including restored `evaluate_single_trial.m`), `return_passive_force.m`, and `protocol_1s_strain.txt`; consider whether 3/4-state models also need the asymmetric passive fix for a fair AIC comparison.

- [2026-07-20] Processed PI dictated feedback (k_7_0123 shape, passive force below slack, slack length, negative force → head opening, L=25, sarcomere length range 800–1200 nm, sensitivity→measurable). Comprehended items, then implemented everything except Jeremiah validation-dataset (external, not in repo). Changes + full refit + k_1 rerun + multistart. **All UNCOMMITTED. See memory [[refit-rebaseline-20260720]] for full detail.**
  - **4 code/config changes applied:**
    1. **hs_force floored at 0** in r1 force-feedback of `update_3state/4state/6state_*.m`: `k_1*(1+k_force*max([0 hs_force]))` — matches `update_beard_atp_revised.m`. (Answers PI "does negative force trigger head opening" — now it only throttles r1, can't drive it negative.)
    2. **Re-baselined length** `hs_length` & `passive_hsl_slack` 1265→**1000 nm** in all 6 `model_template.json` (PI wants operating ~1000, sweep [800,1200]). f_overlap valid (~0.67–1.0) across range. User chose "re-baseline to 1000 + sweep literally" over keeping 1265.
    3. **`passive_force_mode` → `exponential_asymmetric`** + `passive_sigma=100`, `passive_L=25` in all 6 templates. Titin engages only in extension (pf=0 below slack). Real fix of the negative-passive-force sign bug. (Answers PI "linear gives restoring force below slack, should approach zero"; L=25 per PI + sensitivity_report.)
    4. **`k_7_2`=2 (steepness) / `k_7_3`=9 (threshold nm) snapback** added to 4-/6-state templates + free optimizer params. r7 snapback logic already present via `isfield(k_7_2)` guard. (Answers PI "k_7 parabola down then sudden spike/snapback".) **This alone fixed 4-state HCM: e 0.368→0.030.**
  - **Full refit, all 6 models (new baseline), 6-state wins both:**
    | Model | ctrl e / AIC | HCM e / AIC |
    |---|---|---|
    | 3-state | 0.0270 / -3488 | 0.0437 / -3055 |
    | 4-state | 0.0088 / -4567 | 0.0304 / -3404 |
    | **6-state** | **0.0052 / -5082** | **0.0055 / -5073** |
  - **k_1 ceiling rerun — 9.5× was a PINNING ARTIFACT:** first 6s-HCM fit had k_1 pinned at ceiling (53.4, ceiling=56=10×ctrl), e=0.0072. Widened ceiling→100 s⁻¹, reran: **better** basin (e=0.0055, AIC +256) with **k_1=16.95 interior (~3× ctrl), not 9.5×.** In the better basin the increase redistributes: k_1~3×, k_7_1 0.10→0.62 (~6×), k_5_0 240→1143 (~5×).
  - **Multi-start (6 restarts, killed at r4; r1-3 done) — DECISIVE: 6-state HCM is NOT identifiable.** k_1 ranges 3.1→17 across starts; k_3 22→199; k_4_0 5→121; k_off 10→85. r3 error 0.0133 WORSE than 0.0055 best → restarts land in inferior minima. **Cannot report any single crossbridge param as "the HCM driver" from this setup — over-parameterized/poorly identifiable.** Strong concrete case for multi-start/Great Lakes + reducing free params / adding constraints.
  - **Great Lakes discussion:** won't speed a single serial fminsearch fit; real win = many concurrent runs (bypasses local 2-MATLAB-license wall) for multi-start global opt + parameter sweeps. Worth it once workflow scales to hundreds of runs (multi-start HCM array job is the natural first project). Check if PI/Julia already have a GL allocation.
  - **Memory updated:** new `refit_rebaseline_20260720.md`; old `project_pipeline_state.md` k_1=5.2× claim marked SUPERSEDED; MEMORY.md index updated.
  - Next session: (1) harden `multistart_6state_HCM.m` to write CSV incrementally (kill-safe) + run 12–20 restarts ranked by error; (2) task #7 length sweep 800–1200 nm (deferred, not started); (3) decide commits (all reorg + fixes still uncommitted since 27255de/6-07 reorg); (4) bring identifiability finding to PI — it changes the whole "find the HCM-driving parameter" deliverable to Julia.

- [2026-07-30] Completed the two still-deferred 2026-07-20 PI feedback items: the 800–1200 nm operating-length sweep and turning sensitivity numbers into measurable predictions (SRX/DRX%, %shortening added alongside force/relaxation). Characterization only — no refit, `model_best.json` untouched. New tool `Code/Fitting/length_sweep_6state.m`; `sensitivity_all_params.m` extended in place with `shorten_elast`/`srx_elast` columns (additive, old columns unchanged). Full writeup in `Code/Fitting/sensitivity_report.md` ("2026-07-30 update" section).
  - **Length-tension (hs_length 800→1200 nm, slack fixed at 1000 nm):** force rises monotonically across the whole range in both conditions — 1000 nm baseline sits on the rising limb, not at a force max. %shortening peaks near baseline (950-1000 nm) and falls off both directions. **HCM relaxation fails above ~1050 nm** (doesn't reach 50%-decay within the 1.486 s record) while control stays flat (0.135-0.169 s) across the full range — a length-dependent diastolic-relaxation signature specific to HCM, a candidate mechanistic link to Julia's "chaotic oscillations/wasted work" phenotype. Resting (pre-Ca) SRX fraction drops ~11 points from 800→1200 nm in both conditions — length alone recruits SRX→DRX via the existing force-feedback term, a directly testable prediction (Cy3-ATP-type assay, stretched vs. slack).
  - **Measurable-output sensitivity table (6-state ctrl/HCM, current 1000 nm baseline):** `shorten_elast` ≈ `peak_elast` for essentially every kinetic parameter — %shortening is almost a pure linear proxy for force here, so it's largely redundant with a force measurement. **Exception: `passive_hsl_slack`**, where peak and shorten elasticity flip sign (ctrl −1.196 vs +0.760; HCM −0.271 vs +0.527) — the one parameter where shortening is the more diagnostic readout. `srx_elast` small but directionally consistent (force-up params → SRX-down); **k_1's SRX footprint (−0.240 ctrl / −0.348 HCM) rivals k_off/k_3's** — concrete statement: a 10% k_1 increase predicts ~2.4pt (ctrl) / ~3.5pt (HCM) SRX drop at peak, checkable by the Pilagov-style assay. k_coop and k_7_1 remain low on every measurable axis (peak, shorten, AND srx all <0.1), reinforcing k_coop as a low-leverage/fix-don't-float candidate.
  - **Methodology flag:** running 2 sensitivity/length-sweep MATLAB batch jobs launched at the exact same instant caused a startup-race artifact — spurious all-NaN results for the baseline row and the first parameter processed (`k_1`) in both models. Confirmed via sequential single-instance rerun (not a code/model bug); both CSVs' `k_1` rows patched with corrected values, nothing else affected. Avoid exact-simultaneous concurrent launches for these sweep tools going forward, or recheck the first parameter if run concurrently.
  - Next: revisit the pending float/fix parameter-pruning question for the joint/ctrl/HCM optimization.json files (started 2026-07-30 earlier in session, paused for these two items) using this refreshed sensitivity data — k_coop is now supported as a fix candidate on 3 independent measurable axes, not just peak force.

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
