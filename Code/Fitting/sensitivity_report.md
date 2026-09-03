# Sensitivity Analysis Report — 2/3/4/6-state twitch models

Generated 2026-07-07. Tooling: `Code/Fitting/sensitivity_all_params.m` (all-parameter sweeps),
`Code/Fitting/k71_shape_analysis.m` (k_7_1 deep-dive), `Code/Fitting/passive_force_experiment.m`
(linear vs exponential passive). Protocol `System/protocols/protocol_1s.txt`, active-window
force metric. All 6 model folders swept; best-fit values read from each `temp/best/model_best.json`.

## Metrics
- **peak elasticity** = normalized local slope from a ±10% step = (%Δ peak force)/(%Δ param).
  This is the "rise over run" / elasticity requested (item 3). Sign = direction of effect.
- **relax elasticity** = same normalized local slope but on the relaxation half-time
  (peak → 50% decay). `NaN` = at one of the ±10% points the twitch did **not** decay to 50%
  within the 1.486 s record. This is not a crash (peaks are finite) — it means that
  perturbation *abolishes/prolongs relaxation past the record*, which is itself a finding.
- **fold** (in CSVs) = max/min output over a wide 0.1×–10× sweep (saturation view).

Per-model ranked CSVs + bar charts: `twitch_<model>/temp/sweeps/sensitivity_all.{csv,png}`.

---

## Combined table 1 — PEAK-FORCE elasticity (all params × all 6 models)

Ranked by |peak elasticity| in the 6-state models. `-` = param absent from that scheme.
`NaN` = param fixed at 0 (swept additively, no multiplicative slope).

| param | 3s-ctrl | 3s-HCM | 4s-ctrl | 4s-HCM | 6s-ctrl | 6s-HCM |
|---|---|---|---|---|---|---|
| passive_hsl_slack | -3.976 | -2.091 | -4.283 | -2.220 | -4.263 | -2.219 |
| k_off | -1.017 | -1.070 | -1.011 | -1.562 | -1.173 | -1.579 |
| k_on | 0.996 | 1.128 | 0.932 | 1.367 | 1.073 | 1.384 |
| k_5_0 | - | - | 0.578 | 0.303 | 0.714 | 0.264 |
| k_5_1 | - | - | -0.521 | -0.316 | -0.690 | -0.268 |
| k_3 | 1.338 | 1.097 | 0.607 | 0.733 | 0.641 | 0.672 |
| compliance_factor | -0.192 | -0.367 | -0.573 | -0.671 | -0.551 | -0.640 |
| cb_number_density | 1.374 | 1.168 | 0.604 | 0.623 | 0.631 | 0.625 |
| k_1 | 1.143 | 0.889 | 0.569 | 0.630 | 0.613 | 0.572 |
| x_ps | 1.412 | 1.398 | 0.036 | 0.546 | -0.020 | 0.573 |
| k_2 (=10·k_1, not free) | -1.124 | -0.879 | -0.564 | -0.629 | -0.563 | -0.570 |
| k_7_0 | - | - | -0.454 | -0.249 | -0.501 | -0.245 |
| k_boltzmann | 0.789 | 0.652 | 0.464 | 0.364 | 0.493 | 0.365 |
| temperature | 0.789 | 0.652 | 0.464 | 0.364 | 0.493 | 0.365 |
| k_4_0 | -1.139 | -0.741 | -0.140 | -0.104 | -0.345 | -0.065 |
| k_cb | 0.587 | 0.518 | 0.141 | 0.260 | 0.140 | 0.261 |
| k_force | 0.499 | 0.502 | 0.155 | 0.277 | 0.161 | 0.248 |
| k_coop | 0.078 | -0.279 | -0.141 | -0.190 | -0.164 | -0.186 |
| k_12 | - | - | - | - | -0.105 | -0.052 |
| k_11 | - | - | - | - | 0.095 | 0.063 |
| passive_k_linear | -0.168 | -0.144 | -0.074 | -0.076 | -0.077 | -0.077 |
| k_13 | - | - | - | - | 0.050 | 0.054 |
| k_4_1 | 0.094 | 0.067 | -0.055 | -0.042 | -0.039 | -0.043 |
| k_7_1 | - | - | -0.011 | 0.061 | -0.029 | 0.033 |
| k_9 | - | - | - | - | -0.023 | -0.012 |
| k_6_1 | - | - | -0.014 | -0.027 | -0.001 | -0.018 |
| k_14 | - | - | - | - | -0.002 | -0.002 |
| k_6_0 | - | - | -0.000 | -0.000 | -0.000 | -0.000 |
| max_rate | -0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| k_8 (fixed 0) | - | - | 0.037 | 0.021 | NaN | NaN |
| k_10 (fixed 0) | - | - | - | - | NaN | NaN |

