function test_mava_reduced_report
% Completed multistarts must produce group and 24 h recovery summaries.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
source_out = fullfile(repo_root, 'Code', 'Fitting', 'mava_codex', ...
    'output', 'reduced_multistart');
out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's'));

copyfile(fullfile(source_out, 'data'), fullfile(out_dir, 'data'));
results_dir = fullfile(out_dir, 'results');
mkdir(results_dir);
run_ids = { ...
    'ctrl_acute_r10_s01', 'ctrl_acute_r10_s02', ...
    'ctrl_acute_r10_s03', 'ctrl_acute_r10_s04', ...
    'ctrl_acute_r20_s01', 'ctrl_acute_r20_s02', ...
    'ctrl_acute_r20_s03', 'ctrl_acute_r20_s04', ...
    'hcm_acute_r10_s01', 'hcm_acute_r10_s02', ...
    'hcm_acute_r10_s03', 'hcm_acute_r10_s04', ...
    'hcm_acute_r20_s01', 'hcm_acute_r20_s02', ...
    'hcm_acute_r20_s03', 'hcm_acute_r20_s04'};
for i = 1:numel(run_ids)
    copyfile(fullfile(source_out, [run_ids{i} '_optimization.json']), out_dir);
    copyfile(fullfile(source_out, 'results', run_ids{i}), ...
        fullfile(results_dir, run_ids{i}));
end
result = mava_reduced_report(out_dir, [0 1]);

assert(height(result.runs) == 16, 'Expected all 16 completed multistarts.');
assert(height(result.groups) == 4, 'Expected genotype x ratio groups.');
assert(height(result.recovery) == 8, ...
    'Expected genotype x ratio x recovery endpoint rows.');
assert(all(result.groups.n_starts == 4), 'Each group needs four starts.');
assert(all(isfinite(result.runs.total_score)), 'Run scores must be finite.');
near_bound = result.runs.run_id == "hcm_acute_r20_s03";
assert(result.runs.boundary_count(near_bound) > 0, ...
    'Values within 2%% of an optimizer boundary must be flagged.');
assert(isfile(fullfile(out_dir, 'reduced_run_summary.csv')), ...
    'Missing run summary.');
assert(isfile(fullfile(out_dir, 'recovery_path_summary.csv')), ...
    'Missing recovery summary.');

fprintf('PASS: reduced Mava report\n');
end
