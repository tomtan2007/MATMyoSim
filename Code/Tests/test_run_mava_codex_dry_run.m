function test_run_mava_codex_dry_run
% Dry run must prepare data/configs without starting optimization.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting'));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

source = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');
run = run_mava_codex(source, out_dir, 10, true, 'independent_trace');
assert(height(run.experimental_metrics) == 6, 'Expected six prepared traces.');
assert(all(strcmp(run.experimental_metrics.alignment_policy, ...
    'independent_trace')), 'Dry run must pass through alignment policy.');
assert(numel(run.config_files) == 4, 'Expected four fit configs.');
assert(isempty(dir(fullfile(out_dir, 'results', '*', 'model_best.json'))), ...
    'Dry run must not launch fits.');

fprintf('PASS: mavacamten dry run\n');
end