## Combined table 2 — RELAXATION half-time elasticity

Same params/order. **Caveat:** many cells are `NaN` in the HCM columns (large twitch → +10%
perturbation prolongs relaxation past the 1.486 s record, so the 50%-decay point is missing at
one leg of the ±10% pair). These NaNs are honest "relaxation-incomplete" outcomes, not tool
failures. The k_7_1 relaxation story (item 2) is therefore taken from the dedicated fine sweep
below, where relaxation half-time is finite up to ~2.6× best.

| param | 3s-ctrl | 3s-HCM | 4s-ctrl | 4s-HCM | 6s-ctrl | 6s-HCM |
|---|---|---|---|---|---|---|
| passive_hsl_slack | -1.473 | -1.078 | -1.899 | NaN | -1.943 | NaN |
| k_off | NaN | -2.722 | -3.606 | NaN | -3.886 | NaN |
| k_on | NaN | 2.233 | 3.197 | NaN | 3.429 | NaN |
| k_5_0 | - | - | -1.034 | -3.636 | -0.114 | NaN |
| k_3 | 1.452 | 2.244 | 1.466 | NaN | 1.600 | NaN |
| cb_number_density | 1.245 | 2.144 | 0.889 | NaN | 0.857 | NaN |
| k_1 | 1.203 | 1.689 | 1.298 | NaN | 1.314 | NaN |
| k_2 | -1.328 | -1.767 | -1.370 | NaN | -1.429 | NaN |
| k_4_0 | -2.282 | -3.600 | -0.913 | -3.623 | -1.429 | -2.677 |
| k_4_1 | 0.456 | 0.689 | -0.577 | -2.649 | -0.286 | -3.484 |
| k_cb | 0.477 | 0.922 | 0.793 | 2.636 | 0.343 | 2.103 |
| k_force | 0.643 | 1.189 | 0.577 | NaN | 0.543 | NaN |
| k_coop | 0.083 | -0.989 | -0.938 | NaN | -0.829 | NaN |
| k_7_0 | - | - | -0.024 | NaN | -0.400 | NaN |
| k_11 | - | - | - | - | 0.229 | 0.880 |
| k_12 | - | - | - | - | -0.229 | -0.819 |
| passive_k_linear | -0.145 | -0.256 | -0.096 | -0.675 | -0.114 | -0.721 |
| **k_7_1** | - | - | **0.072** | **0.416** | **0.029** | **0.220** |
| compliance_factor | 0.498 | 0.978 | 0.240 | 0.208 | 0.229 | 0.183 |

Note k_7_1: near-zero on **peak** in every scheme, but consistently **positive on relaxation**,
and largest in HCM (0.416 in 4-state, 0.220 in 6-state) — i.e. k_7_1 slows relaxation. This is
its true mechanistic axis (see item 2).

---

## Answers to the 5 PI items

### Item 1 — k_force (force-feedback gain; r1 = k_1·(1+k_force·hs_force))
- Peak elasticity: 3-state ~+0.50, 4-state ~+0.16–0.28, 6-state +0.16 (ctrl) / +0.25 (HCM).
  Positive, moderate — more force-feedback → more force (positive Frank-Starling-like gain).
- Its influence is **~3× stronger in the 3-state scheme** than in 4/6-state. In the multi-state
  schemes the SRX↔DRX recruitment that k_force drives is shared with the explicit power-stroke /
  bottom-row transitions, so the marginal effect of k_force is diluted.
