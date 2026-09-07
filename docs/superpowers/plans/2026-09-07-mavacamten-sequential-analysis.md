# Mavacamten Sequential Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, verify, and execute an immutable, reproducible nested mavacamten fit analysis without creating the Wednesday slide deck.

**Architecture:** Extend the existing `mava_codex` workflow with explicit preprocessing policies, pure diagnostic helpers, a nested fit-config factory, and a manifest-driven runner. Production artifacts live in a new run capsule and are summarized only from manifest-listed results, leaving every historical output directory untouched.

**Tech Stack:** MATLAB R2026a, MATMyoSim, MATLAB function tests, JSONLab, CSV/JSON/PNG artifacts, Git.

**Spec:** `docs/superpowers/specs/2026-09-07-mavacamten-sequential-analysis-design.md`

## Global Constraints

- Do not create or edit a slide deck.
- Preserve existing user, Claude, engine, and historical result files except for the exact source/test files named here.
- Never overwrite an existing run capsule; resume only after manifest validation.
- Default to `Code/System/experimental_data/Mava data.xlsx`.
- Preserve local baseline correction, one force scale per genotype, and `shared_by_genotype` as the default alignment.
- Score from row 481, the first protocol row with `pCa < 6.70`.
- Keep `k_2` independently free in every stage and do not interpret fitted `k_2/k_1` ratios biologically.
- Compare AIC only within one genotype, target, and alignment policy.
- Use one serial MATLAB instance and never exceed two total instances.
- Add `Code/System` to the MATLAB path after the repository path to prevent worktree shadowing.
- Use red-green-refactor for every production-code change.

---

### Task 1: Extract and test trace landmarks and alignment policies

**Files:**
- Create: `Code/Fitting/mava_codex/detect_mava_trace_landmarks.m`
- Create: `Code/Fitting/mava_codex/mava_alignment_shifts.m`
- Create: `Code/Tests/test_detect_mava_trace_landmarks.m`
- Create: `Code/Tests/test_mava_alignment_policies.m`

**Interfaces:**
- Produces `landmarks = detect_mava_trace_landmarks(t,y)` with peak, trough, sustained 5%-rise indices/times, and local baseline.
- Produces `shifts = mava_alignment_shifts(trough_times,genotypes,calcium_onset,policy)` for `shared_by_genotype` or `independent_trace`.

- [ ] **Step 1: Write the failing landmark test**

```matlab
t=(0:0.01:1.2)';
y=7+100*exp(-0.5*((t-0.70)/0.10).^2); y(t<0.42)=7;
L=detect_mava_trace_landmarks(t,y);
assert(abs(L.baseline_value-7)<0.2);
assert(abs(L.peak_time-0.70)<=0.01);
assert(L.trough_time<L.rise_time && L.rise_time<L.peak_time);
```

- [ ] **Step 2: Run it and confirm an undefined-function failure**

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_detect_mava_trace_landmarks"`

- [ ] **Step 3: Implement the landmark helper by extracting lines 122-148 of `prepare_mava_data.m`**

Use the current primary window `0.35 <= t <= 1.0`, three-point smoothing, last pre-peak search window, and two-sample sustained 5% threshold. Validate equal finite column vectors and return:

```matlab
L=struct('peak_index',peak_idx,'trough_index',trough_idx, ...
 'rise_index',rise_idx,'peak_time',t(peak_idx), ...
 'trough_time',t(trough_idx),'rise_time',t(rise_idx), ...
 'baseline_value',baseline);
```

- [ ] **Step 4: Run the landmark test and confirm it passes**

- [ ] **Step 5: Write the failing alignment test**

```matlab
trough=[0.16;0.35;0.21;0.29;0.22;0.19];
codes=["Control";"Control";"Control";"H251N";"H251N";"H251N"];
shared=mava_alignment_shifts(trough,codes,0.480,'shared_by_genotype');
independent=mava_alignment_shifts(trough,codes,0.480,'independent_trace');
assert(max(abs(shared(1:3)-(0.480-0.16)))<1e-12);
assert(max(abs(shared(4:6)-(0.480-0.29)))<1e-12);
assert(max(abs(trough+independent-0.480))<1e-12);
```

