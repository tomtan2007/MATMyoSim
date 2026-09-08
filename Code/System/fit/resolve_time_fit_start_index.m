function [first_active, target_range] = ...
    resolve_time_fit_start_index(target_data, fit_start_index)
% Resolve the scored time-fit window and its target normalization range.

if isempty(target_data) || ~isvector(target_data) || ...
        ~isnumeric(target_data) || ~isreal(target_data) || ...
        any(~isfinite(target_data(:)))
    error('resolve_time_fit_start_index:badTarget', ...
        'target_data must be a finite real numeric vector.');
end

target_data = target_data(:);
if isempty(fit_start_index)
    full_range = max(target_data) - min(target_data);
    threshold = min(target_data) + 0.05 * full_range;
    first_active = find(target_data > threshold, 1, 'first');
    if isempty(first_active) || first_active < 2
        first_active = 1;
    end
else
    if ~isnumeric(fit_start_index) || ~isreal(fit_start_index) || ...
            ~isscalar(fit_start_index) || ~isfinite(fit_start_index)
        error('resolve_time_fit_start_index:badFitStartIndex', ...
            'fit_start_index must identify one target sample.');
    end
    first_active = round(fit_start_index);
    if first_active < 1 || first_active > numel(target_data)
        error('resolve_time_fit_start_index:badFitStartIndex', ...
            'fit_start_index must identify one target sample.');
    end
end

scored_target = target_data(first_active:end);
target_range = max(scored_target) - min(scored_target);
end