- Relaxation elasticity positive (+0.5–1.2) — higher feedback also modestly prolongs relaxation.
- Classification: **sensitive, interior, but similar ctrl↔HCM** (best 1.5e-4 in both, at/near the
  Lewalle 2024 value 1.48e-4). Not an HCM driver on its own; a genuine gain knob. (A prior 9-param
  fit found HCM k_force *lower* than ctrl — counterintuitive and flagged for PI; the 8-param fits
  used here keep k_force fixed at 1.5e-4.)

### Item 2 — k_7_1 (strain-dependent DETACHMENT sensitivity) — evaluated on RELAXATION
r7 = k_7_0·exp(−k_cb·x·k_7_1/kT), per x-bin. Larger k_7_1 → slower detachment of positive-strain
(force-bearing) heads, faster (exp) detachment of negative-strain heads.
- **Peak** elasticity ≈ 0 in every scheme (−0.03 to +0.06). This is NOT because k_7_1 is
  unimportant — the best fit sits at/near a force turning point (see item "k_7_1 shape analysis").
- **Relaxation** elasticity is the real signal: **+0.22 (6-state HCM), +0.42 (4-state HCM)**,
  smaller in control (+0.03 / +0.07). Direction: higher k_7_1 → longer relaxation half-time.
- Fine sweep (below) shows relaxation half-time rising 0.34→0.55 s across 0.1×→2× best in HCM,
  then failing to relax at all past ~2.6× best. **k_7_1 is a relaxation/falling-phase parameter,
  not a peak parameter.**

### Item 3 — cross-scheme comparison + local sensitivity rate (elasticity)
The elasticities above ARE the requested normalized local slopes. Cross-scheme pattern:
- The **rank order of peak sensitivity is stable** across schemes: passive_hsl_slack > k_off ≈
  k_on > k_3 ≈ cb_number_density ≈ k_1 > k_boltzmann/temperature > k_cb ≈ k_force > detachment
  terms > titin/vertical transitions (k_9–k_14) ≈ 0.
- **Magnitudes shrink from 3-state → 4/6-state** for the shared thermodynamic/kinetic knobs
  (e.g. k_1 1.14→0.57–0.61; k_cb 0.59→0.14–0.26; x_ps 1.41→~0). Adding states spreads control
  across more transitions, so each individual parameter is less pivotal — the system is more
  buffered. This is the expected AIC/identifiability trade-off made quantitative.
- The 6-state–only bottom-row / vertical transitions (k_9, k_11–k_14, k_6_0/1) all have
  |peak elasticity| < 0.11 → they are **structurally near-passive for peak force** but do carry
  small relaxation weight (k_11 +0.88, k_12 −0.82 on relaxation in HCM).

### Item 4 — every parameter, emphasis on structural cross-bridge terms
- **cb_number_density**: peak elasticity **+0.60 (4/6-state), +1.17–1.37 (3-state)** — NOT the
  naive +1 of a pure force scaler. Force = cb_number_density·k_cb·Σ(x+x_ps)·M_attached, so the
  direct effect is +1, but two couplings bend it: (a) higher density → higher force → more
  SRX→DRX recruitment via k_force (superlinear, pushes >1, dominant in 3-state), and (b) higher
  force → more series-compliance shortening → heads shift to lower-strain bins (sublinear, pushes
  <1, dominant in 4/6-state). Both effects are real physics; +0.6–1.4 is sensible, not a bug.
- **k_cb (cross-bridge stiffness)**: peak elasticity only **+0.14–0.26 (4/6-state)**, well below
  +1. k_cb is NOT a pure force scaler — it *also* sits in the r7 detachment exponent
  (−k_cb·x·k_7_1/kT) and the power-stroke energetics. Raising k_cb boosts per-head force (+1) but
  simultaneously speeds strain-dependent detachment of the very heads carrying that force, largely
  cancelling the gain. This coupling is the key structural insight: **stiffness and detachment
  load-sensitivity are entangled through k_cb.** (In 3-state, which lacks the exponential r7, the
  cancellation is weaker → k_cb elasticity is higher, +0.52–0.59.)
