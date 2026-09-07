function test_mava_amplitude_timing_analysis
% A one-level grid must cover both genotypes, both ratios, and all scales.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>
source = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');
result = mava_amplitude_timing_analysis( ...
    source, out_dir, 1, 'shared_by_genotype');

assert(height(result.grid) == 4, 'Expected genotype x ratio grid rows.');
assert(height(result.experimental) == 6, ...
    'Expected genotype x scaling experimental rows.');
assert(height(result.comparison) == 12, ...
    'Expected each grid row scored against three scaling modes.');
assert(all(isfinite(result.comparison.total_score)), 'Scores must be finite.');
assert(isfile(fullfile(out_dir, 'grid_metrics.csv')), 'Missing grid CSV.');
assert(isfile(fullfile(out_dir, 'grid_comparison.csv')), ...
    'Missing comparison CSV.');

fprintf('PASS: mavacamten amplitude-timing analysis\n');
end