- [ ] **Step 6: Run it and confirm an undefined-function failure**

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_mava_alignment_policies"`

- [ ] **Step 7: Implement the policy helper**

For `shared_by_genotype`, use the first Control and first H251N trough as the respective anchor. For `independent_trace`, return `calcium_onset-trough_times`. Reject any other policy with identifier `mava_alignment_shifts:badPolicy`.

- [ ] **Step 8: Run both focused tests and commit**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_detect_mava_trace_landmarks; test_mava_alignment_policies"
git add Code/Fitting/mava_codex/detect_mava_trace_landmarks.m Code/Fitting/mava_codex/mava_alignment_shifts.m Code/Tests/test_detect_mava_trace_landmarks.m Code/Tests/test_mava_alignment_policies.m
git commit -m "test: define mavacamten timing policies"
```

---

### Task 2: Harden preprocessing and make its tests hermetic

**Files:**
- Modify: `Code/Fitting/mava_codex/prepare_mava_data.m:1-148`
- Modify: `Code/Fitting/mava_codex/run_mava_codex.m:1-18`
- Modify: `Code/Fitting/mava_codex/mava_amplitude_timing_analysis.m:1-14`
- Modify: `Code/Fitting/mava_codex/mava_extended_sensitivity.m:1-14`
- Modify: `Code/Tests/test_prepare_mava_data.m`
- Modify: `Code/Tests/test_mava_onset_alignment.m`
- Modify: `Code/Tests/test_mava_scaling_modes.m`
- Modify: `Code/Tests/test_run_mava_codex_dry_run.m`
- Modify: `Code/Tests/test_mava_amplitude_timing_analysis.m`
- Modify: `Code/Tests/test_mava_extended_sensitivity.m`

**Interfaces:**
- Produces `summary = prepare_mava_data(workbook_file,out_dir,scale_mode,alignment_policy)`.
- Empty workbook defaults to the repository copy; alignment defaults to `shared_by_genotype`.

- [ ] **Step 1: Extend tests with the new diagnostics and repository workbook**

Replace every Downloads path with:

```matlab
source=fullfile(repo_root,'Code','System','experimental_data','Mava data.xlsx');
```

Assert the columns `source_trough_time`, `source_force_rise_time`, `applied_time_shift`, `aligned_force_rise_time`, `calcium_to_force_lag`, and `alignment_policy`. Assert shared shifts within each genotype, Control lags of `0.063`, `0.208`, and `0.133` seconds within 4 ms, and acute peak ratios within 0.02 of 0.35 and 0.33.

- [ ] **Step 2: Run the six affected tests and confirm failures**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_prepare_mava_data; test_mava_onset_alignment; test_mava_scaling_modes; test_run_mava_codex_dry_run; test_mava_amplitude_timing_analysis; test_mava_extended_sensitivity"
```

- [ ] **Step 3: Change preprocessing defaults and signature**

```matlab
function summary=prepare_mava_data(workbook_file,out_dir,scale_mode,alignment_policy)
script_dir=fileparts(mfilename('fullpath'));
repo_root=fullfile(script_dir,'..','..','..');
if nargin<1 || isempty(workbook_file)
 workbook_file=fullfile(repo_root,'Code','System','experimental_data','Mava data.xlsx');
end
if nargin<3 || isempty(scale_mode), scale_mode='peak'; end
if nargin<4 || isempty(alignment_policy), alignment_policy='shared_by_genotype'; end
```

- [ ] **Step 4: Replace the nested detector and ambiguous column names**

Use `detect_mava_trace_landmarks` for every trace and select shifts only after all six landmarks are known. Compute:

```matlab
applied_time_shift=mava_alignment_shifts(source_trough_time,genotypes,onset_time,alignment_policy);
aligned_force_rise_time=source_force_rise_time+applied_time_shift;
calcium_to_force_lag=aligned_force_rise_time-onset_time;
```

