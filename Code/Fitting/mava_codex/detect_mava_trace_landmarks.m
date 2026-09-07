function L = detect_mava_trace_landmarks(t, y)
% Detect the primary peak, pre-contraction trough, and sustained 5%% rise.

if ~iscolumn(t) || ~iscolumn(y) || numel(t) ~= numel(y) || ...
        ~all(isfinite(t)) || ~all(isfinite(y))
    error('detect_mava_trace_landmarks:badInput', ...
        't and y must be equal-length finite column vectors.');
end
if numel(t) < 3 || any(diff(t) <= 0)
    error('detect_mava_trace_landmarks:badTime', ...
        't must contain at least three strictly increasing samples.');
end

primary_indices = find(t >= 0.35 & t <= 1.0);
if isempty(primary_indices)
    error('detect_mava_trace_landmarks:noPrimaryWindow', ...
        'No samples fall in the primary 0.35 to 1.0 s window.');
end
[~, local_peak] = max(y(primary_indices));
peak_idx = primary_indices(local_peak);
peak_time = t(peak_idx);

search = find(t >= max(0.1, peak_time - 0.55) & t <= peak_time - 0.15);
if numel(search) < 3
    error('detect_mava_trace_landmarks:noTroughWindow', ...
        'Insufficient samples before the primary peak.');
end
smooth_y = movmean(y, 3);
[~, local_min] = min(smooth_y(search));
trough_idx = search(local_min);
trough_level = mean(y(max(1, trough_idx-1):min(numel(y), trough_idx+1)));
threshold = trough_level + 0.05*(y(peak_idx) - trough_level);

rise_idx = [];
for k = trough_idx:(peak_idx-1)
    if k + 1 <= numel(y) && all(smooth_y(k:k+1) >= threshold)
        rise_idx = k;
        break;
    end
end
if isempty(rise_idx)
    error('detect_mava_trace_landmarks:noRise', ...
        'Could not detect a sustained pre-peak rise.');
end
baseline_range = trough_idx:max(trough_idx, rise_idx-1);
baseline = mean(y(baseline_range));

L = struct('peak_index', peak_idx, 'trough_index', trough_idx, ...
    'rise_index', rise_idx, 'peak_time', t(peak_idx), ...
    'trough_time', t(trough_idx), 'rise_time', t(rise_idx), ...
    'baseline_value', baseline);
end
