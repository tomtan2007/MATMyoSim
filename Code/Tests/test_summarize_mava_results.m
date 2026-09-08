function test_summarize_mava_results
% Completed fits must yield a four-row summary and comparison figures.

test_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(test_dir));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
source_out = fullfile(repo_root, 'Code', 'Fitting', 'mava_codex', 'output');
fixture_root = tempname;
mkdir(fixture_root);
cleanup = onCleanup(@() rmdir(fixture_root, 's'));
out_dir = fullfile(fixture_root, 'output');
mkdir(out_dir);

copyfile(fullfile(source_out, 'data'), fullfile(out_dir, 'data'));
results_dir = fullfile(out_dir, 'results');
mkdir(results_dir);
run_ids = {'ctrl_acute_r10', 'ctrl_acute_r20', ...
    'hcm_acute_r10', 'hcm_acute_r20'};
for i = 1:numel(run_ids)
    copyfile(fullfile(source_out, 'results', run_ids{i}), ...
        fullfile(results_dir, run_ids{i}));
    copied_config = fullfile(results_dir, run_ids{i}, ...
        'best_optimization.json');
    encoded_source = strrep(source_out, '/', '\/');
    encoded_fixture = strrep(out_dir, '/', '\/');
    config_text = strrep(fileread(copied_config), ...
        encoded_source, encoded_fixture);
    config_file = fopen(copied_config, 'w');
    assert(config_file >= 0, 'Could not rewrite copied optimization fixture.');
    config_cleanup = onCleanup(@() fclose(config_file));
    fprintf(config_file, '%s', config_text);
    clear config_cleanup
    assert(~contains(fileread(copied_config), encoded_source), ...
        'Copied reporter fixtures must not retain production output paths.');
end

summary = summarize_mava_results(out_dir);
assert(height(summary) == 4, 'Expected four fitted conditions.');
assert(all(ismember(summary.ratio, [10 20])), 'Unexpected coupling ratio.');
assert(all(isfinite(summary.best_error)), 'Fit errors must be finite.');
assert(all(isfinite(summary.srx_rest_total)), 'SRX predictions must be finite.');
assert(isfile(fullfile(out_dir, 'fit_summary.csv')), 'Missing fit summary CSV.');
assert(isfile(fullfile(out_dir, 'mava_fit_overlays.png')), 'Missing overlay figure.');
assert(isfile(fullfile(out_dir, 'mava_experimental_traces.png')), ...
    'Missing experimental trace figure.');

fprintf('PASS: mavacamten result summary\n');
end
