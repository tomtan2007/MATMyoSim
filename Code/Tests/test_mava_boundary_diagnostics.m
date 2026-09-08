function test_mava_boundary_diagnostics
% Raw optimizer coordinates must drive boundary classification.

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

raw = [0.50 0.01 0.99 -0.01 1.01];
expected = ["interior"; "near_lower"; "near_upper"; ...
    "outside_lower"; "outside_upper"];
parameters = cell(1, numel(raw));
for i = 1:numel(raw)
    parameters{i} = struct('name', sprintf('k_%d', i), ...
        'min_value', -1, 'max_value', 1, 'p_value', 0.25, ...
        'p_value_raw', raw(i), 'p_mode', 'log');
end

D = mava_boundary_diagnostics(parameters);
assert(height(D) == 5, 'Expected one boundary row per parameter.');
assert(isequal(string(D.classification), expected), ...
    'Raw coordinates were not classified in the required order.');
assert(max(abs(D.p_simulated - [0.50; 0.01; 0.99; 0; 1])) < 1e-12, ...
    'Only the simulated coordinate should be clamped to [0,1].');
assert(max(abs(D.physical_value - 10.^(-1 + 2*D.p_simulated))) < 1e-12, ...
    'Log-mode physical values must use the clamped coordinate.');
finite_names = {'normalized_distance','log_distance','fold_distance', ...
    'lower_bound','upper_bound','physical_value','p_raw','p_simulated'};
for i = 1:numel(finite_names)
    assert(all(isfinite(D.(finite_names{i}))), ...
        'Boundary diagnostic %s must be finite.', finite_names{i});
end

exact_bounds = parameters(1:2);
exact_bounds{1}.p_value_raw = 0;
exact_bounds{2}.p_value_raw = 1;
D_exact = mava_boundary_diagnostics(exact_bounds);
assert(isequal(string(D_exact.classification), ...
    ["near_lower";"near_upper"]), ...
    'Exact optimizer bounds must be classified as near-boundary hits.');

fprintf('PASS: Mava boundary diagnostics\n');
end
