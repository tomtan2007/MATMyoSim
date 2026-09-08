function test_mava_waveform_metrics
% Pre-zeroed experimental targets must not be baseline-subtracted twice.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

t = (0:0.001:1)';
onset_idx = 481;
y = 100 * exp(-0.5*((t-0.70)/0.12).^2);

target = mava_waveform_metrics(t, y, onset_idx, 'prezeroed');
model = mava_waveform_metrics(t, y, onset_idx, 'model');

assert(abs(target.peak - 100) < 1e-10, ...
    'Pre-zeroed target peak must retain its original amplitude.');
assert(model.peak < target.peak, ...
    'Model baseline correction should remove its pre-onset offset.');
assert(abs(target.time_to_peak_centroid - 0.22) < 0.01, ...
    'Centroid time-to-peak is incorrect.');
assert(target.relax_half_time > 0, 'Relaxation half-time must be positive.');

step_t = (0:0.01:1)';
step_y = zeros(size(step_t));
step_y(41) = 4;
step_y(42:43) = 5;
step_y(44:61) = linspace(10, 100, 18);
step_y(62:81) = linspace(95, 0, 20);
step_target = step_y;
step_onset = 31;
step_target(step_onset:numel(step_target)) = ...
    step_target(step_onset:numel(step_target)) + 10;
extended = mava_waveform_metrics(step_t, step_y, step_onset, 'prezeroed', ...
    'calcium_onset_time', 0.30, 'target', step_target, ...
    'fit_start_index', step_onset);
assert(abs(extended.force_rise_time - 0.41) < 1e-12, ...
    'Sustained rise must begin at the first of two samples at 5%% peak.');
assert(abs(extended.calcium_to_force_lag - 0.11) < 1e-12, ...
    'Calcium-to-force lag must use the supplied calcium onset.');
assert(abs(extended.normalized_rmse - 0.1) < 1e-12, ...
    'Normalized RMSE must use the target range over the scored window.');
assert(isfinite(target.force_rise_time) && ...
    isnan(target.calcium_to_force_lag) && isnan(target.normalized_rmse), ...
    'Existing four-argument calls must remain valid with optional metrics unset.');

peak_pair_t = (0:0.01:0.03)';
peak_pair_y = [0; 0; 5; 100];
peak_pair = mava_waveform_metrics(peak_pair_t, peak_pair_y, 2, ...
    'prezeroed');
assert(abs(peak_pair.force_rise_time - 0.02) < 1e-12, ...
    ['The sustained-rise pair may end at the peak sample; the first ' ...
    'qualifying sample is still the rise time.']);

fprintf('PASS: mavacamten waveform metrics\n');
end