Retain the current local-baseline subtraction, cutoff, interpolation, shared genotype scaling, and output lengths.

- [ ] **Step 5: Pass the optional alignment policy through legacy callers and rerun tests**

Expected: six passes and no writes under the production `output/` tree.

- [ ] **Step 6: Commit**

```bash
git add Code/Fitting/mava_codex/prepare_mava_data.m Code/Fitting/mava_codex/run_mava_codex.m Code/Fitting/mava_codex/mava_amplitude_timing_analysis.m Code/Fitting/mava_codex/mava_extended_sensitivity.m Code/Tests/test_prepare_mava_data.m Code/Tests/test_mava_onset_alignment.m Code/Tests/test_mava_scaling_modes.m Code/Tests/test_run_mava_codex_dry_run.m Code/Tests/test_mava_amplitude_timing_analysis.m Code/Tests/test_mava_extended_sensitivity.m
git commit -m "feat: make mavacamten alignment explicit"
```

---

### Task 3: Verify independent `k_2` and capture optimizer diagnostics

**Files:**
- Modify: `Code/System/fit/fit_controller.m:1-164`
- Create: `Code/Tests/test_independent_k2_model_write.m`
- Create: `Code/Tests/test_fit_controller_diagnostics.m`

**Interfaces:**
- Produces optional return value `fit_results = fit_controller(opt_structure,varargin)`.
- Adds `exitflag`, `iterations`, `func_count`, `algorithm`, and `message` to `fit_results.json`.
- Saves clamped `p_value` plus raw `p_value_raw` in `best_optimization.json`.

- [ ] **Step 1: Write and run the independent-`k_2` model-write test**

Create a temporary optimization with `k_1` bounds `[0,2]`, `k_2` bounds `[1,3]`, and normalized values `[0.25,0.75]`. Call `update_json_model_file` and assert `k_1=10^0.5`, `k_2=10^2.5`, and `k_2 ~= 10*k_1`.

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_independent_k2_model_write"`

Expected: it passes with the current free-parameter protection. If not, fix only the exact-name detection in `update_json_model_file.m`.

- [ ] **Step 2: Write a failing diagnostics test with a test-only quadratic objective**

The fixture supplies `opt_structure.test_objective = @(p)sum((p-0.4).^2)` and temporary result paths, then asserts returned/disk fields and that every saved `p_value` is in `[0,1]` while `p_value_raw` exists.

- [ ] **Step 3: Run it and confirm failure on the current controller**

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_fit_controller_diagnostics"`

- [ ] **Step 4: Capture optimizer outputs and raw/clamped coordinates**

```matlab
[~,~,exitflag,fm_output]=fminsearch(fh,p_vector,fm_options);
fit_results.exitflag=exitflag;
fit_results.iterations=fm_output.iterations;
fit_results.func_count=fm_output.funcCount;
fit_results.algorithm=fm_output.algorithm;
fit_results.message=fm_output.message;
```

When saving a best point, set `p_value_raw` to the raw coordinate and `p_value=max(0,min(1,p_value_raw))`. Use the test objective only when its field is present; production continues through `fit_worker`.

