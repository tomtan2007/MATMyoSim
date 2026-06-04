% Debug: plot 3-state and 4-state best control fits vs target
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_3state_control/sim_input/sim_options.json';
target_file   = 'code/demos/fitting/twitch_3state_control/target/Con_target.txt';
target = dlmread(target_file);

models = struct( ...
    'label', {'3-state', '4-state', '6-state'}, ...
    'file',  { ...
        'code/demos/fitting/twitch_3state_control/temp/best/model_best.json', ...
        'code/demos/fitting/twitch_4state_control/temp/best/model_best.json', ...
        'code/demos/fitting/twitch_6state_control/temp/best/model_best.json'}, ...
    'color', {[0.8 0.2 0.2], [0.1 0.5 0.9], [0.1 0.7 0.3]});

n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max-t_min), 1, 'first');

fig = figure('Position',[100 100 900 500],'Color','w','Visible','off');
hold on;
t_axis = (0:n-1)' * 0.001;
plot(t_axis, target, 'k-', 'LineWidth', 2, 'DisplayName', 'Control target');
xline(t_axis(first_active), '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'Ca onset');

for i = 1:numel(models)
    m = models(i);
    sim = simulation_driver( ...
        'model_json_file_string',          m.file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string',        options_file);
    f = sim.muscle_force(end-n+1:end);
    passive_idx = 1:(first_active-1);
    late = passive_idx(max(1,round(0.5*end)):end);
    f_shifted = f - mean(f(late)) + mean(target(late));
    plot(t_axis, f_shifted, '-', 'LineWidth', 1.5, 'Color', m.color, ...
         'DisplayName', m.label);
    fprintf('%s: peak sim = %.0f, peak target = %.0f\n', ...
        m.label, max(f_shifted), max(target));
end

xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('Control fits vs target — debug comparison');
legend('Location','best'); grid on;
exportgraphics(fig, 'debug_control_comparison.png', 'Resolution', 150);
fprintf('Saved debug_control_comparison.png\n');
