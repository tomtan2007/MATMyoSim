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
fprintf('PASS: explicit time-fit start index\n');
end
