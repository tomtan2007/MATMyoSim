# Mavacamten Sequential Analysis Design

## Goal

Harden the corrected MATMyoSim mavacamten workflow and run a reproducible,
nested parameter-addition analysis for Control and H251N acute mavacamten
traces. The resulting artifacts must distinguish trustworthy quantitative
outputs from historical experiments and must not assign biological meaning to
the independent fitted `k_2` values.

Creating the Wednesday slide deck is explicitly outside this implementation.
The run will nevertheless produce concise, presentation-ready figures and
tables for later use.

## Verified Context

- The source workbook tracked in the repository is
  `Code/System/experimental_data/Mava data.xlsx`.
- Corrected preprocessing uses local baseline correction, one shared alignment
  shift per genotype, and one shared force scale per genotype.
- Acute peak force is approximately 35% of Before in Control and 33% of Before
  in H251N.
- The single independent-`k_2` fits with only `k_1`, `k_2`, and `k_3` were poor
  and boundary-limited: Control error 0.31553 and H251N error 0.18166.
- Existing five-parameter fits were substantially better, but they used a
  different parameterization and are historical context rather than rows in
  the new nested AIC comparison.
- Protocol row 481 is the first row where `pCa < 6.70` and is the fit scoring
  start.
- No more than two MATLAB instances may run simultaneously.

## Alignment Uncertainty

The workbook has no electrical-stimulus or calcium-stimulus timestamps. With a
single Control alignment shift derived from the Before trace, the aligned 5%
force-rise times are 0.543 s Before, 0.688 s acute, and 0.613 s at 24 h. Thus,
the acute trace begins approximately 192 ms later than Before and 208 ms after
calcium onset.

The implementation must support two explicit policies:

1. `shared_by_genotype`: determine the shift from each genotype's Before trace
   and apply it to all three traces in that genotype. This preserves observed
   between-condition timing differences.
2. `independent_trace`: align each trace's detected contraction onset
   independently to the calcium onset. This removes possible export offsets and
   prevents inference of treatment-induced timing changes.

The production analysis will run `shared_by_genotype` for Control and H251N.
It will also run `independent_trace` as an alignment sensitivity analysis for
Control. AIC values may be compared between nested parameter stages only within
the same genotype and alignment policy; they must not be compared across
alignment policies.

Until the PI confirms whether the traces share an absolute stimulus clock,
Control parameter conclusions and treatment-related timing conclusions are
provisional. Independent-`k_2` ratios are diagnostic only and must not be given
a biological interpretation.

## Preprocessing Contract

`prepare_mava_data` will accept an explicit alignment policy and will default to
`shared_by_genotype` to preserve the corrected workflow. It will continue to:

- calculate a local baseline for every trace;
- use one force scaling factor per genotype, anchored by that genotype's Before
  trace;
- interpolate onto the canonical 1 ms protocol;
- remove the rising portion of any subsequent contraction;
- emit target and protocol files with equal finite lengths.

The diagnostic table will distinguish these quantities:

- `source_trough_time`: time of the local pre-contraction trough;
- `source_force_rise_time`: sustained 5% force-rise time in the workbook;
- `applied_time_shift`: shift selected by the alignment policy;
- `aligned_force_rise_time`: force-rise time after the shift;
- `calcium_to_force_lag`: aligned force-rise time minus calcium onset;
- local baseline value, scale factor, peak force, time-to-peak, relaxation
  half-time, FWHM, final time, and sample count.

The repository workbook, not a hard-coded Downloads path, is the default input.
Its SHA-256 hash and the protocol hash will be recorded in every production run.

## Immutable Run Capsule

Each analysis run will live under:

`Code/Fitting/mava_codex/output/runs/<run_id>/`

Creating a run with an existing identifier will fail unless resume mode is
explicitly requested. Resume mode will accept only a run whose manifest inputs
and settings match the current request. Completed result directories will never
be overwritten.

Every run capsule will contain:

- `manifest.json`: run identifier, timestamps, status, repository HEAD, hashes
  of dirty/relevant source files, MATLAB version, workbook/protocol/template/
  options hashes, preprocessing choices, fit start, parameter stages, bounds,
  seeds, restart count, and evaluation limits;
- `data/<alignment_policy>/`: prepared targets, protocols, and experimental
  metrics;
- `configs/`: generated optimization JSON files;
- `results/<alignment_policy>/<genotype>/<stage>/<restart>/`: model, optimizer,
  fit result, and completion artifacts for every fit;
- `tables/`: restart-level, stage-level, boundary, identifiability, waveform,
  and provenance summaries;
- `figures/`: experimental traces, failed three-parameter overlays, sequential
  AIC/error comparisons, best-fit overlays, and identifiability/boundary plots;
- `AUTHORITATIVE_OUTPUTS.md`: human-readable description of which files are
  authoritative and which conclusions remain provisional.

`Code/Fitting/mava_codex/output/AUTHORITATIVE_RUN.txt` will contain the selected
completed run identifier. Historical directories under `output/` will remain
untouched and will not be read by the new summarizer.

## Reproducible Runner

A single MATLAB entry point will support dry-run, execute, resume, and summarize
modes. It will:

