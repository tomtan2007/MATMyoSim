function test_evaluate_time_fit_start_index
% An explicit protocol onset must control the scored fitting window.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

sim.muscle_force = [100; 100; 100; 110; 120; 130];
target = [0; 0; 0; 10; 20; 30];

[e, y, aligned] = evaluate_time_fit(sim, target, 'fit_start_index', 4);

assert(abs(e) < 1e-12, ...
    'Samples before the explicit fit start must not affect the error.');
assert(max(abs(y - sim.muscle_force)) < 1e-12, ...
    'evaluate_time_fit must continue returning the unshifted simulation.');
assert(max(abs(aligned - target)) < 1e-12, ...
    'The optional aligned output must expose the waveform that was scored.');

% Opposite vector orientations must still produce a scalar error, and the
% normalization range must come only from the scored target window.
oriented_sim.muscle_force = [1100; 100; 100; 110; 120; 140];
oriented_target = [1000, 0, 0, 10, 20, 30];
[oriented_error, oriented_y, oriented_aligned] = evaluate_time_fit( ...
    oriented_sim, oriented_target, 'fit_start_index', 3.6);
assert(isscalar(oriented_error) && abs(oriented_error - 1/12) < 1e-12, ...
    'Scoring must be column-safe and normalized over rows 4:end.');
assert(isequal(size(oriented_y), size(oriented_sim.muscle_force)), ...
    'The legacy unshifted simulation output must retain its orientation.');
assert(isequal(size(oriented_aligned), [6 1]), ...
    'The aligned scoring waveform must be returned as a column vector.');

auto_sim.muscle_force = [100; 100; 100; 110; 120; 130];
auto_error = evaluate_time_fit(auto_sim, target);
assert(abs(auto_error) < 1e-12, ...
    'An empty fit start must retain threshold-based start detection.');

[aligned_seven, idx_seven] = align_time_fit_baseline( ...
    (10:17)', 100 + (1:8)', 8);
assert(isequal(idx_seven, 4:7) && ...
    max(abs(aligned_seven - (101:108)')) < 1e-12, ...
    'Seven passive samples must use rounded-half indices 4:7 and target mean.');
[~, idx_five] = align_time_fit_baseline((1:6)', (11:16)', 6);
assert(isequal(idx_five, 1:5), ...
    'Exactly five passive samples must use the complete passive window.');

assert_error(@() evaluate_time_fit(sim, target, 'fit_start_index', NaN), ...
    'resolve_time_fit_start_index:badFitStartIndex');
assert_error(@() evaluate_time_fit(sim, target, 'fit_start_index', [3 4]), ...
    'resolve_time_fit_start_index:badFitStartIndex');
fprintf('PASS: explicit time-fit start index\n');
end

function assert_error(f, expected_id)
try
    f();
    error('test_evaluate_time_fit_start_index:missingError', ...
        'Expected error %s.', expected_id);
catch ME
    assert(strcmp(ME.identifier, expected_id), ...
        'Expected %s but received %s.', expected_id, ME.identifier);
end
end
