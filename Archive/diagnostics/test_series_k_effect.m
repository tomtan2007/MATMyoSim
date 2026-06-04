% test_series_k_effect.m
% Compares twitch force with series_k_linear=0 vs series_k_linear=100.
% Uses the 3-state control model template (which now has series_k_linear=100).
% A temporary JSON with series_k_linear=0 is created for comparison.
%
% Outputs: series_k_comparison.png in the working directory root.
%
% Usage: /Applications/MATLAB_R2026a.app/bin/matlab -batch "run('test_series_k_effect.m')"
% Run from MATMyoSim root directory.

cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

base_model   = 'code/demos/fitting/twitch_3state_control/sim_input/model_template.json';
protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_3state_control/sim_input/sim_options.json';
tmp_model_k0  = 'code/demos/fitting/twitch_3state_control/temp/model_k0.json';

% --- Build a k=0 version by modifying the template JSON ---
m = loadjson(base_model);
m.MyoSim_model.muscle_props.series_k_linear = 0;
out_str = savejson('MyoSim_model', m.MyoSim_model);
out_str = strrep(out_str, '\/', '/');
fid = fopen(tmp_model_k0, 'w');
fprintf(fid, '%s', out_str);
fclose(fid);

fprintf('Running simulation with series_k_linear = 0 ...\n');
sim0 = simulation_driver( ...
    'model_json_file_string',          tmp_model_k0, ...
    'simulation_protocol_file_string', protocol_file, ...
    'options_json_file_string',        options_file);

fprintf('Running simulation with series_k_linear = 100 ...\n');
sim100 = simulation_driver( ...
    'model_json_file_string',          base_model, ...
    'simulation_protocol_file_string', protocol_file, ...
    'options_json_file_string',        options_file);

peak0   = max(sim0.muscle_force);
peak100 = max(sim100.muscle_force);

fprintf('\n=== SERIES COMPLIANCE EFFECT ===\n');
fprintf('Peak force (series_k_linear = 0):   %.1f N/m^2\n', peak0);
fprintf('Peak force (series_k_linear = 100): %.1f N/m^2\n', peak100);
fprintf('Difference: %.1f N/m^2  (%.1f%%)\n', peak100 - peak0, ...
    100*(peak100 - peak0)/max(peak0, 1e-9));

% --- Plot ---
fig = figure('Position', [100 100 900 500], 'Color', 'w', 'Visible', 'off');
hold on;
plot(sim0.time_s,   sim0.muscle_force,   'b-',  'LineWidth', 2, ...
    'DisplayName', sprintf('k\\_linear=0  (peak=%.0f)', peak0));
plot(sim100.time_s, sim100.muscle_force, 'r--', 'LineWidth', 2, ...
    'DisplayName', sprintf('k\\_linear=100 (peak=%.0f)', peak100));
xlabel('Time (s)');
ylabel('Force (N/m^2)');
title('Effect of series compliance on twitch force (3-state control)');
legend('Location', 'best');
grid on;

out_png = 'series_k_comparison.png';
exportgraphics(fig, out_png, 'Resolution', 150);
fprintf('Saved: %s\n', out_png);
close(fig);

% Clean up temp file
delete(tmp_model_k0);
