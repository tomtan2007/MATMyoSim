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

% Sum of squares error for last part of simulation
target_stats = summary_stats(target_data);

if (target_stats.max == target_stats.min)
    error('target_data has no range');
end

% Baseline-shift sim to match passive level; compute error over active region only
y_window = y_attempt(end-target_stats.n+1:end);

if isempty(p.fit_start_index)
    baseline_range = target_stats.min + 0.05 * (target_stats.max - target_stats.min);
    first_active = find(target_data > baseline_range, 1, 'first');
else
    first_active = round(p.fit_start_index);
    if ~isscalar(first_active) || first_active < 1 || first_active > target_stats.n
        error('evaluate_time_fit:badFitStartIndex', ...
            'fit_start_index must be an integer within the target data.');
    end
end

if isempty(first_active) || first_active < 2
    first_active = 1;
end
y_window_bs = align_time_fit_baseline( ...
    y_window, target_data, first_active);

active_idx = first_active:numel(target_data);
n_active   = numel(active_idx);

e = sum(((y_window_bs(active_idx) - target_data(active_idx))./ ...
            (target_stats.max - target_stats.min)).^2) / n_active;

% Plot result
if (p.figure_time_fit)
    figure(p.figure_time_fit);
    clf;
    hold on;
    plot(sim_output.time_s(end-target_stats.n+1:end),target_data,'k-');
    plot(sim_output.time_s,y_attempt,'b-');
    drawnow;
end