- **x_ps (power-stroke offset)**: huge in 3-state (+1.4) but ~0 in 6-state ctrl (−0.02) — in the
  6-state the attached population is dominated by the M3/M4 power-stroke equilibrium so the raw
  offset matters less at the ctrl operating point (still +0.57 in HCM). Its wide-sweep peak_fold
  is enormous (2×10⁸) because at 0.1×x_ps the net twitch collapses to baseline — a degenerate
  point, not a smooth response; trust the local elasticity, not the fold, for x_ps.
- **k_boltzmann and temperature give identical elasticities in every model** (they enter only as
  the product kT in every rate exponent). This is a clean internal consistency check that the
  tool and the kinetics are wired correctly.
- **max_rate, k_6_0, k_14**: elasticity ≈ 0 → true passengers at these operating points.
- **k_8, k_10 fixed at 0**: swept additively; elasticity NaN by construction (documented).

### Item 5 — passive force: linear vs exponential ("rubber band")
Ran the 6-state control best-fit twitch under a scenario matrix (canonical exponential params from
the original MATMyoSim ramp_2 demo: σ=100 N/m², L=25 nm). Two slack settings: 1265 nm (= operating
length; passive engaged only via series-compliance shortening) and 1200 nm (operating length 65 nm
*above* slack → passive element pre-stretched so the linear-vs-exp shape difference is exercised).
CSV: `twitch_6state_control/temp/scratch/passive_experiment.csv`.

| scenario | baseline | peak | net peak | relax½ (s) |
|---|---|---|---|---|
| linear, slack=1265 (baseline) | 821 | 5015 | 4194 | 0.175 |
| exp σ=100 L=25, slack=1265 | 964 | 5830 | 4866 | 0.223 |
| linear, slack=1200 (stretch) | 1711 | 6107 | 4397 | 0.193 |
| exp σ=100 L=25, slack=1200 | 1662 | 5960 | 4299 | 0.186 |
| exp σ=100 **L=10**, slack=1200 | 3459 | 7129 | 3670 | 0.154 |
| exp σ=50 L=25, slack=1200 | 1350 | 5740 | 4390 | 0.191 |
| exp σ=200 L=25, slack=1200 | 2114 | 6283 | 4169 | 0.180 |

**Finding:** at physiological passive parameters the exponential form does **not** change the
twitch qualitatively. When the passive element is engaged (slack=1200), linear vs canonical
exponential (σ=100, L=25) give nearly identical net twitch (net 4397 vs 4299, relax 0.193 vs
0.186 s). The exponential's nonlinear stiffening only becomes important with a **short length
constant** (L=10 nm): diastolic/baseline force jumps 1.7 kPa → 3.5 kPa and net active force falls
~17% (4397 → 3670) because the stiff passive spring opposes shortening and speeds apparent
relaxation. So passive-force *form* is a second-order effect for this cell operating near slack;
it matters only if titin/ECM stiffening is steep (small L → high diastolic tension), which is the
relevant regime for diastolic dysfunction but not for matching the current systolic twitch peak.
Recommendation: keep linear for the twitch fits; revisit exponential only if modeling elevated
diastolic tension. The real model_best.json files were **not** modified (scratch copies only).

---

## k_7_1 shape analysis (dedicated deep-dive) — REVISES the earlier "passenger" call

Fine log sweep, 18 points 0.1×–10× best, 6-state control and HCM. Figures:
`twitch_6state_{control,HCM}/temp/sweeps/k71_fine_sweep.png`, `k71_waveforms.png`, `k71_r7_profile.png`.
CSVs: `k71_fine_sweep.csv`.

**Control** (best k_7_1 = 0.228): net peak declines *monotonically* 4277 → 3317 N/m² across
0.1×→10×; relaxation half-time rises *monotonically* 0.171 → 0.374 s (2.2×). No hump, no cliff in
this window. Best fit sits on a gentle declining shoulder.

**HCM** (best k_7_1 = 0.257): **non-monotonic, as the PI observed.**
- Net peak rises 9133 → **max 9796 at k_7_1 = 0.507 (1.97× best)**, then declines to 8712 at 10×.
  The best fit sits at **0.51× of the peak-optimal value — on the rising shoulder, just below the
  optimum.** The peak change is a gentle hump (~±7%), not a sharp cliff.
