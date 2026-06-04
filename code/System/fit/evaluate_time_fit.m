function [e, y_attempt] = evaluate_time_fit(sim_output,target_data,varargin)

p = inputParser;
p.addParamValue('figure_time_fit',0);
p.addParamValue('fit_variable','muscle_force');
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

baseline_range = target_stats.min + 0.05 * (target_stats.max - target_stats.min);
first_active = find(target_data > baseline_range, 1, 'first');

if isempty(first_active) || first_active < 2
    first_active = 1;
    baseline_y = y_window(1);
    baseline_t = target_data(1);
else
    passive_idx = 1:(first_active-1);
    if numel(passive_idx) > 5
        late_passive = passive_idx(round(0.5*end):end);
        baseline_y = mean(y_window(late_passive));
        baseline_t = mean(target_data(late_passive));
    else
        baseline_y = mean(y_window(passive_idx));
        baseline_t = mean(target_data(passive_idx));
    end
end

y_window_bs = y_window - baseline_y + baseline_t;

active_idx = first_active:numel(target_data);
n_active   = numel(active_idx);

e = sum(((y_window_bs(active_idx) - target_data(active_idx))./ ...
            (target_stats.max - target_stats.min)).^2) / n_active;

% Plot result
if (p.figure_time_fit);
    figure(p.figure_time_fit);
    clf;
    hold on;
    plot(sim_output.time_s(end-target_stats.n+1:end),target_data,'k-');
    plot(sim_output.time_s,y_attempt,'b-');
    drawnow;
end