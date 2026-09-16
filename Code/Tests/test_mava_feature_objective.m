function test_mava_feature_objective
repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

t = (0:0.001:1)';
target = 100*exp(-0.5*((t-0.62)/0.10).^2);
target(t < 0.30) = 0;
onset_idx = 301;

perfect.time_s = t;
perfect.muscle_force = target;
[perfect_error, ~, perfect_details] = evaluate_mava_feature_fit( ...
    perfect, target, 'fit_start_index', onset_idx);
assert(perfect_error < 1e-20, ...
    'A target scored against itself must have zero feature error.');
assert(nnz(perfect_details.included) >= 8, ...
    'The default objective should score the core feature set.');

altered = perfect;
altered.muscle_force = 0.7*100*exp(-0.5*((t-0.68)/0.14).^2);
altered.muscle_force(t < 0.30) = 0;
[altered_error, ~, altered_details] = evaluate_mava_feature_fit( ...
    altered, target, 'fit_start_index', onset_idx);
assert(altered_error > 1, ...
    'A lower, delayed, broader twitch should have substantial feature error.');
assert(any(abs(altered_details.standardized_residual( ...
    altered_details.included)) > 1), ...
    'Altered twitch should miss at least one feature tolerance.');

missing_target = perfect_details;
target_metrics = mava_feature_metrics(t, target, ...
    'ReferenceOnsetTime', t(onset_idx), ...
    'BaselineIndices', 251:300);
model_metrics = target_metrics;
target_metrics.relaxation_90_time = NaN;
spec = mava_default_feature_spec(target_metrics);
[~, missing_details] = mava_feature_score(target_metrics, model_metrics, spec);
relax90 = missing_details.feature == "relaxation_90_time";
assert(~missing_details.included(relax90), ...
    'Unobserved target relaxation must be excluded, not imputed.');

fprintf('PASS: Mava feature objective\n');
end
