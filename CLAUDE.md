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
- Next: review fit results when 3/4/6-state HCM fits complete; compute AIC; verify M2345 cycle is dominant in best-fit (vs full M123456 loop) via population trajectories; clarify Beard rewiring; revisit k_7_0=100 vs 104 question; consider running control demos too with the new pipeline.

## Lab Meeting Notes
- Lab meeting 2026-05-07 at 2pm
- Beard collaboration: revise m4/m7 interactions → m1/m6
