function m = mava_waveform_metrics(t, y, onset_idx, baseline_mode, varargin)
% Consistent twitch metrics for pre-zeroed targets and raw model force.

p = inputParser;
addParameter(p, 'calcium_onset_time', NaN);
addParameter(p, 'target', []);
addParameter(p, 'fit_start_index', onset_idx);
parse(p, varargin{:});
options = p.Results;

t = t(:); y = y(:);
if numel(t) ~= numel(y)
    error('mava_waveform_metrics:lengthMismatch', 'Time and signal lengths differ.');
end
if onset_idx < 2 || onset_idx > numel(y)
    error('mava_waveform_metrics:badOnset', 'Invalid onset index.');
end
target = options.target(:);
if ~isempty(target) && numel(target) ~= numel(y)
    error('mava_waveform_metrics:targetLengthMismatch', ...
        'Target and signal lengths differ.');
end

switch baseline_mode
    case 'prezeroed'
        corrected = y;
    case 'model'
        if isempty(target)
            baseline_target = zeros(size(y));
        else
            baseline_target = target;
        end
        corrected = align_time_fit_baseline( ...
            y, baseline_target, options.fit_start_index);
    otherwise
        error('mava_waveform_metrics:badBaselineMode', ...
            'Unknown baseline mode: %s', baseline_mode);
end

active = onset_idx:numel(corrected);
[m.peak, rel_peak] = max(corrected(active));
m.peak_index = active(rel_peak);
m.time_to_peak_argmax = t(m.peak_index) - t(onset_idx);
near_peak = active(corrected(active) >= 0.95*m.peak);
m.time_to_peak_centroid = mean(t(near_peak)) - t(onset_idx);

threshold = 0.05*m.peak;
rise_samples = onset_idx:m.peak_index;
if numel(rise_samples) < 2
    rise_idx = [];
else
    pairs = corrected(rise_samples(1:end-1)) >= threshold & ...
        corrected(rise_samples(2:end)) >= threshold;
    first_pair = find(pairs, 1, 'first');
    if isempty(first_pair)
        rise_idx = [];
    else
        rise_idx = rise_samples(first_pair);
    end
end
if isempty(rise_idx)
    m.force_rise_time = NaN;
else
    m.force_rise_time = t(rise_idx);
end
if isfinite(options.calcium_onset_time)
    m.calcium_to_force_lag = m.force_rise_time - ...
        options.calcium_onset_time;
else
    m.calcium_to_force_lag = NaN;
end

half = 0.5*m.peak;
right = find(corrected(m.peak_index:end) <= half, 1, 'first');
if isempty(right)
    m.relax_half_time = NaN;
    right_idx = numel(corrected);
else
    right_idx = m.peak_index + right - 1;
    m.relax_half_time = t(right_idx) - t(m.peak_index);
end
left_idx = find(corrected(1:m.peak_index) <= half, 1, 'last');
if isempty(left_idx) || isempty(right)
    m.fwhm = NaN;
else
m.fwhm = t(right_idx) - t(left_idx);
end
m.normalized_rmse = NaN;
m.relative_peak_error_signed = NaN;
if ~isempty(options.target)
    [first_scored, target_range] = resolve_time_fit_start_index( ...
        target, options.fit_start_index);
    scored = first_scored:numel(target);
    if target_range <= 0
        error('mava_waveform_metrics:constantTarget', ...
            'Target must vary over the scored window.');
    end
    m.normalized_rmse = sqrt(mean( ...
        (corrected(scored)-target(scored)).^2)) / target_range;
    target_peak = max(target(onset_idx:end));
    if target_peak ~= 0
        m.relative_peak_error_signed = (m.peak-target_peak)/target_peak;
    end
end
m.corrected_signal = corrected;
end
