================================================================================
CONTROL TWITCH FITTING RESULTS — Corrected with Standardized Parameter Bounds
Generated: 2026-05-22
================================================================================

SUMMARY
-------
We refitted 3-state, 4-state, and 6-state kinetic models to the control twitch
target (Con_target.txt) using standardized parameter bounds and two key fixes:

  FIX 1: SRX equilibrium initialization
    - Previously: M1 (SRX) started at 1.0 (100% SRX) every simulation
    - Fixed: M1 now initializes at k_2/(k_1+k_2) = 90.9% (equilibrium)
    - This correctly matches the Filip paper (Jezek et al.) steady-state
    - File: code/@half_sarcomere/half_sarcomere.m

  FIX 2: Standardized parameter bounds
    - 3-state: k_on expanded from [1e6, 1e8] to [1e5, 1e8]; k_off from [10, 100] to [1, 100]
    - 4-state: k_1 max expanded from 10 to 100 (log scale: -1 to 2)
    - 6-state: k_1 max expanded from 10 to 100; k_5_0 max from 1000 to 10000

  CONSTRAINT (unchanged): k_2 = 10 × k_1 (enforced in update_json_model_file.m)
  SERIES SPRING (unchanged): series_k_linear = 100 (elastic, realistic)


AIC COMPARISON — CONTROL TWITCH
---------------------------------
Model     Params    Error       AIC      delta_AIC   Winner?
---------+--------+-----------+---------+-----------+--------
3-state       6    0.003077   -5592.5       0        YES
6-state       7    0.012802   -4209.1    +1383       No
4-state       7    0.118975   -2048.8    +3544       No

AIC formula: n*ln(e) + 2k, where n=969 active points (Ca onset to end),
e = best error (normalized SSE), k = free parameters

WINNER: 3-state model by large margin (ΔAIC > 1383 for all others)


BEST-FIT PARAMETERS
--------------------
3-state (scheme: 3state_with_SRX_and_exp_k4):
  k_1   =   5.419 s⁻¹   (SRX exit rate)
  k_2   =  54.19 s⁻¹   (SRX entry = 10×k_1)
  k_3   =   1.176        (attachment rate — thin filament activation term)
  k_4_0 =  40.98 s⁻¹   (detachment base rate)
  k_on  = 3.257e6 M⁻¹s⁻¹ (Ca association)
  k_off =   1.102 s⁻¹   *** AT LOWER BOUND (see caveats) ***
  k_coop =  27.4          (cooperativity)
  SRX at rest: k_2/(k_1+k_2) = 90.9%

4-state (scheme: 4state_with_SRX_and_exp_k7):
  k_1   =   7.398 s⁻¹
  k_2   =  73.98 s⁻¹
  k_3   =  74.18
  k_5_0 =  97.69 s⁻¹   (power stroke rate)
  k_7_0 =  61.58 s⁻¹   (exponential detachment rate)
  k_on  = 6.393e6 M⁻¹s⁻¹
  k_off =  37.01 s⁻¹
  k_coop =   2.41
  NOTE: 4-state is architecturally broken for control — power stroke plus
        exponential detachment with elastic spring means force never falls
        properly. This is why error=0.119 is so high.

6-state (scheme: 6state_with_SRX_and_titin, clockwise cycle):
  k_1   =  10.62 s⁻¹
  k_2   = 106.2  s⁻¹
  k_3   = 416.4          (very high — see caveats)
  k_5_0 = 722.5  s⁻¹   (power stroke)
  k_7_0 =  53.18 s⁻¹   (detachment)
  k_on  = 3.860e6 M⁻¹s⁻¹
  k_off =  17.38 s⁻¹
  k_coop = 100.0         *** AT UPPER BOUND (see caveats) ***


CAVEATS AND OPEN QUESTIONS FOR PI
-----------------------------------
1. 3-state k_off = 1.1 s⁻¹ is AT THE LOWER BOUND.
   Cardiac troponin k_off should be ~10-100 s⁻¹ (Phillips et al., Reed et al.).
   The optimizer wants even lower k_off. Should we constrain k_off ≥ 10?

2. 3-state k_off = 1.1 s⁻¹ is physiologically unrealistic (very slow Ca release).
   Suggest: fix k_off = 10 s⁻¹ and refit with 5 free params to get a constrained result.