- [ ] **Step 5: Run focused tests and commit**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_build_mava_free_k2_fit_configs; test_independent_k2_model_write; test_fit_controller_diagnostics"
git add Code/System/fit/fit_controller.m Code/Tests/test_independent_k2_model_write.m Code/Tests/test_fit_controller_diagnostics.m
git commit -m "feat: record fit convergence diagnostics"
```

---

### Task 4: Build deterministic nested fit configurations

**Files:**
- Create: `Code/Fitting/mava_codex/mava_parameter_stages.m`
- Create: `Code/Fitting/mava_codex/mava_deterministic_start.m`
- Create: `Code/Fitting/mava_codex/build_mava_sequential_fit_config.m`
- Create: `Code/Tests/test_mava_parameter_stages.m`
- Create: `Code/Tests/test_build_mava_sequential_fit_config.m`

**Interfaces:**
- `stages = mava_parameter_stages()` returns four exact nested parameter lists.
- `p = mava_deterministic_start(n,restart,previous_best)` returns reproducible normalized seeds.
- `[config_file,record] = build_mava_sequential_fit_config(run_dir,alignment,genotype,stage,restart,previous_best,settings)` writes one config.

- [ ] **Step 1: Write failing stage/seed tests**

```matlab
S=mava_parameter_stages();
assert(isequal({S.id},{'k123','plus_k50','plus_k40','plus_k73'}));
assert(isequal(S(1).parameters,{'k_1','k_2','k_3'}));
assert(isequal(S(4).parameters,{'k_1','k_2','k_3','k_5_0','k_4_0','k_7_3'}));
assert(isequal(mava_deterministic_start(4,2,[]),mava_deterministic_start(4,2,[])));
assert(any(abs(mava_deterministic_start(4,2,[])-mava_deterministic_start(4,3,[]))>0.01));
```

- [ ] **Step 2: Run tests and confirm missing functions**

- [ ] **Step 3: Implement exact stages and seeds**

Restart 1 is all `0.5` for stage 1; later restart 1 is the preceding best coordinates plus `0.5` for the new parameter. Other starts use:

```matlab
j=0:n-1;
p=0.2+0.6*mod((restart-1)*0.61803398875+j*0.41421356237,1);
```

- [ ] **Step 4: Write a failing config-factory test**

In a temporary run directory, assert exact parameter names, `fit_start_index==481`, absence of `k_2_k_1_ratio`, fixed one-log-unit bounds centered on the unchanged genotype baseline model, unique result directories, and deterministic seeds.

- [ ] **Step 5: Implement the config factory**

Map Control to `twitch_6state_control`/`ctrl_acute`, H251N to `twitch_6state_HCM`/`hcm_acute`. Store results under `results/<alignment>/<genotype>/<stage>/sNN/` and configs as `configs/<alignment>__<genotype>__<stage>__sNN.json`.

- [ ] **Step 6: Run both tests and commit**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_mava_parameter_stages; test_build_mava_sequential_fit_config"
git add Code/Fitting/mava_codex/mava_parameter_stages.m Code/Fitting/mava_codex/mava_deterministic_start.m Code/Fitting/mava_codex/build_mava_sequential_fit_config.m Code/Tests/test_mava_parameter_stages.m Code/Tests/test_build_mava_sequential_fit_config.m
git commit -m "feat: build nested mavacamten fit stages"
```

---

### Task 5: Add an immutable manifest-driven runner

**Files:**
- Create: `Code/Fitting/mava_codex/mava_sha256.m`
- Create: `Code/Fitting/mava_codex/mava_run_manifest.m`
- Create: `Code/Fitting/mava_codex/run_mava_sequential_analysis.m`
- Create: `Code/Tests/test_mava_sha256.m`
- Create: `Code/Tests/test_mava_run_manifest.m`
- Create: `Code/Tests/test_run_mava_sequential_dry_run.m`

**Interfaces:**
- `digest = mava_sha256(file)` returns lowercase SHA-256.
- `manifest = mava_run_manifest(run_dir,settings,mode)` creates or validates provenance.
- `run = run_mava_sequential_analysis(run_id,mode,varargin)` supports `dry_run`, `execute`, `resume`, and `summarize`.

- [ ] **Step 1: Write failing SHA and manifest tests**

Hash a temporary file containing `abc` and expect `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`. Assert manifest creation records workbook/protocol hashes, duplicate creation fails, matching resume succeeds, and changed `fit_start_index` raises `mava_run_manifest:resumeMismatch`.

- [ ] **Step 2: Run tests and confirm missing functions**

- [ ] **Step 3: Implement binary-safe SHA and manifest validation**

