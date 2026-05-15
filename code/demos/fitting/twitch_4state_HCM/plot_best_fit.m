function plot_best_fit
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, '..', '..', '..', '..', 'code')));

opt = loadjson('optimization.json');
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;

p_vec = [0.729 0.299 0.000 0.658 1.000];
update_json_model_file(opt_structure, 1, p_vec, {});

sim_output = simulation_driver( ...
    'model_json_file_string',          'temp/model_worker.json', ...
    'simulation_protocol_file_string', opt_structure.job{1}.protocol_file_string, ...
    'options_json_file_string',        opt_structure.job{1}.options_file_string);

target = dlmread('target/H251N_target.txt');
n = numel(target);
t_sim = sim_output.time_s(end-n+1:end);
f_sim = sim_output.muscle_force(end-n+1:end);

target_min = min(target); target_max = max(target);
first_active = find(target > target_min + 0.05*(target_max - target_min), 1, 'first');
if isempty(first_active) || first_active < 2
    bl_y = f_sim(1); bl_t = target(1);
else
    passive_idx = 1:(first_active-1);
    late = passive_idx(round(0.5*end):end);
    bl_y = mean(f_sim(late)); bl_t = mean(target(late));
end
f_sim_shifted = f_sim - bl_y + bl_t;

fig = figure('Position', [100 100 900 500], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_sim, target, 'k-', 'LineWidth', 2, 'DisplayName', 'H251N target');
plot(t_sim, f_sim_shifted, 'r-', 'LineWidth', 1.5, 'DisplayName', '4-state fit (e=0.0077)');
xline(t_sim(first_active), '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'Ca onset');
xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state HCM fit vs H251N target');
legend('Location', 'best'); grid on;

out_path = fullfile(cd, 'best_4state_HCM_fit.png');
exportgraphics(fig, out_path, 'Resolution', 150);
fprintf('Saved %s\n', out_path);
fprintf('sim peak: %.2f at t=%.3f s\n', max(f_sim), t_sim(find(f_sim==max(f_sim),1)));
end
