% test_4state_k0.m — Test 4-state control with series_k_linear=0 (like HCM fits)
% to verify the model CAN produce a twitch with k=0.
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
model_struct.MyoSim_model.muscle_props.series_k_linear = 0;  % isometric
model_struct.MyoSim_model.hs_props.parameters.k_1 = 3.67;
model_struct.MyoSim_model.hs_props.parameters.k_2 = 36.7;
model_struct.MyoSim_model.hs_props.parameters.k_3 = 100;
model_struct.MyoSim_model.hs_props.parameters.k_5_0 = 100;
model_struct.MyoSim_model.hs_props.parameters.k_7_0 = 100;
model_struct.MyoSim_model.hs_props.parameters.k_on = 1.1e6;
model_struct.MyoSim_model.hs_props.parameters.k_off = 10.4;
model_struct.MyoSim_model.hs_props.parameters.k_coop = 1.35;

tmp_file = 'temp_4state_k0.json';
of = fopen(tmp_file, 'w');
fprintf(of, '%s', savejson('MyoSim_model', model_struct.MyoSim_model));
fclose(of);

sim = simulation_driver( ...
    'model_json_file_string', tmp_file, ...
    'simulation_protocol_file_string', protocol_file, ...
    'options_json_file_string', options_file);

f = sim.muscle_force(end-n+1:end);
late = round(0.5*first_active):first_active-1;
if numel(late) < 2, late = 1:max(1,first_active-1); end
f_shifted = f - mean(f(late)) + mean(target(late));

[pk, pki] = max(f_shifted);
last10 = f_shifted(round(end*0.9):end);
fall_ok = mean(last10) < 0.5 * pk;

fprintf('series_k=0: peak=%.0f t2pk=%.3f fall=%d\n', pk, t_axis(pki), fall_ok);

fig = figure('Position', [100 100 900 500], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 2, 'DisplayName', 'Control target');
plot(t_axis, f_shifted, 'b-', 'LineWidth', 1.5, 'DisplayName', '4-state k=0 (k7=100)');
xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state control: series\_k=0 test'); legend; grid on;
exportgraphics(fig, 'test_4state_k0.png', 'Resolution', 150);
fprintf('Saved test_4state_k0.png\n');
if isfile(tmp_file), delete(tmp_file); end