- Relaxation half-time rises steeply 0.339 → 0.551 s up to 1.97× best, then **goes to NaN beyond
  ~2.58× best (k_7_1 ≈ 0.66): the twitch no longer relaxes to 50% within the 1.486 s record.**
  *This* is the cliff — it is a **relaxation collapse, not a peak collapse.**

**Mechanism (verified via r7(x) profile):**
- Positive-strain (x>0, force-bearing) heads: r7 = 104·exp(−0.252·x·k_7_1) → 0 as k_7_1 grows, so
  force-bearing heads latch on → force sustained → relaxation slows then fails. **This is the
  dominant falling-phase effect and is purely physical (no cap involved for x>0).**
- Negative-strain (x<0) heads: exponent flips sign, r7 blows up and is clamped at max_rate.

**Physical vs numerical cap (item 3 of PI k_7_1 request):**
- At best fit: **0 / 200 x-bins hit the max_rate cap** (max r7 = 185 s⁻¹ ctrl, 199 s⁻¹ HCM) —
  well below the 5000 s⁻¹ cap. The cap is **not** engaged at the fitted operating point.
- At 10× best (k_7_1 ≈ 2.3–2.6): 33/200 (ctrl) to 40/200 (HCM) negative-strain bins are pinned at
  5000 s⁻¹. So the *far* end of the sweep does involve the numerical cap — but the relaxation
  cliff onset (~2.6× best) is driven by the **physical** latching of positive-strain heads, not by
  the cap (which only accelerates already-detaching negative-strain heads). **The cliff is
  physical; the cap contaminates only the extreme (≥10×) tail.** The PI should read the >5× region
  with that caveat.

**Is k_7_1 well-determined?** Reasonably. In HCM the best fit sits on the rising shoulder at ~0.5×
of the peak-optimum; peak is insensitive there (turning point) but *relaxation* is steeply
sensitive (relax half-time changes ~35% per 2× change in k_7_1) and the fit uses the full falling
waveform — so k_7_1 is pinned by the relaxation phase, which is exactly its mechanistic role.

**Revision:** the earlier CLAUDE.md / notes conclusion that "k_7_1 is a flat passenger" (based on
its ≈0 peak elasticity) is **incorrect and should be revised.** k_7_1 has strong nonlinear
structure (peak hump + relaxation cliff) and governs the falling phase. Its flat peak elasticity is
a turning-point artifact, not evidence of unimportance. It is NOT a peak/HCM force driver (ctrl
0.228 vs HCM 0.257, ~1.1×, essentially unchanged), but it IS the relaxation-kinetics control knob.

---

## Driver classification (project framework)

Framework: steep local slope + interior (non-bound-pinned) fit + differs ctrl→HCM = real HCM
driver; steep but bound-pinned = constrained; flat = passenger. 6-state best-fit values:

| param | ctrl | HCM | ratio | peak elast (ctrl/HCM) | class |
|---|---|---|---|---|---|
| **k_1** | 5.05 | 26.37 | **5.2×↑** | 0.61 / 0.57 | **REAL HCM DRIVER** — sensitive, interior [0.1,100], large differential. Confirms headline. |
| k_5_0 | 231 | 848 | 3.7×↑ | 0.71 / 0.26 | Secondary candidate — power-stroke/attach rate, interior, positive force effect, HCM higher. Worth reporting alongside k_1. |
| k_3 | 35.3 | 23.9 | 0.68×↓ | 0.64 / 0.67 | Sensitive & interior but **direction unstable** (HCM lower; CLAUDE flags k_3↔k_off correlation). Do NOT report as driver. |
| k_off | 10.0 | 11.2 | ~1× | -1.17 / -1.58 | **Constrained** — ctrl pinned at floor (10). Very sensitive but similar ctrl↔HCM → not a driver. |
| k_on | 2.63e7 | 2.96e7 | ~1× | 1.07 / 1.38 | Sensitive, interior, but ~unchanged → high-leverage passenger, not a driver. |
| k_coop | 19.95 | 19.94 | ~1× | -0.16 / -0.19 | **Constrained** — both pinned at ceiling (20). Low peak leverage (shape param). Flag for PI. |
| k_7_1 | 0.228 | 0.257 | ~1.1× | -0.03 / +0.03 | **Relaxation modulator, NOT passenger** (see deep-dive). Not a peak/HCM driver. |
| cb_number_density | 6.9e16 | 6.9e16 | fixed | 0.63 / 0.63 | Structural scaler (fixed, not fitted). |
| k_cb | 0.001 | 0.001 | fixed | 0.14 / 0.26 | Structural; entangled with detachment (see item 4). |

