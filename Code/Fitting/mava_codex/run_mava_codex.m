function run = run_mava_codex(workbook_file, out_dir, max_fun_evals, dry_run, alignment_policy)
% Prepare and fit acute mavacamten traces with k_1, k_3, k_5_0 only.

script_dir = fileparts(mfilename('fullpath'));
fitting_dir = fileparts(script_dir);
repo_root = fullfile(script_dir, '..', '..', '..');
if nargin < 1 || isempty(workbook_file)
    workbook_file = fullfile(repo_root, 'Code', 'System', ...
        'experimental_data', 'Mava data.xlsx');
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output');
end
if nargin < 3 || isempty(max_fun_evals), max_fun_evals = 500; end
if nargin < 4, dry_run = false; end
if nargin < 5 || isempty(alignment_policy)
    alignment_policy = 'shared_by_genotype';
end

addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fitting_dir);

data_dir = fullfile(out_dir, 'data');
if ~isfolder(data_dir), mkdir(data_dir); end
run.experimental_metrics = prepare_mava_data(workbook_file, data_dir, ...
    'peak', alignment_policy);
run.config_files = build_mava_fit_configs(out_dir, max_fun_evals);

if dry_run
    fprintf('Dry run complete: prepared six traces and four fit configs.\n');
    return;
end

for i = 1:numel(run.config_files)
    fprintf('\n===== MAVACAMTEN FIT %d/%d =====\n%s\n', ...
        i, numel(run.config_files), run.config_files{i});
    run_variant_fit(script_dir, run.config_files{i});
end
end
