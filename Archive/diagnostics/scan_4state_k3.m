% scan_4state_k3.m — Scan high k_3 values to understand force plateau vs shape
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_4state_control/sim_input/sim_options.json';
target_file   = 'code/demos/fitting/twitch_4state_control/target/Con_target.txt';
template_file = 'code/demos/fitting/twitch_4state_control/sim_input/model_template.json';

target = dlmread(target_file);
n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
t_axis = (0:n-1)' * 0.001;

model_struct = loadjson(template_file);

% Use 3-state control best fit params as base
model_struct.MyoSim_model.hs_props.parameters.k_1 = 3.67;
model_struct.MyoSim_model.hs_props.parameters.k_2 = 36.7;
model_struct.MyoSim_model.hs_props.parameters.k_on = 1.1e6;
model_struct.MyoSim_model.hs_props.parameters.k_off = 10.4;
model_struct.MyoSim_model.hs_props.parameters.k_coop = 1.35;

% Scan k_3 at fixed k_5_0, k_7_0
k3_vals = [69, 200, 600, 1000, 2000];
k5_vals = [1, 5, 10, 50, 100];  % also vary k_5_0

fig = figure('Position', [100 100 1400 900], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 3, 'DisplayName', 'Control target');
clrs = lines(numel(k3_vals) * numel(k5_vals));
ci = 0;

fprintf('k_3\t k_5_0\t peak\t time_to_peak\t fall_at_end\n');

for ik3 = 1:numel(k3_vals)
    k3 = k3_vals(ik3);
    for ik5 = 1:numel(k5_vals)
        k5 = k5_vals(ik5);
        ci = ci + 1;

        model_struct.MyoSim_model.hs_props.parameters.k_3 = k3;
        model_struct.MyoSim_model.hs_props.parameters.k_5_0 = k5;
        model_struct.MyoSim_model.hs_props.parameters.k_7_0 = 50;  % fixed mid

        tmp_file = 'temp_scan_k3.json';
        of = fopen(tmp_file, 'w');
        fprintf(of, '%s', savejson('MyoSim_model', model_struct.MyoSim_model));
        fclose(of);

        try
            sim = simulation_driver( ...
                'model_json_file_string', tmp_file, ...
                'simulation_protocol_file_string', protocol_file, ...
                'options_json_file_string', options_file);
            f = sim.muscle_force(end-n+1:end);
            late = round(0.5*first_active):first_active-1;
            if numel(late) < 2, late = 1:max(1,first_active-1); end
            f_shifted = f - mean(f(late)) + mean(target(late));

            [pk, pki] = max(f_shifted);
            last10 = f_shifted(round(end*0.85):end);
            fall = mean(last10) < 0.5 * pk;
            t2pk = t_axis(pki);

            fprintf('k_3=%4.0f k_5_0=%4.0f: peak=%5.0f t2pk=%.3f fall=%d\n', ...
                k3, k5, pk, t2pk, fall);

            if fall && pk > 2000
                lbl = sprintf('k3=%.0f k5=%.0f (peak=%.0f)', k3, k5, pk);
                plot(t_axis, f_shifted, '-', 'LineWidth', 1.5, 'Color', clrs(ci,:), ...
                    'DisplayName', lbl);
            end
        catch ME
            fprintf('k_3=%4.0f k_5_0=%4.0f: ERROR %s\n', k3, k5, ME.message);
        end
    end
end

xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state k\_3 vs k\_5\_0 scan (k\_7\_0=50, showing shape\_ok only)');
legend('Location', 'best', 'FontSize', 7); grid on;
exportgraphics(fig, 'scan_4state_k3.png', 'Resolution', 150);
fprintf('Saved scan_4state_k3.png\n');
if isfile('temp_scan_k3.json'), delete('temp_scan_k3.json'); end