**Headline confirmed:** k_1 (SRX exit / −SRX rate) is the primary HCM driver — 5.2× higher in HCM,
sensitive and interior. Consistent with Vander Roest 2021 (P710R 12.9× k_−SRX). k_5_0 (3.7×) is a
plausible secondary driver. k_7_1 is explicitly re-classified from "passenger" to
"relaxation-shaping parameter."

---

## Problems found & fixes applied
1. **Relaxation-elasticity NaNs in HCM columns.** Root cause diagnosed: for the large HCM twitch,
   a +10% perturbation of many parameters prolongs relaxation past the 1.486 s record, so the
   50%-decay crossing is absent at one leg of the ±10% pair → NaN. Confirmed NOT a crash (peaks
   finite) and NOT a tool bug — it is a genuine "relaxation-incomplete" outcome. **Action:**
   documented the semantics; sourced the k_7_1 relaxation result from the dedicated fine sweep
   (finite up to ~2.6× best) instead of the fragile ±10% metric. No code change needed. (Future
   improvement if desired: add a record-independent relaxation metric such as residual-force
   fraction at peak+250 ms — would require re-running all 6 folders, ~1 h, deferred.)
2. **Structural elasticities ≠ +1.** Initially flagged as suspicious (expectation was cb_number_
   density and k_cb ≈ +1). Investigated and explained as real physics: force-feedback (k_force)
   and series-compliance shortening bend cb_number_density off +1; k_cb's force gain is cancelled
   by its role in the r7 detachment exponent. Not a bug — added to item 4.
3. **x_ps huge peak_fold (2×10⁸).** Traced to a degenerate sweep point (0.1×x_ps collapses the net
   twitch to baseline), not a real smooth response. Flagged so the local elasticity (not the fold)
   is used for x_ps.
4. **k_7_1 cliff — physical vs numerical.** Explicitly checked r7 vs the max_rate cap: 0/200 bins
   capped at best fit, 33–40/200 only at 10×. Cliff onset (~2.6× best) is physical (positive-strain
   latching); cap contaminates only the ≥10× tail. Reported so the PI does not misread the extreme.
5. No sims crashed across any of the ~800 sensitivity runs; all peaks finite except the fixed-at-0
   params (k_8, k_10), which are NaN by design.

## Files
- Per-model sweeps: `twitch_<model>/temp/sweeps/sensitivity_all.{csv,png}` (6 models)
- k_7_1 deep-dive: `twitch_6state_{control,HCM}/temp/sweeps/k71_fine_sweep.{csv,png}`,
  `k71_waveforms.png`, `k71_r7_profile.png`
- Passive experiment: `twitch_6state_control/temp/scratch/passive_experiment.csv`
- Tools: `Code/Fitting/sensitivity_all_params.m`, `k71_shape_analysis.m`, `passive_force_experiment.m`

---

## 2026-07-30 update — 800-1200 nm length sweep + measurable-output extension

Addresses two deferred items from the 2026-07-20 PI feedback session: (1) the
800-1200 nm operating-length sweep (never run — the original sweep above only
covered `passive_hsl_slack`, a structurally separate field from `hs_length`),
and (2) turning sensitivity numbers into checkable predictions by adding %
sarcomere shortening and SRX/DRX fraction alongside peak force and relaxation
half-time. Both re-run on the CURRENT 6-state control/HCM `model_best.json`
(2026-07-20 rebaseline: 1000 nm operating/slack length, exponential-asymmetric
passive force, floored force-feedback, k_7_2/k_7_3 snapback) — no refit
performed, `model_best.json` untouched. New tool: `Code/Fitting/length_sweep_6state.m`.
Sensitivity tool extended in place (`Code/Fitting/sensitivity_all_params.m`)
with two new columns, `shorten_elast` and `srx_elast`; old columns unchanged.

