% series_k_comparison_fitted.m
% Compare series_k_linear=0 vs 100 using the FITTED 3-state control model
% (the only control model with a good fit so far).
% Shows how the series compliance changes the force magnitude.

cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_3state_control/sim_input/sim_options.json';
target_file   = 'code/demos/fitting/twitch_3state_control/target/Con_target.txt';
best_model    = 'code/demos/fitting/twitch_3state_control/temp/best/model_best.json';

target = dlmread(target_file);
n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
t_axis = (0:n-1)' * 0.001;

k_vals = [0, 1, 5, 10, 50, 100];
colors_rgb = [0 0.6 0; 0 0.5 1; 0.8 0.3 0; 0.6 0 0.6; 0.5 0.5 0; 1 0.5 0];

fprintf('series_k\tpeak_force\tpeak_force/target_peak\n');

model_struct = loadjson(best_model);

fig = figure('Position', [100 100 1200 700], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 3, 'DisplayName', 'Control target (4368 N/m²)');

forces = struct();
for ik = 1:numel(k_vals)
    kv = k_vals(ik);
    model_struct.MyoSim_model.muscle_props.series_k_linear = kv;

    tmp = sprintf('temp_skcomp_%d.json', ik);
    of = fopen(tmp, 'w');
    fprintf(of, '%s', savejson('MyoSim_model', model_struct.MyoSim_model));
    fclose(of);

    try
        sim = simulation_driver( ...
            'model_json_file_string', tmp, ...
            'simulation_protocol_file_string', protocol_file, ...
            'options_json_file_string', options_file);
        f = sim.muscle_force(end-n+1:end);
        late = round(0.5*first_active):first_active-1;
        if numel(late)<2, late=1:max(1,first_active-1); end
        f_shifted = f - mean(f(late)) + mean(target(late));

        [pk, ~] = max(f_shifted);
        pct = pk / t_max * 100;
        fprintf('k=%-4.0f\t%.0f\t\t%.1f%%\n', kv, pk, pct);
        forces.(sprintf('k_%d', kv)) = f_shifted;

        lbl = sprintf('k=%.0f (peak=%.0f N/m², %.1f%%)', kv, pk, pct);
        plot(t_axis, f_shifted, '-', 'LineWidth', 1.5, 'Color', colors_rgb(ik,:), ...
            'DisplayName', lbl);
    catch ME
        fprintf('k=%-4.0f: ERROR %s\n', kv, ME.message);
    end
    if isfile(tmp), delete(tmp); end
end

xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('3-state control fitted model: effect of series\_k\_linear');
legend('Location', 'best', 'FontSize', 8); grid on;
ylim([-500 5000]);
exportgraphics(fig, 'series_k_comparison_fitted.png', 'Resolution', 150);
fprintf('\nSaved series_k_comparison_fitted.png\n');
