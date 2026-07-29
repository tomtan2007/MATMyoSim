# MATMyoSim — 6-State Myosin Kinetic Model

MATLAB implementation of a titin-coupled **6-state myosin kinetic model** built on
[MATMyoSim](https://github.com/Campbell-Muscle-Lab/MATMyoSim) (Campbell Muscle Lab).
The goal is to fit twitch force waveforms for control vs. HCM (H251N) data, compare
2/3/4/6-state models by AIC, and identify the crossbridge-level parameters that drive
increased force — feeding into a multiscale heart-geometry model.

Vander Roest Lab, University of Michigan.

## Repository layout

```
Code/
  simulation_driver.m        Top-level MyoSim run entry point
  loadjson.m                 JSON loader used by drivers
  System/                    Simulation engine (do not edit lightly)
    @half_sarcomere/         Kinetic schemes (update_*state_*.m) + forces
    @muscle/  @simulation/   Muscle/simulation classes
    fit/                     Optimizer (fit_controller, fit_worker, evaluate_time_fit, ...)
    protocols/               Ca protocols (protocol_1s.txt is canonical; _slow is PI-supplied)
    target_data/             Fit targets: Con_target.txt, H251N_target.txt
    experimental_data/       Raw experimental traces
    utilities/               jsonlab + helpers
  Fitting/                   One folder per model × condition
    twitch_<N>state_<cond>/
      demo_fit_*.m           Run the fit for this model/condition
      parameter_sweep_*.m    Sensitivity sweep (0.1x–10x best fit, log-spaced)
      sim_input/             model_template.json, optimization.json, sim_options.json
      temp/best/             Best-fit results (model_best.json, fit_results.json)  <- kept
      temp/sweeps/           Sweep figures  <- kept
    run_desktop_models.m     Run control + HCM 6-state, compare protocols
    plot_all_fits.m          Per-model fit vs. target figures
    plot_model_comparison.m  Overlay all models per condition
    update_hcm_bounds_from_ctrl.py  Sets HCM bounds to [ctrl/10, ctrl*10]
```

`temp/` holds run artifacts; only `temp/best/` and `temp/sweeps/` are tracked.
Worker/log files (`model_worker*.json`, `*.log`, `DONE.flag`, …) are git-ignored.

## Running a fit

From MATLAB, run the demo for the model/condition you want, e.g.:

```matlab
cd Code/Fitting/twitch_6state_control
demo_fit_twitch_6state          % writes temp/best/model_best.json
```

Each demo adds the engine to the path, loads `sim_input/optimization.json`, and calls
`fit_controller`. Bounds and free parameters live in `optimization.json`.

Note: `.claude/worktrees/` sorts before `Code/` and can shadow engine files — demo
scripts already `addpath(genpath(fullfile(repo_root,'Code','System')))` after the main
path add to avoid this.

## Current state

6-state (+ k_force) wins AIC in both control and HCM. Primary HCM driver is **k_1**
(SRX exit rate), ~5–10× higher than control. See `CLAUDE.md` for the full fit table,
parameter values, and open questions for the PI; `FITTING_LOG.md` for the run history.
