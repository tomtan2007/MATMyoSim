% scan_4state_highk7.m — Scan high k_7_0 to find where force falls properly
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
model_struct.MyoSim_model.hs_props.parameters.k_1 = 3.67;
model_struct.MyoSim_model.hs_props.parameters.k_2 = 36.7;
model_struct.MyoSim_model.hs_props.parameters.k_3 = 600;  % high to get enough force
model_struct.MyoSim_model.hs_props.parameters.k_5_0 = 100;  % keep high
model_struct.MyoSim_model.hs_props.parameters.k_on = 1.1e6;
model_struct.MyoSim_model.hs_props.parameters.k_off = 10.4;
model_struct.MyoSim_model.hs_props.parameters.k_coop = 1.35;

k7_vals = [50, 200, 500, 1000, 2000, 5000];

fig = figure('Position', [100 100 1200 700], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 3, 'DisplayName', 'Control target');
clrs = hsv(numel(k7_vals));

fprintf('k_7_0\t peak\t t2pk\t val_at_1.3s\t fall_ok\n');

for ik7 = 1:numel(k7_vals)
    k7 = k7_vals(ik7);
    model_struct.MyoSim_model.hs_props.parameters.k_7_0 = k7;

    tmp_file = 'temp_scan_hk7.json';
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
        idx_1p3 = round(1.3/0.001);  % index at t=1.3s
        if idx_1p3 > n, idx_1p3 = n; end
        val_1p3 = f_shifted(idx_1p3);
        fall_ok = val_1p3 < 0.3 * pk;
        t2pk = t_axis(pki);

        fprintf('k_7_0=%5.0f: peak=%5.0f t2pk=%.3f val_1.3s=%5.0f fall=%d\n', ...
            k7, pk, t2pk, val_1p3, fall_ok);

        lbl = sprintf('k7=%.0f (pk=%.0f, fall=%d)', k7, pk, fall_ok);
        plot(t_axis, f_shifted, '-', 'LineWidth', 1.5, 'Color', clrs(ik7,:), 'DisplayName', lbl);
    catch ME
        fprintf('k_7_0=%5.0f: ERROR %s\n', k7, ME.message);
    end
end

xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state high k\_7\_0 scan (k\_3=600, k\_5\_0=100)');
legend('Location', 'best', 'FontSize', 7); grid on;
exportgraphics(fig, 'scan_4state_highk7.png', 'Resolution', 150);
fprintf('Saved scan_4state_highk7.png\n');
if isfile('temp_scan_hk7.json'), delete('temp_scan_hk7.json'); end
