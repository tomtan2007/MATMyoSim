% Quick plot of current 6-state control best fit
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_6state_control/sim_input/sim_options.json';
target_file   = 'code/demos/fitting/twitch_6state_control/target/Con_target.txt';

target = dlmread(target_file);
n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
t_axis = (0:n-1)' * 0.001;

model_file = 'code/demos/fitting/twitch_6state_control/temp/best/model_best.json';
sim = simulation_driver( ...
    'model_json_file_string', model_file, ...
    'simulation_protocol_file_string', protocol_file, ...
    'options_json_file_string', options_file);
f = sim.muscle_force(end-n+1:end);
late = round(0.5*first_active):first_active-1;
if numel(late)<2, late=1:max(1,first_active-1); end
f_shifted = f - mean(f(late)) + mean(target(late));

fig = figure('Position', [100 100 900 500], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Control target');
plot(t_axis, f_shifted, 'g-', 'LineWidth', 1.5, 'DisplayName', '6-state best (e~0.037)');
xline(t_axis(first_active), '--', 'Color', [0.5 0.5 0.5]);
xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('6-state control best fit (k\_5\_0=999, series\_k=100)');
legend; grid on;
exportgraphics(fig, 'current_6state_control_fit.png', 'Resolution', 150);
fprintf('Saved\n');
