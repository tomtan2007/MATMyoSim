function m = mava_feature_metrics(t, y, varargin)
% Extract robust, interpretable twitch features from one force trace.
%
% Relaxation percentages describe the fraction relaxed: 50%% relaxation is
% the post-peak crossing of 50%% amplitude, while 90%% relaxation is the
% crossing of 10%% amplitude. Threshold times use linear interpolation and
% require a sustained crossing to reject isolated noisy samples.

p = inputParser;
addParameter(p, 'ReferenceOnsetTime', NaN);
addParameter(p, 'BaselineIndices', []);
addParameter(p, 'SmoothWindowSeconds', 0.015);
addParameter(p, 'SmoothWindowSamples', []);
addParameter(p, 'PersistenceSamples', 2);
parse(p, varargin{:});
options = p.Results;

t = t(:);
y = y(:);
if numel(t) ~= numel(y) || numel(t) < 5 || ...
        ~all(isfinite(t)) || ~all(isfinite(y))
    error('mava_feature_metrics:badInput', ...
        't and y must be equal-length finite vectors with at least five samples.');
end
if any(diff(t) <= 0)
    error('mava_feature_metrics:badTime', ...
        't must be strictly increasing.');
end
if ~isscalar(options.PersistenceSamples) || ...
        options.PersistenceSamples < 1 || ...
        options.PersistenceSamples ~= round(options.PersistenceSamples)
    error('mava_feature_metrics:badPersistence', ...
        'PersistenceSamples must be a positive integer.');
end

baseline_indices = options.BaselineIndices(:);
if isempty(baseline_indices)
    if ~isfinite(options.ReferenceOnsetTime)
        error('mava_feature_metrics:missingBaseline', ...
            'Supply BaselineIndices or a finite ReferenceOnsetTime.');
    end
    baseline_indices = find(t < options.ReferenceOnsetTime);
end
if isempty(baseline_indices) || any(baseline_indices < 1) || ...
        any(baseline_indices > numel(y))
    error('mava_feature_metrics:badBaseline', ...
        'BaselineIndices must select at least one valid sample.');
end

baseline = median(y(baseline_indices));
corrected = y - baseline;
baseline_residual = corrected(baseline_indices);
baseline_noise = 1.4826 * median(abs( ...
    baseline_residual - median(baseline_residual)));

dt = median(diff(t));
if isempty(options.SmoothWindowSamples)
    smooth_n = max(3, round(options.SmoothWindowSeconds / dt));
else
    smooth_n = round(options.SmoothWindowSamples);
end
smooth_n = max(1, smooth_n);
if mod(smooth_n, 2) == 0
    smooth_n = smooth_n + 1;
end
smooth_y = movmean(movmedian(corrected, smooth_n, ...
    'Endpoints', 'shrink'), smooth_n, 'Endpoints', 'shrink');

if isfinite(options.ReferenceOnsetTime)
    reference_idx = find(t >= options.ReferenceOnsetTime, 1, 'first');
else
    reference_idx = baseline_indices(end) + 1;
end
if isempty(reference_idx) || reference_idx >= numel(t)
    error('mava_feature_metrics:badReferenceOnset', ...
        'Reference onset must precede the end of the trace.');
end

active = reference_idx:numel(t);
[peak_amplitude, local_peak] = max(smooth_y(active));
peak_idx = active(local_peak);
if ~isfinite(peak_amplitude) || peak_amplitude <= 0
    error('mava_feature_metrics:noPositiveTwitch', ...
        'No positive twitch was detected after the reference onset.');
end

peak_band = contiguous_peak_band(smooth_y, peak_idx, 0.95*peak_amplitude, ...
    reference_idx);
peak_time_centroid = mean(t(peak_band));
peak_plateau_level = median(corrected(peak_band));
peak_residual = corrected(peak_band) - smooth_y(peak_band);
peak_noise = 1.4826 * median(abs(peak_residual - median(peak_residual)));

fractions = [0.05 0.20 0.30 0.50 0.90];
rise_crossing = nan(size(fractions));
for i = 1:numel(fractions)
    rise_crossing(i) = sustained_crossing(t, smooth_y, ...
        reference_idx, peak_idx, fractions(i)*peak_amplitude, ...
        'rising', options.PersistenceSamples);
end
force_onset_time = rise_crossing(1);

decay_fractions = [0.90 0.50 0.20 0.10];
decay_crossing = nan(size(decay_fractions));
for i = 1:numel(decay_fractions)
    decay_crossing(i) = sustained_crossing(t, smooth_y, ...
        peak_idx, numel(t), decay_fractions(i)*peak_amplitude, ...
        'falling', options.PersistenceSamples);
end

dy_dt = gradient(smooth_y, t);
rise_rate_indices = reference_idx:peak_idx;
decay_rate_indices = peak_idx:numel(t);
[max_force_rate, rise_rate_local] = max(dy_dt(rise_rate_indices));
[min_force_rate, decay_rate_local] = min(dy_dt(decay_rate_indices));
max_force_rate_idx = rise_rate_indices(rise_rate_local);
min_force_rate_idx = decay_rate_indices(decay_rate_local);

if isfinite(force_onset_time)
    integration_start = find(t >= force_onset_time, 1, 'first');
else
    integration_start = reference_idx;
end
integration_indices = integration_start:numel(t);
auc_signed = trapz(t(integration_indices), corrected(integration_indices));
auc_positive = trapz(t(integration_indices), ...
    max(corrected(integration_indices), 0));
