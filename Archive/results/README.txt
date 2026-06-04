MATMyoSim Fitting Results — PI Review Package
Tom Tan, Vander Roest Lab | 2026-05-22
==============================================

ACTION ITEM STATUS
------------------

[DONE] K2 = 10 x K1
  Enforced in code/fit/update_json_model_file.m.
  After every optimizer step, k_2 is set = 10 * k_1 automatically.
  All best-fit JSONs here have k_2 = 10 * k_1.

[DONE] series_k_linear = 100 (elastic series spring)
  All model templates use series_k_linear = 100.
  Effect: sarcomere shortens ~50 nm (4%) during twitch,
  which reduces peak force ~40% (8495 → 5056 N/m²) vs isometric.
  This is correct physics. See: diagnostics_srx_force_length.png, Panel 1+2.

[DONE] Fit to control data
  3-state wins: error=0.0253, AIC=-3552 (DELTA=0, best)
  6-state:      error=0.0374, AIC=-3170 (DELTA=+382)
  4-state:      error=0.1163, AIC=-2071 (DELTA=+1481, architecturally broken*)
  *4-state with series_k=100: power stroke + exponential detachment + compliance
   causes force to never fall. Mechanistically incompatible with control twitch.

[FOUND ISSUE] SRX too high / baseline force
  - All schemes initialize at M1=1.0 (all heads in SRX) — see half_sarcomere.m line 86/98.
  - Pre-Ca, M1 equilibrates to ~0.843 (should be ~0.91 theoretically, but pCa=6.72
    at rest is slightly activating so true equilibrium is lower).
  - Pre-activation baseline force = ~1,158 N/m² (target = ~0 N/m²).
    Source: (1) transient from M1=1.0 → equilibrium; (2) partial Ca activation at pCa=6.72.
  - During twitch: only 3% of heads attach (M3), even though 25% are in DRX.
    Bottleneck = troponin only activates to ~5%.
  - See: diagnostics_srx_force_length.png, Panels 3+4.
  - QUESTION FOR PI: should resting pCa be raised (e.g., 7.5) to suppress baseline?

[FOUND ISSUE] Ca waveform comparison
  protocol_1s.txt (used for all fitting):
    Ca onset t=0.484s, peak pCa=6.127 at t=0.522s, 1486 rows.
    Smooth synthetic Ca transient. Produces peak force ~5000 N/m² (target ~4368).
  protocol_exp_con2.txt (NOT used — included for review):
    Ca onset t=0.563s, peak pCa=6.174 at t=0.833s, 2056 rows.
    Experimental fluorescence Ca trace (noisy, slow rise).
    Produces peak force ~10,537 N/m² — 2.4x too high.
    Mismatch: if Con_target.txt came from the same experiment, this is the correct
    Ca to use. If Con_target.txt is isometric standard, protocol_1s.txt is correct.
  QUESTION FOR PI: which Ca protocol does Con_target.txt correspond to?

[FOUND ISSUE] protocol_1s_strain timing offset
  The strain protocol from Julia (protocol_1s_strain.txt) starts length changes
  at t=0.544s (60ms after Ca onset), but the experimental force peaks at t=0.768s.
  Simulation force peaks 136ms EARLIER than target when using this protocol.
  The strain also oscillates for a full second after the initial shortening.
  Row count mismatch: 1801 rows (strain) vs 1486 rows (target).
  QUESTION FOR PI: was Julia's strain data recorded simultaneously with Con_target.txt?
  If so, we need the matching force trace. If not, timing needs to be manually aligned.

[DONE] Track muscle length (ecc_mean)
  Sarcomere length output = sim_output.hs_length.
  With series_k=100: starts at 1265 nm, shortens to ~1219 nm (50 nm, 4%).
  See: diagnostics_srx_force_length.png, Panel 2.

[DONE] Does series_k_linear dampen force?
  YES — by ~40%. Mechanism: sarcomere shortens → cross-bridges compressed to
  negative x → detachment rate increases (exponential k4/k7) → fewer attached heads.
  This is correct physics, not artificial damping.


FILES IN THIS FOLDER
--------------------
best_3state_control_model.json   — best fit to Con_target.txt (3-state wins)
best_3state_HCM_model.json       — best 3-state fit to H251N
best_4state_HCM_model.json       — best 4-state fit to H251N (AIC winner for HCM)
best_6state_HCM_model.json       — best 6-state fit to H251N
protocol_1s_used_for_fitting.txt — Ca protocol used in all fits
protocol_exp_con2_NOT_used.txt   — experimental Ca trace (too slow, 2.4x force)
protocol_1s_strain_136ms_timing_offset.txt — Julia's strain protocol (needs timing fix)
diagnostics_srx_force_length.png — 4-panel diagnostic: force, length, SRX, states


KEY PARAMETER COMPARISON (Control 3-state best vs HCM 4-state best)
---------------------------------------------------------------------
Parameter        | Control 3-state | HCM 4-state  | Ratio (HCM/Con)
k_1 (SRX exit)  |  3.67 s⁻¹       |  86.0 s⁻¹   |  23x  <-- main driver
k_2 (SRX entry) |  36.7 s⁻¹       |  860 s⁻¹    |  23x  (constrained = 10*k1)
k_on             |  1.1e6 M⁻¹s⁻¹  |  5.3e7      |  48x
k_coop           |  1.35            |  37.6       |  28x
k_5_0 (power)   |  --              |  ~988 s⁻¹   |  at upper bound
series_k_linear  |  100             |  100        |  same

NOTE: k_1=86 s⁻¹ for HCM is very high. Literature suggests ~1.5-2x increase
for H251N. Optimizer may be using extreme k_1 as a mathematical workaround.
