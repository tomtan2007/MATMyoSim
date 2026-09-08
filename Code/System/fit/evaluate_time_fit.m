function [e, y_attempt, y_window_bs] = ...
    evaluate_time_fit(sim_output,target_data,varargin)

p = inputParser;
p.addParamValue('figure_time_fit',0);
p.addParamValue('fit_variable','muscle_force');
p.addParamValue('fit_start_index',[]);
parse(p,varargin{:});
p = p.Results;

% Pull off appropriate variable
switch p.fit_variable
    case 'muscle_force'
        y_attempt = sim_output.muscle_force;
    otherwise
        error('Invalid fit_variable');
end

% Baseline-shift sim to match passive level; compute error over active region only
target_data_scored = target_data(:);
[first_active, target_range] = resolve_time_fit_start_index( ...
    target_data_scored, p.fit_start_index);
if ~(isfinite(target_range) && target_range > 0)
    error('evaluate_time_fit:noTargetRange', ...
        'Scored target_data has no finite range.');
end
y_window = y_attempt(end-numel(target_data_scored)+1:end);
y_window_bs = align_time_fit_baseline( ...
    y_window, target_data_scored, first_active);

active_idx = first_active:numel(target_data_scored);
n_active   = numel(active_idx);

e = sum(((y_window_bs(active_idx) - target_data_scored(active_idx))./ ...
            target_range).^2) / n_active;

% Plot result
if (p.figure_time_fit)
    figure(p.figure_time_fit);
    clf;
    hold on;
    plot(sim_output.time_s(end-numel(target_data_scored)+1:end), ...
        target_data_scored, 'k-');
    plot(sim_output.time_s,y_attempt,'b-');
    drawnow;
end
