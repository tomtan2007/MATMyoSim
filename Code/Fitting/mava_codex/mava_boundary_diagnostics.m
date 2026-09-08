function D = mava_boundary_diagnostics(parameters)
% Describe optimizer-bound proximity from raw and simulated coordinates.

if isstruct(parameters)
    parameters = num2cell(parameters);
end
if ~iscell(parameters)
    error('mava_boundary_diagnostics:badParameters', ...
        'Parameters must be a cell array or struct array.');
end

n = numel(parameters);
name = strings(n, 1);
p_raw = nan(n, 1);
p_simulated = nan(n, 1);
normalized_distance = nan(n, 1);
physical_distance = nan(n, 1);
log_distance = nan(n, 1);
fold_distance = nan(n, 1);
lower_bound = nan(n, 1);
upper_bound = nan(n, 1);
physical_value = nan(n, 1);
classification = strings(n, 1);

for i = 1:n
    parameter = parameters{i};
    required = {'name','min_value','max_value','p_value'};
    if ~all(isfield(parameter, required))
        error('mava_boundary_diagnostics:badParameter', ...
            'Parameter %d is missing a required field.', i);
    end
    if ~(ischar(parameter.name) || ...
            (isstring(parameter.name) && isscalar(parameter.name))) || ...
            ~isnumeric(parameter.min_value) || ...
            ~isreal(parameter.min_value) || ...
            ~isscalar(parameter.min_value) || ...
            ~isfinite(parameter.min_value) || ...
            ~isnumeric(parameter.max_value) || ...
            ~isreal(parameter.max_value) || ...
            ~isscalar(parameter.max_value) || ...
            ~isfinite(parameter.max_value) || ...
            parameter.max_value <= parameter.min_value || ...
            ~isnumeric(parameter.p_value) || ~isreal(parameter.p_value) || ...
            ~isscalar(parameter.p_value) || ~isfinite(parameter.p_value)
        error('mava_boundary_diagnostics:badParameter', ...
            'Parameter %d has invalid scalar values or unordered bounds.', i);
    end
    name(i) = string(parameter.name);
    if isfield(parameter, 'p_value_raw')
        p_raw(i) = parameter.p_value_raw;
    else
        p_raw(i) = parameter.p_value;
    end
    if ~isnumeric(p_raw(i)) || ~isreal(p_raw(i)) || ...
            ~isscalar(p_raw(i)) || ~isfinite(p_raw(i))
        error('mava_boundary_diagnostics:badParameter', ...
            'Parameter %s has an invalid raw coordinate.', name(i));
    end
    p_simulated(i) = max(0, min(1, p_raw(i)));
    normalized_distance(i) = min(p_simulated(i), 1-p_simulated(i));
    mode = 'linear';
    if isfield(parameter, 'p_mode')
        mode = char(string(parameter.p_mode));
    end
    switch mode
        case 'log'
            lower_bound(i) = 10^parameter.min_value;
            upper_bound(i) = 10^parameter.max_value;
            physical_value(i) = 10^(parameter.min_value + ...
                p_simulated(i)*(parameter.max_value-parameter.min_value));
            log_distance(i) = min( ...
                abs(log10(physical_value(i)/lower_bound(i))), ...
                abs(log10(upper_bound(i)/physical_value(i))));
            fold_distance(i) = 10^log_distance(i);
        case 'linear'
            lower_bound(i) = parameter.min_value;
            upper_bound(i) = parameter.max_value;
            physical_value(i) = parameter.min_value + ...
                p_simulated(i)*(parameter.max_value-parameter.min_value);
            log_distance(i) = NaN;
            fold_distance(i) = NaN;
        otherwise
            error('mava_boundary_diagnostics:badMode', ...
                'Unknown p_mode for %s: %s.', name(i), mode);
    end
    physical_distance(i) = min(abs(physical_value(i)-lower_bound(i)), ...
        abs(upper_bound(i)-physical_value(i)));
    if any(~isfinite([lower_bound(i), upper_bound(i), ...
            physical_value(i), physical_distance(i)]))
        error('mava_boundary_diagnostics:badParameter', ...
            'Parameter %s produces nonfinite physical diagnostics.', name(i));
    end

    if p_raw(i) < 0
        classification(i) = "outside_lower";
    elseif p_raw(i) > 1
        classification(i) = "outside_upper";
    elseif p_raw(i) <= 0.02
        classification(i) = "near_lower";
    elseif p_raw(i) >= 0.98
        classification(i) = "near_upper";
    else
        classification(i) = "interior";
    end
end

D = table(name, p_raw, p_simulated, normalized_distance, ...
    physical_distance, log_distance, fold_distance, lower_bound, ...
    upper_bound, physical_value, classification);
end