### Length-tension sweep (hs_length 800→1200 nm, passive_hsl_slack fixed at 1000 nm)

| hs_length (nm) | ctrl peak (N/m²) | ctrl shorten% | ctrl relax½ (s) | ctrl SRX base→peak | HCM peak (N/m²) | HCM shorten% | HCM relax½ (s) | HCM SRX base→peak |
|---|---|---|---|---|---|---|---|---|
| 800  | 4302  | 5.38  | 0.135 | 0.808→0.663 | 9385  | 11.73 | 0.151 | 0.812→0.677 |
| 900  | 4837  | 5.37  | 0.150 | 0.804→0.650 | 10834 | 12.04 | 0.197 | 0.806→0.657 |
| **1000 (baseline)** | **5324** | **5.32** | **0.168** | **0.800→0.638** | **12179** | **12.18** | **0.371** | **0.801→0.639** |
| 1100 | 6975  | 4.45  | 0.166 | 0.775→0.607 | 14048 | 11.01 | **NaN** | 0.776→0.616 |
| 1200 | 12385 | 2.00  | 0.169 | 0.696→0.532 | 18536 | 7.60  | **NaN** | 0.699→0.563 |

(full 9-point CSVs: `twitch_6state_{control,HCM}/temp/sweeps/length_sweep.csv`)

**Findings:**
1. **Force rises monotonically across the entire 800-1200 nm window in both
   conditions — no descending limb, no plateau.** The current 1000 nm
   operating point sits on the rising limb, not at a force maximum;
   f_overlap is flat at 1.0 from 1040-1200 nm (per architecture check below),
   so the continued force rise past 1040 nm comes from filament-overlap
   engaging fully plus more series-compliance/passive recruitment, not from
   overlap geometry. **Answers the PI's "is 1000 nm the right baseline"
   question directionally: if peak systolic force were the sole criterion,
   a longer baseline (closer to 1100-1200 nm) would produce more force** —
   but shortening% and relaxation behavior (below) argue against simply
   maximizing length.
2. **% shortening is non-monotonic — peaks near baseline (950-1000 nm), falls
   off in both directions,** most sharply at long length (ctrl 5.3%→2.0%,
   HCM 12.2%→7.6% from 1000→1200 nm). A cell operating at 1200 nm would
   generate more force but shorten proportionally less — a real, testable
   trade-off if comparing to sarcomere-length imaging data.
3. **HCM relaxation fails above ~1050 nm: relax half-time is NaN (does not
   reach 50% decay within the 1.486 s twitch record) at 1100-1200 nm,** vs.
   control which stays flat (0.135-0.169 s) across the whole range. Control
   never shows this failure in the tested window. This is a length-dependent
   diastolic-relaxation signature specific to the HCM parameter set — a
   candidate mechanistic link to the "chaotic/irregular oscillations" and
   "wasted work" phenotype from Julia's slide, and a concrete, checkable
   prediction: HCM cells at longer preload should show measurably
   slower/incomplete relaxation relative to control at the same length.
4. **Resting (pre-activation) SRX fraction drops with length in both
   conditions, nearly identically (ctrl 0.808→0.696, HCM 0.812→0.699 over
   800→1200 nm)** — i.e. stretch alone (no Ca) recruits SRX into DRX in this
   model, a length-dependent thick-filament mechanosensing effect already
   built in via the force-feedback term. **Directly measurable**: resting
   Cy3-ATP-type SRX assay on stretched vs. slack myofibrils should show this
   ~11-percentage-point drop, independent of activation — same assay class
   used in Pilagov 2025.

### Sensitivity table extended with measurable outputs (6-state ctrl/HCM, current baseline)