3. 6-state k_coop = 100 is AT THE UPPER BOUND (optimizer wants > 100).
   Typical cardiac values: k_coop = 2-10.

4. 3-state k_coop = 27.4 is high but not at bound.
   Typical cardiac values: k_coop = 2-10. May compensate for unrealistic k_off.

5. Detachment form inconsistency:
   - 3-state uses EXPONENTIAL detachment (k_4_0 × exp(-k_4_1 × x²))
   - 4-state and 6-state use EXPONENTIAL in a different implementation (k_7_0)
   - This is not apples-to-apples for AIC comparison (different assumptions
     about force-dependence of detachment)

6. 4-state architectural issue: the power stroke plus exponential detachment
   scheme, combined with elastic series compliance, makes force persist
   indefinitely because crossbridges are always generating positive force
   and don't detach until the subsequent Ca signal. This is likely why
   4-state cannot fit control data.

7. Single optimizer (fminsearch, local): results may not be global optimum.
   Especially for 6-state with 7 free parameters.

8. SRX at rest = 90.9% (k_2=10×k_1). Filip paper uses 91% as target.
   Is this constraint correct, or should we explore other k_2/k_1 ratios?


FIGURES
-------
- control_fit_summary/control_fit_comparison.png
    Two-panel: raw force traces and baseline-subtracted comparison
    Blue=3-state, Green=4-state, Magenta=6-state, Red dashed=target

- twitch_3state_control/temp/diagnostics/series_k_dampen_force.png
    Shows effect of series_k_linear on twitch force (0 vs 100)
    series_k=0: 8497 N/m², series_k=100: 5057 N/m² (-40%), target: 4368 N/m²

- twitch_3state_control/temp/diagnostics/muscle_length_ecc_mean.png
    ecc_mean curve from protocol_1s_strain.txt vs simulated sarcomere length
    Sarcomere shortening: ~99 nm (7.8% of slack length from ecc_mean)
    Note: 15nm offset between ecc_mean and sim start (resting crossbridge force)

- srx_check/srx_all_models.png
    SRX occupancy over time for all models
    All start at 90.9% (correct after SRX init fix)


PROTOCOLS INVESTIGATED
----------------------
1. protocol_1s.txt — USED FOR FITTING
   Standard isometric twitch, smooth Ca transient, 1486 time steps, dt=0.001 s
   Ca onset at row 353 (t=0.352 s), dhsl=0 throughout

2. protocol_1s_strain.txt (from Downloads) — Julia's length-change protocol
   1801 rows, Ca onset at row 486 (t=0.484 s), includes dhsl perturbations
   Peak shortening: ~99 nm (ecc_mean), ~50 nm (sim with series_k=100)
   Issue: sim force peak arrives 136 ms EARLY vs Con_target.txt
   Status: diagnostic only, not used for fitting

3. protocol_exp_con2.txt (from Downloads)
   2056 rows, isometric, Ca onset at t=0.563 s, different Ca waveform
   Produces 2.4× too much force (10,537 vs 4,368 N/m²)
   Status: not used — likely a different experimental condition


OPEN QUESTIONS FOR PI
---------------------
Q1: Which Ca protocol was used to record Con_target.txt?
    Was it protocol_1s.txt or something else?

Q2: Was protocol_1s_strain.txt recorded simultaneously with Con_target.txt?
    The 136 ms timing offset suggests possibly not.

Q3: What condition is protocol_exp_con2.txt? It produces 2.4× more force
    than Con_target.txt with a different Ca peak shape.

Q4: Should we constrain k_off ≥ 10 s⁻¹ for physiological realism?
    Without this constraint, the 3-state optimizer finds k_off=1.1 which
    is unrealistically tight Ca binding.

Q5: For AIC comparison to be fair, should 3-state be refit with polynomial
    detachment (same as 6-state) instead of exponential?

================================================================================
Files committed to branch: 6state-model
Key files:
  code/demos/fitting/control_fit_summary/control_fit_comparison.png
  code/demos/fitting/twitch_3state_control/temp/best/fit_results.json
  code/demos/fitting/twitch_4state_control/temp/best/fit_results.json
  code/demos/fitting/twitch_6state_control/temp/best/fit_results.json
================================================================================
