function [e, y_attempt, details, target_metrics, model_metrics] = ...
    evaluate_mava_feature_fit(sim_output, target_data, varargin)
% Compare a simulated twitch with a target using interpretable features.

p = inputParser;
addParameter(p, 'fit_variable', 'muscle_force');
addParameter(p, 'fit_start_index', []);
addParameter(p, 'feature_spec', []);
parse(p, varargin{:});
options = p.Results;

if ~strcmp(options.fit_variable, 'muscle_force')
    error('evaluate_mava_feature_fit:badVariable', ...
        'Feature fitting currently supports muscle_force only.');
end
target_data = target_data(:);
n_target = numel(target_data);
y_attempt = sim_output.muscle_force(:);
if numel(y_attempt) < n_target || numel(sim_output.time_s) < n_target
    error('evaluate_mava_feature_fit:shortSimulation', ...
        'Simulation is shorter than the target trace.');
end

t = sim_output.time_s(end-n_target+1:end);
y_window = y_attempt(end-n_target+1:end);
[reference_idx, ~] = resolve_time_fit_start_index( ...
    target_data, options.fit_start_index);
if reference_idx < 2
    error('evaluate_mava_feature_fit:noBaseline', ...
        'Feature fitting requires samples before the reference onset.');
end
baseline_start = max(1, reference_idx-50);
baseline_indices = baseline_start:(reference_idx-1);
reference_time = t(reference_idx);
y_aligned = align_time_fit_baseline(y_window, target_data, reference_idx);

metric_options = {'ReferenceOnsetTime', reference_time, ...
    'BaselineIndices', baseline_indices};
target_metrics = mava_feature_metrics(t, target_data, metric_options{:});
try
    model_metrics = mava_feature_metrics(t, y_aligned, metric_options{:});
catch ME
    if startsWith(ME.identifier, 'mava_feature_metrics:')
        model_metrics = target_metrics;
        names = fieldnames(model_metrics);
        for i = 1:numel(names)
            if isnumeric(model_metrics.(names{i})) && isscalar(model_metrics.(names{i}))
                model_metrics.(names{i}) = NaN;
            end
        end
    else
        rethrow(ME);
    end
end

spec = options.feature_spec;
if isempty(spec)
    spec = mava_default_feature_spec(target_metrics);
end
[e, details] = mava_feature_score(target_metrics, model_metrics, spec);
end