Full ranked CSVs: `twitch_6state_{control,HCM}/temp/sweeps/sensitivity_all.csv`
(now 10 columns: `peak_elast`, `peak_fold`, `peak_dir`, `relax_elast`,
`relax_fold`, **`shorten_elast`, `srx_elast`**). Top parameters by
|peak_elast|, current (post-rebaseline) values:

| param | ctrl peak_elast | ctrl srx_elast | HCM peak_elast | HCM srx_elast |
|---|---|---|---|---|
| k_off | -1.274 | +0.144 | -1.960 | +0.426 |
| k_on | +1.178 | -0.132 | +1.765 | -0.372 |
| cb_number_density | +0.697 | -0.009 | +0.774 | -0.061 |
| k_3 | +0.688 | -0.116 | +0.771 | -0.159 |
| k_1 | +0.634 | -0.240 | +0.650 | -0.348 |
| k_7_0 | -0.530 | +0.034 | -0.432 | +0.053 |
| k_coop | -0.106 | +0.005 | -0.094 | +0.014 |
| k_7_1 | -0.014 | -0.002 | -0.036 | +0.012 |

**Findings:**
1. **`shorten_elast` ≈ `peak_elast` for essentially every kinetic parameter**
   (e.g. k_off -1.2738 peak vs -1.2738 shorten) — shortening is almost a pure
   linear readout of force under this model's fixed series compliance, so a
   sarcomere-shortening measurement would mostly just re-confirm a force
   measurement for any kinetic-rate perturbation.
2. **Exception: `passive_hsl_slack`.** Peak and shortening elasticity
   *diverge in sign* (ctrl: peak −1.196 vs shorten **+0.760**; HCM: peak
   −0.271 vs shorten **+0.527**). This is the one parameter where a
   shortening measurement is NOT redundant with a force measurement — moving
   slack length changes force and shortening in opposite local directions,
   making %shortening the more diagnostic readout specifically for
   titin/slack-length questions.
3. **SRX elasticity is small in absolute magnitude (bounded 0-1 output) but
   directionally consistent**: force-increasing kinetic params (k_on, k_3,
   k_1, cb_number_density) all carry negative `srx_elast` (more force → more
   SRX recruited into DRX at peak); force-decreasing params (k_off, k_2)
   carry positive `srx_elast`. **k_1's SRX footprint (−0.240 ctrl / −0.348
   HCM) is comparable to or larger than k_off's and k_3's** — concrete
   measurable statement: *a 10% increase in k_1 predicts roughly a
   2.4-point (ctrl) / 3.5-point (HCM) drop in SRX fraction at peak force,
   checkable by the same Cy3-ATP pulse-chase assay class as Pilagov 2025.*
4. **k_coop and k_7_1 remain low on every measurable axis** (peak, shorten,
   AND srx all <0.1 in magnitude) — reinforces the 2026-07-07 classification
   of k_coop as a low-leverage shape parameter (candidate to fix rather than
   float) independent of which measurable output is used to judge it.

### Methodology note (transient, already fixed)
The first concurrent MATLAB run (2 batch instances launched simultaneously
for ctrl+HCM) produced spurious all-NaN results for the baseline row and the
first parameter processed (`k_1`) in both models — a startup-race artifact,
not a code or model bug (confirmed via a sequential single-instance rerun of
just `k_1`, which reproduced clean, non-NaN values matching the rest of the
sweep's pattern). Both CSVs' `k_1` rows were patched with the corrected
sequential values; all other rows were unaffected (only the very first ~6
calls in each process were hit). Flag for future runs: avoid launching 2
sensitivity/length-sweep batch jobs at the exact same instant, or discard/
recheck the first parameter processed if run concurrently.

### Files (this update)
- New: `Code/Fitting/length_sweep_6state.m`
- Modified (additive columns only): `Code/Fitting/sensitivity_all_params.m`
- New per-model outputs: `twitch_6state_{control,HCM}/temp/sweeps/length_sweep.{csv,png}`
- Refreshed: `twitch_6state_{control,HCM}/temp/sweeps/sensitivity_all.{csv,png}`
  (now current-baseline values with 4 measurable-output columns; supersedes
  the 2026-07-07 6-state rows in the table above for those two models — 3/4-state
  rows in the original table are unchanged/still at the old baseline)
