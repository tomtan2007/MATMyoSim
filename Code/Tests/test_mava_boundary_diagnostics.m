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
finite_names = {'normalized_distance','physical_distance', ...
    'lower_bound','upper_bound','physical_value','p_raw','p_simulated'};
for i = 1:numel(finite_names)
    assert(all(isfinite(D.(finite_names{i}))), ...
        'Boundary diagnostic %s must be finite.', finite_names{i});
end
assert(all(isfinite(D.log_distance)) && all(isfinite(D.fold_distance)), ...
    'Log-mode parameters must report real logarithmic and fold distances.');

linear = {struct('name', 'linear_rate', 'min_value', 2, ...
    'max_value', 12, 'p_value', 0.25, 'p_value_raw', 0.25, ...
    'p_mode', 'linear')};
D_linear = mava_boundary_diagnostics(linear);
assert(abs(D_linear.physical_value - 4.5) < 1e-12 && ...
    abs(D_linear.physical_distance - 2.5) < 1e-12, ...
    'Linear parameters must report absolute physical distance to a bound.');
assert(isnan(D_linear.log_distance) && isnan(D_linear.fold_distance), ...
    ['Linear parameters must mark logarithmic/fold distance as not ' ...
    'applicable rather than inventing a fold distance.']);

exact_bounds = parameters(1:2);
exact_bounds{1}.p_value_raw = 0;
exact_bounds{2}.p_value_raw = 1;
D_exact = mava_boundary_diagnostics(exact_bounds);
assert(isequal(string(D_exact.classification), ...
    ["near_lower";"near_upper"]), ...
    'Exact optimizer bounds must be classified as near-boundary hits.');

invalid = linear;
invalid{1}.p_value_raw = NaN;
assert_error(@() mava_boundary_diagnostics(invalid), ...
    'mava_boundary_diagnostics:badParameter');
invalid = linear;
invalid{1}.max_value = Inf;
assert_error(@() mava_boundary_diagnostics(invalid), ...
    'mava_boundary_diagnostics:badParameter');
invalid = linear;
invalid{1}.min_value = 12;
invalid{1}.max_value = 2;
assert_error(@() mava_boundary_diagnostics(invalid), ...
    'mava_boundary_diagnostics:badParameter');

fprintf('PASS: Mava boundary diagnostics\n');
end

function assert_error(f, expected_id)
try
    f();
catch ME
    assert(strcmp(ME.identifier, expected_id), ...
        'Expected %s, received %s.', expected_id, ME.identifier);
    return;
end
error('test_mava_boundary_diagnostics:missingError', ...
    'Expected error %s.', expected_id);
end
