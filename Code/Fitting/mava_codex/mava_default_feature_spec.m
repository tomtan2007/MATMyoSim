function spec = mava_default_feature_spec(target)
% Default prototype feature set and tolerances for twitch fitting.
%
% Scales are 10% of the target value with an absolute timing floor. They
% are explicit provisional tolerances, not estimates of population SD.
% Replace them with population variability when individual-cell data exist.

definitions = { ...
    'peak_amplitude',                 0; ...
    'force_onset_delay',          0.0321; ...
    'rise_20_to_50',              0.0321; ...
    'time_to_peak',               0.020; ...
    'duration_above_50',          0.030; ...
    'peak_plateau_duration',      0.0321; ...
    'relaxation_50_time',         0.030; ...
    'relaxation_90_time',         0.050; ...
    'auc_normalized',             0.020};

spec = repmat(struct('name', '', 'scale', NaN, 'weight', 1), ...
    size(definitions, 1), 1);
for i = 1:size(definitions, 1)
    name = definitions{i, 1};
    floor_value = definitions{i, 2};
    target_value = target.(name);
    if strcmp(name, 'peak_amplitude')
        scale = max(0.10*abs(target_value), eps);
    elseif isfinite(target_value)
        scale = max(0.10*abs(target_value), floor_value);
    else
        scale = NaN;
    end
    spec(i) = struct('name', name, 'scale', scale, 'weight', 1);
end
end