1. validate the input files and settings;
2. create or validate the immutable run capsule;
3. preprocess the requested alignment policies;
4. build every nested fit configuration deterministically;
5. run incomplete configurations one at a time;
6. record per-fit success or failure without marking unrelated fits complete;
7. summarize only results named in the manifest;
8. publish the authority pointer only after required fits and summaries pass
   validation.

One MATLAB instance is the default. The runner will not launch background
MATLAB processes, so it cannot violate the two-instance limit by itself.

## Sequential Fit Design

The models are nested and keep `k_2` independently free throughout:

| Stage | Free parameters |
|---|---|
| `k123` | `k_1`, `k_2`, `k_3` |
| `plus_k50` | `k_1`, `k_2`, `k_3`, `k_5_0` |
| `plus_k40` | `k_1`, `k_2`, `k_3`, `k_5_0`, `k_4_0` |
| `plus_k73` | `k_1`, `k_2`, `k_3`, `k_5_0`, `k_4_0`, `k_7_3` |

All stage bounds will be fixed relative to the genotype-specific Before
best-fit model, initially one log unit below and above the corresponding
baseline value. Later stages must not recenter bounds on an earlier acute fit.
This preserves the nested comparison and makes boundary diagnostics
interpretable.

Each stage will use four deterministic multistarts. Starts will include the
baseline midpoint, the preceding stage's best solution with the new parameter
at baseline, and reproducible space-filling perturbations. If the leading final
stage has materially different near-optimal solutions, it will receive four
additional deterministic starts. Fit outputs will retain the optimizer exit
status, iteration and evaluation counts, termination message, unclamped best
coordinates, clamped simulated coordinates, and physical parameter values.

## Metrics and AIC

Every fit is scored from row 481 through the end of its target using the current
range-normalized mean squared waveform error. The existing AIC form,
`n_active * log(error) + 2*k`, will be used for comparisons among stages sharing
the same target. Summaries will also report delta AIC and Akaike weights within
each genotype/alignment group.

Waveform comparisons will use a common metrics function and report:

- peak force and relative peak error;
- sustained 5% force-rise time and calcium-to-force lag;
- argmax and near-peak-centroid time to peak;
- relaxation half-time and FWHM;
- normalized RMSE over the scored window.

## Boundary and Identifiability Diagnostics

For every fitted parameter, boundary output will include its raw optimizer
coordinate, simulated/clamped coordinate, physical value, lower and upper
bounds, normalized distance to the nearest bound, log-distance/fold-distance
to the nearest physical bound, and one of `interior`, `near_lower`,
`near_upper`, `outside_lower`, or `outside_upper`. Near-boundary means within
2% of the normalized optimizer range.

Identifiability will be described conservatively from the multistart ensemble:

- number of completed and converged starts;
- best, median, and worst fit error;
- number of distinct solution clusters;
- log-parameter spread across all completed starts;
- log-parameter spread among near-optimal fits with delta AIC at most 2;
- boundary frequency per parameter;
- a flag of `stable`, `weak`, or `non-identifiable` based on explicit thresholds
  recorded in the summarizer.

These are practical-identifiability diagnostics, not proof of structural
identifiability. Parameters will not be presented as mechanistic drivers when
near-optimal solutions span materially different values or repeatedly hit
bounds.

## Tests and TDD

Implementation will use red-green-refactor cycles. Tests will use temporary
directories and the repository workbook; no test may modify production output.

Required tests cover:

- synthetic traces with known baselines and timing offsets;
- exact behavior of `shared_by_genotype` and `independent_trace`;
- correct trough, 5% rise, aligned-rise, and calcium-lag diagnostics;
- one scale factor per genotype and the approximately 35%/33% acute peak ratios;
- row 481 as the first `pCa < 6.70` sample and as the scoring start;
- independent `k_2` surviving model generation without the legacy ratio
  override;
- exact parameter sets, fixed bounds, deterministic starts, and nested stages;
- boundary classifications at interior, near-bound, exact-bound, and
  out-of-bound coordinates;
- run-directory collision rejection and manifest-validated resume behavior;
- summary calculations for error, AIC, delta AIC, Akaike weight, waveform
  timing, and identifiability using fixture results;
- dry-run behavior that creates configs and provenance without launching fits.

The existing fourteen tests will be retained or strengthened, and output-writing
tests will be converted to isolated fixtures before the full suite is rerun.

## Review and Verification

After implementation and before production fits:

1. run the focused new tests;
2. run the complete MATLAB test suite;
3. conduct an independent internal code review for requirements, test quality,
   data provenance, and statistical correctness;
4. resolve review findings and rerun affected tests;
5. execute a dry run and inspect its manifest/configuration matrix;
6. execute the production run with one MATLAB instance;
7. validate every listed result and regenerate summaries from the manifest;
8. visually inspect all final figures;
9. rerun the complete test suite before declaring completion.

## Deliverables

- Hardened preprocessing and fitting code under `Code/Fitting/mava_codex/`.
- Strengthened isolated MATLAB tests under `Code/Tests/`.
- One complete immutable production run capsule.
- Sequential comparison tables and presentation-ready figures.
- A concise written interpretation separating robust findings, provisional
  Control timing/parameter results, independent-`k_2` diagnostics, limitations,
  and the PI stimulus-synchronization question.
- No slide deck in this phase.