Read with `fread(fid,Inf,'*uint8')`; hash with Java `MessageDigest`. Record repository HEAD, relevant source hashes, MATLAB version, workbook/protocol/template/options hashes, settings, stage lists, and status.

Default settings are:

```matlab
alignment_groups={ ...
 struct('policy','shared_by_genotype','genotypes',{{'Control','H251N'}}), ...
 struct('policy','independent_trace','genotypes',{{'Control'}})};
scale_mode='peak'; fit_start_index=481; restarts=4;
extra_final_restarts=4; max_fun_evals=1200;
tol_fun=1e-5; tol_x=1e-3;
```

- [ ] **Step 4: Write a failing dry-run test**

Use a temporary output root, two restarts, and ten max evaluations. Assert manifest/data/config creation, no `model_best.json`, status `dry_run_complete`, 24 configs, and duplicate-run rejection.

- [ ] **Step 5: Implement the serial runner**

Create or validate the capsule, preprocess requested policies, process groups/stages/restarts in order, use the preceding stage best for later restart 1, and write per-result `status.json`. Resume skips only results with model, best optimization, fit results, and complete status. A failed fit records its identifier/message and leaves the run incomplete.

- [ ] **Step 6: Run focused tests and commit**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_mava_sha256; test_mava_run_manifest; test_run_mava_sequential_dry_run"
git add Code/Fitting/mava_codex/mava_sha256.m Code/Fitting/mava_codex/mava_run_manifest.m Code/Fitting/mava_codex/run_mava_sequential_analysis.m Code/Tests/test_mava_sha256.m Code/Tests/test_mava_run_manifest.m Code/Tests/test_run_mava_sequential_dry_run.m
git commit -m "feat: add immutable mavacamten run capsules"
```

---

### Task 6: Add boundary, waveform, AIC, and identifiability summaries

**Files:**
- Create: `Code/Fitting/mava_codex/mava_boundary_diagnostics.m`
- Create: `Code/Fitting/mava_codex/summarize_mava_sequential_run.m`
- Create: `Code/Fitting/mava_codex/plot_mava_sequential_results.m`
- Modify: `Code/Fitting/mava_codex/mava_waveform_metrics.m`
- Create: `Code/Tests/test_mava_boundary_diagnostics.m`
- Create: `Code/Tests/test_summarize_mava_sequential_run.m`
- Modify: `Code/Tests/test_mava_waveform_metrics.m`

**Interfaces:**
- `D = mava_boundary_diagnostics(parameters)` returns one row per parameter.
- `summary = summarize_mava_sequential_run(run_dir)` returns restart, stage, boundary, waveform, and identifiability tables.
- `plot_mava_sequential_results(run_dir,summary)` creates five deterministic PNGs.

- [ ] **Step 1: Write failing boundary tests**

Test raw coordinates `0.50`, `0.01`, `0.99`, `-0.01`, and `1.01`; expect `interior`, `near_lower`, `near_upper`, `outside_lower`, and `outside_upper`. Require finite normalized, log, fold, bound, and physical-value columns.

- [ ] **Step 2: Implement boundary diagnostics**

Use `p_value_raw` when present; otherwise use `p_value`. Classify outside before near-boundary checks. Clamp only the simulated coordinate. For log mode use `10^(min+p_sim*(max-min))`.

- [ ] **Step 3: Extend waveform tests**

Add sustained 5%-rise time, calcium-to-force lag, and optional target-based normalized RMSE to `mava_waveform_metrics`, preserving existing calls.

- [ ] **Step 4: Write a failing fixture summarizer test**

Create four stages with at least three result fixtures each. Assert minimum delta AIC is zero, Akaike weights sum to one per group, a known near-upper boundary appears, and classifications are limited to `stable`, `weak`, or `non-identifiable`. Fixture mode reads stored metrics and launches no simulation.

- [ ] **Step 5: Implement manifest-only summarization**

Compute `delta=AIC-min(AIC)` and normalized `exp(-0.5*delta)` weights within groups. Near-optimal restarts have within-stage delta AIC `<=2`; count clusters with `uniquetol(P,0.05,'ByRows',true)`.

Use these exact parameter-level classifications:

- `stable`: at least three near-optimal runs, log10 spread `<=0.30`, zero near/outside boundary frequency.
- `weak`: at least two near-optimal runs, log10 spread `<=1.00`, boundary frequency `<0.50`.
- `non-identifiable`: every other case.

Write `restart_summary.csv`, `stage_summary.csv`, `boundary_diagnostics.csv`, `waveform_metrics.csv`, and `identifiability_summary.csv`.

- [ ] **Step 6: Generate presentation-ready figures and authority notes**

Create `experimental_traces_and_alignment.png`, `k123_failed_fits.png`, `sequential_error_aic.png`, `best_fit_waveforms.png`, and `boundary_identifiability.png`. Write `AUTHORITATIVE_OUTPUTS.md` with hashes, authoritative paths, AIC grouping limits, free-`k_2` warning, provisional Control warning, and the PI synchronization question. Do not edit `presentation/`.

- [ ] **Step 7: Run focused tests and commit**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); test_mava_boundary_diagnostics; test_mava_waveform_metrics; test_summarize_mava_sequential_run"
git add Code/Fitting/mava_codex/mava_boundary_diagnostics.m Code/Fitting/mava_codex/summarize_mava_sequential_run.m Code/Fitting/mava_codex/plot_mava_sequential_results.m Code/Fitting/mava_codex/mava_waveform_metrics.m Code/Tests/test_mava_boundary_diagnostics.m Code/Tests/test_summarize_mava_sequential_run.m Code/Tests/test_mava_waveform_metrics.m
git commit -m "feat: summarize mavacamten model progression"
```

