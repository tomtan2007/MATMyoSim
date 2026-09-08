function [aligned_signal, baseline_idx, signal_baseline, target_baseline] = ...
    align_time_fit_baseline(signal, target, first_active)
% Align a model signal to the target over the shared late-passive window.

if numel(signal) ~= numel(target)
    error('align_time_fit_baseline:lengthMismatch', ...
        'Signal and target must have the same number of samples.');
end
if ~isscalar(first_active) || ~isfinite(first_active)
    error('align_time_fit_baseline:badFirstActive', ...
        'first_active must identify one signal sample.');
end

first_active = round(first_active);
if first_active < 1 || first_active > numel(signal)
    error('align_time_fit_baseline:badFirstActive', ...
        'first_active must identify one signal sample.');
end

if first_active < 2
    baseline_idx = 1;
else
    passive_idx = 1:(first_active - 1);
    if numel(passive_idx) > 5
        baseline_idx = passive_idx( ...
            round(0.5 * numel(passive_idx)):end);
    else
        baseline_idx = passive_idx;
    end
end

signal_baseline = mean(signal(baseline_idx));
target_baseline = mean(target(baseline_idx));
aligned_signal = signal - signal_baseline + target_baseline;
end
