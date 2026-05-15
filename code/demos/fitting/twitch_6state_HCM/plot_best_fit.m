function plot_best_fit
% Reconstruct best 6-state fit (from eval log) and plot vs H251N target.

cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, '..', '..', '..', '..', 'code')));

opt = loadjson('optimization.json');
opt_structure = opt.MyoSim_optimization;

% best p-vector from eval log: e=0.0509
p_vec = [0.000 0.301 0.157 0.260 1.000 0.914 0.881 0.195 0.509 0.852 0.827 0.225];

% Build the model worker file from template + p-vector
opt_structure.job{1}.model_file_string = 'temp/model_worker.json';
opt_structure.model_working_file_string = 'temp/model_worker.json';
update_json_model_file(opt_structure, 1, p_vec, {});

% Run simulation
sim_output = simulation_driver( ...
    'model_json_file_string',          'temp/model_worker.json', ...
    'simulation_protocol_file_string', opt_structure.job{1}.protocol_file_string, ...
    'options_json_file_string',        opt_structure.job{1}.options_file_string);

% Load target
target = dlmread('target/H251N_target.txt');

% Match lengths: target has 1486 rows, simulation should also (or use last n)
n = numel(target);
t_sim = sim_output.time_s(end-n+1:end);
f_sim = sim_output.muscle_force(end-n+1:end);

% Compute baseline shift (same logic as evaluate_time_fit)
target_min = min(target); target_max = max(target);
first_active = find(target > target_min + 0.05*(target_max - target_min), 1, 'first');
if isempty(first_active) || first_active < 2
    bl_y = f_sim(1); bl_t = target(1);
else
    passive_idx = 1:(first_active-1);
    if numel(passive_idx) > 5
        late = passive_idx(round(0.5*end):end);
        bl_y = mean(f_sim(late)); bl_t = mean(target(late));
    else
        bl_y = mean(f_sim(passive_idx)); bl_t = mean(target(passive_idx));
    end
end
f_sim_shifted = f_sim - bl_y + bl_t;

% Plot
fig = figure('Position', [100 100 900 500], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_sim, target, 'k-', 'LineWidth', 2, 'DisplayName', 'H251N target');
plot(t_sim, f_sim_shifted, 'b-', 'LineWidth', 1.5, 'DisplayName', '6-state fit (e=0.051)');
xline(t_sim(first_active), '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'Ca onset');
xlabel('Time (s)');
ylabel('Force (N/m^2)');
title('6-state HCM fit vs H251N target');
legend('Location', 'best');
grid on;

out_path = fullfile(cd, 'best_6state_HCM_fit.png');
exportgraphics(fig, out_path, 'Resolution', 150);
fprintf('Saved figure to %s\n', out_path);
end
