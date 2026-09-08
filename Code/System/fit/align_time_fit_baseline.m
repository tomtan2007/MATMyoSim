function [aligned_signal, baseline_idx, signal_baseline, target_baseline] = ...
    align_time_fit_baseline(signal, target, first_active)
% Align a model signal to the target over the shared late-passive window.

if isempty(signal) || ~isvector(signal) || isempty(target) || ~isvector(target)
    error('align_time_fit_baseline:badSignal', ...
        'Signal and target must be nonempty vectors.');
end
if numel(signal) ~= numel(target)
    error('align_time_fit_baseline:lengthMismatch', ...
        'Signal and target must have the same number of samples.');
end

signal = signal(:);
target = target(:);
first_active = resolve_time_fit_start_index(target, first_active);

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