---

### Task 7: Isolate legacy tests and run the complete suite

**Files:**
- Modify: `Code/Tests/test_summarize_mava_results.m`
- Modify: `Code/Tests/test_mava_reduced_report.m`
- Create: `Code/Tests/run_mava_tests.m`

**Interfaces:**
- `results = run_mava_tests()` runs all Mava and affected fit-engine tests.
- No test writes into the production `output/` tree.

- [ ] **Step 1: Hash current production outputs**

Run: `find Code/Fitting/mava_codex/output -type f -print0 | sort -z | xargs -0 shasum -a 256 > /tmp/mava-output-before.sha256`

- [ ] **Step 2: Move reporter tests to temporary copied fixtures**

For `test_summarize_mava_results`, copy `data/` plus the four named result directories into a temporary root. For `test_mava_reduced_report`, copy its `data/`, sixteen named configs, and sixteen result directories into a temporary root. Call reporters only on those temporary paths.

- [ ] **Step 3: Create the suite runner**

```matlab
function results=run_mava_tests
repo_root=fullfile(fileparts(mfilename('fullpath')),'..','..');
addpath(genpath(fullfile(repo_root,'Code','System')));
addpath(fullfile(repo_root,'Code','Fitting'));
addpath(fullfile(repo_root,'Code','Fitting','mava_codex'));
results=runtests(fileparts(mfilename('fullpath')),'IncludeSubfolders',false);
assert(all([results.Passed]),'At least one MATMyoSim test failed.');
end
```

- [ ] **Step 4: Run the suite and compare output hashes**

```bash
/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Tests'); R=run_mava_tests; disp(table(R))"
find Code/Fitting/mava_codex/output -type f -print0 | sort -z | xargs -0 shasum -a 256 > /tmp/mava-output-after.sha256
diff -u /tmp/mava-output-before.sha256 /tmp/mava-output-after.sha256
```

Expected: all tests pass and the hash diff is empty.

- [ ] **Step 5: Commit**

```bash
git add Code/Tests/test_summarize_mava_results.m Code/Tests/test_mava_reduced_report.m Code/Tests/run_mava_tests.m
git commit -m "test: isolate mavacamten workflow verification"
```

---

### Task 8: Conduct internal review and validate a dry run

