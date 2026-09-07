function test_mava_extended_sensitivity
% Expanded screen must score every requested parameter and flag validity.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>
parameters = {'k_4_0','k_on'};
source = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');
result = mava_extended_sensitivity( ...
    source, out_dir, 1, parameters, 'shared_by_genotype');

assert(height(result.screen) == 8, ...
    'Expected genotype x ratio x parameter rows.');
assert(height(result.comparison) == 24, ...
    'Expected each screen row scored against three scaling modes.');
assert(all(ismember(parameters, cellstr(unique(result.screen.parameter)))), ...
    'Requested parameters were not all screened.');
assert(all(result.screen.valid), 'Baseline simulations should be valid.');
assert(all(isfinite(result.comparison.total_score)), ...
    'Valid simulations must have finite scores.');
assert(isfile(fullfile(out_dir, 'extended_screen.csv')), ...
    'Missing extended screen output.');
assert(isfile(fullfile(out_dir, 'parameter_effects.csv')), ...
    'Missing ranked parameter effects output.');

fprintf('PASS: mavacamten extended sensitivity\n');
end