auc_rise = integrate_interval(t, corrected, force_onset_time, ...
    peak_time_centroid, false);
auc_relaxation = integrate_interval(t, corrected, peak_time_centroid, ...
    t(end), false);
auc_to_relax50 = integrate_interval(t, corrected, force_onset_time, ...
    decay_crossing(2), true);
auc_to_relax90 = integrate_interval(t, corrected, force_onset_time, ...
    decay_crossing(4), true);

m = struct;
m.baseline = baseline;
m.baseline_noise_mad = baseline_noise;
m.peak_amplitude = peak_amplitude;
m.peak_plateau_level = peak_plateau_level;
m.peak_noise_mad = peak_noise;
m.peak_time_centroid = peak_time_centroid;
m.peak_plateau_start = t(peak_band(1));
m.peak_plateau_end = t(peak_band(end));
m.peak_plateau_duration = t(peak_band(end)) - t(peak_band(1));
m.force_onset_time = force_onset_time;
m.force_onset_delay = force_onset_time - options.ReferenceOnsetTime;
m.time_to_peak = peak_time_centroid - force_onset_time;
m.rise_20_time = rise_crossing(2) - force_onset_time;
m.rise_30_time = rise_crossing(3) - force_onset_time;
m.rise_50_time = rise_crossing(4) - force_onset_time;
m.rise_90_time = rise_crossing(5) - force_onset_time;
m.rise_20_to_50 = rise_crossing(4) - rise_crossing(2);
m.rise_50_to_90 = rise_crossing(5) - rise_crossing(4);
m.relaxation_50_time = decay_crossing(2) - peak_time_centroid;
m.relaxation_90_time = decay_crossing(4) - peak_time_centroid;
m.decay_50_from_plateau_end = decay_crossing(2) - t(peak_band(end));
m.decay_90_from_plateau_end = decay_crossing(4) - t(peak_band(end));
m.duration_above_20 = decay_crossing(3) - rise_crossing(2);
m.duration_above_50 = decay_crossing(2) - rise_crossing(4);
m.duration_above_90 = decay_crossing(1) - rise_crossing(5);
m.auc_signed = auc_signed;
m.auc_positive = auc_positive;
m.auc_normalized = auc_positive / peak_amplitude;
m.auc_rise = auc_rise;
m.auc_relaxation = auc_relaxation;
m.relaxation_to_rise_auc_ratio = auc_relaxation / auc_rise;
m.auc_to_relax50 = auc_to_relax50;
m.auc_to_relax50_normalized = auc_to_relax50 / peak_amplitude;
m.auc_to_relax90 = auc_to_relax90;
m.auc_to_relax90_normalized = auc_to_relax90 / peak_amplitude;
m.max_force_rate = max_force_rate;
m.max_force_rate_time = t(max_force_rate_idx);
m.min_force_rate = min_force_rate;
m.min_force_rate_time = t(min_force_rate_idx);
m.signal_to_noise = peak_amplitude / max(baseline_noise, eps);
m.smoothing_samples = smooth_n;
m.reference_onset_time = options.ReferenceOnsetTime;
m.recording_end_time = t(end);
m.integration_duration = t(end) - force_onset_time;
m.missing_relaxation_50 = ~isfinite(decay_crossing(2));
m.missing_relaxation_90 = ~isfinite(decay_crossing(4));
m.low_signal_to_noise = m.signal_to_noise < 5;
m.corrected_signal = corrected;
m.smoothed_signal = smooth_y;
end

function indices = contiguous_peak_band(y, peak_idx, threshold, lower_bound)
left = peak_idx;
while left > lower_bound && y(left-1) >= threshold
    left = left - 1;
end
right = peak_idx;
while right < numel(y) && y(right+1) >= threshold
    right = right + 1;
end
indices = left:right;
end

function crossing_time = sustained_crossing(t, y, first_idx, last_idx, ...
        threshold, direction, persistence)
crossing_time = NaN;
if last_idx <= first_idx
    return;
end
initial_stop = min(last_idx, first_idx + persistence - 1);
if initial_stop - first_idx + 1 == persistence
    if strcmp(direction, 'rising') && ...
            all(y(first_idx:initial_stop) >= threshold)
        crossing_time = t(first_idx);
        return;
    elseif strcmp(direction, 'falling') && ...
            all(y(first_idx:initial_stop) <= threshold)
        crossing_time = t(first_idx);
        return;
    end
end
for idx = (first_idx+1):last_idx
    stop_idx = min(last_idx, idx + persistence - 1);
    if stop_idx - idx + 1 < persistence
        continue;
    end
    if strcmp(direction, 'rising')
        crossed = y(idx-1) < threshold && y(idx) >= threshold;
        persists = all(y(idx:stop_idx) >= threshold);
    else
        crossed = y(idx-1) > threshold && y(idx) <= threshold;
        persists = all(y(idx:stop_idx) <= threshold);
    end
    if crossed && persists
        fraction = (threshold - y(idx-1)) / (y(idx) - y(idx-1));
        crossing_time = t(idx-1) + fraction*(t(idx) - t(idx-1));
        return;
    end
end
end

function area = integrate_interval(t, y, start_time, end_time, positive_only)
if ~isfinite(start_time) || ~isfinite(end_time) || end_time <= start_time
    area = NaN;
    return;
end
inside = t > start_time & t < end_time;
tq = [start_time; t(inside); end_time];
yq = interp1(t, y, tq, 'linear');
if positive_only
    yq = max(yq, 0);
end
area = trapz(tq, yq);
end