**Files:**
- Review: every file changed in Tasks 1-7
- Create through runner: `Code/Fitting/mava_codex/output/runs/mava_seq_20260907_dryrun/`

- [ ] **Step 1: Invoke `superpowers:requesting-code-review`**

Ask the reviewer to compare the diff with the approved spec, emphasizing preprocessing semantics, independent `k_2`, output immutability, AIC grouping, boundary math, identifiability wording, and test hermeticity.

- [ ] **Step 2: Address each confirmed finding through a failing regression test**

Do not change alignment semantics or statistical interpretation without user approval.

- [ ] **Step 3: Rerun the complete test suite**

- [ ] **Step 4: Execute a dry run**

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Fitting/mava_codex'); run_mava_sequential_analysis('mava_seq_20260907_dryrun','dry_run','restarts',2,'max_fun_evals',10)"`

- [ ] **Step 5: Inspect the dry-run manifest**

Require three groups, four stages, two starts, row 481, independent `k_2`, the repository workbook hash, and no fitted models.

- [ ] **Step 6: Commit confirmed review fixes if any**

Use commit message `fix: address mavacamten workflow review` and skip the commit if review found no defects.

---

### Task 9: Execute and verify the production analysis

**Files:**
- Create through runner: `Code/Fitting/mava_codex/output/runs/mava_seq_20260907/`
- Create through runner: `Code/Fitting/mava_codex/output/AUTHORITATIVE_RUN.txt`
- Do not modify: `presentation/`

- [ ] **Step 1: Check MATLAB process count**

Run: `pgrep -fl '/Applications/MATLAB_R2026a.app|MATLAB_R2026a' || true`

Proceed with one batch process; an existing user GUI plus the batch process remains within the two-instance limit.

- [ ] **Step 2: Launch the 48-fit serial production run**

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Fitting/mava_codex'); run_mava_sequential_analysis('mava_seq_20260907','execute')"`

If interrupted, rerun the identical command with mode `resume`.

- [ ] **Step 3: Apply the adaptive final-stage rule**

Add four declared final-stage starts if the best final stage has fewer than three near-optimal starts, multiple solution clusters, a best-run boundary hit, or more than twofold near-optimal spread in any parameter. Otherwise record that the trigger was not met.

- [ ] **Step 4: Summarize only manifest-listed results**

Run: `/Applications/MATLAB_R2026a.app/bin/matlab -batch "addpath('Code/Fitting/mava_codex'); run_mava_sequential_analysis('mava_seq_20260907','summarize')"`

- [ ] **Step 5: Verify completeness and authority**

Every required result must contain model, best optimization, fit results, and complete status. Summary groups/stages must match the manifest, AIC weights must sum to one within group, and the authority pointer must contain exactly `mava_seq_20260907`.

- [ ] **Step 6: Visually inspect all five figures**

Check labels, legends, target/model pairing, baseline artifacts, boundary markers, and absence of misleading cross-policy AIC comparisons. Regenerate only inside the new capsule.

- [ ] **Step 7: Write the capsule interpretation**

Lead with the 35%/33% acute effect; show the failed `k123` result; identify the parameter addition with the largest AIC improvement and the best defensible stage; report boundary/multistart evidence; label Control provisional; avoid biological interpretation of free `k_2`; include the PI synchronization question.

- [ ] **Step 8: Invoke `superpowers:verification-before-completion`**

Rerun the complete suite, validate manifest/tables, and confirm historical outputs and `presentation/` are unchanged.

- [ ] **Step 9: Commit reviewed source and small authoritative artifacts**

Stage source, tests, authority pointer, manifest, summary CSV/Markdown, and final PNGs explicitly. Do not commit bulky worker outputs unless repository policy already tracks equivalents. Inspect `git diff --cached` before committing with message `feat: complete mavacamten sequential analysis`.

Expected final report: run path, test count, fit completeness, best stage per genotype/alignment policy, AIC and waveform changes, boundary/identifiability caveats, Control timing caveat, review status, and confirmation that no slides were created.
