% check_srx_with_rest.m
% Test SRX equilibration with the protocol_1s_with_rest.txt
% (200 rows pCa=9 prepended before the main 1486-row protocol)
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

model_file    = 'code/demos/fitting/twitch_3state_control/sim_input/model_template.json';
protocol_orig = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
protocol_rest = 'code/demos/twitches/twitch_1/protocols/protocol_1s_with_rest.txt';
options_file  = 'code/demos/fitting/twitch_3state_control/sim_input/sim_options.json';

fprintf('=== Original protocol (no rest) ===\n');
sim1 = simulation_driver( ...
    'model_json_file_string', model_file, ...
    'simulation_protocol_file_string', protocol_orig, ...
    'options_json_file_string', options_file);
M1_orig = sim1.M1(:,1);
fprintf('M1 at t=0:      %.6f\n', M1_orig(1));
fprintf('M1 at row 352:  %.6f\n', M1_orig(352));
fprintf('M1 minimum:     %.6f\n', min(M1_orig));
fprintf('Drift (0->352): %.1f%%\n', 100*(M1_orig(352)-M1_orig(1))/M1_orig(1));

fprintf('\n=== With-rest protocol (200 rows pCa=9 prepended) ===\n');
sim2 = simulation_driver( ...
    'model_json_file_string', model_file, ...
    'simulation_protocol_file_string', protocol_rest, ...
    'options_json_file_string', options_file);
M1_rest = sim2.M1(:,1);
fprintf('M1 at t=0 (pCa=9):          %.6f\n', M1_rest(1));
fprintf('M1 at end of rest (row 200): %.6f\n', M1_rest(200));
fprintf('M1 at start of protocol (row 201+352=553): %.6f\n', M1_rest(min(553, end)));
fprintf('M1 minimum:                  %.6f\n', min(M1_rest));
fprintf('Drift (rest start->end): %.1f%%\n', 100*(M1_rest(200)-M1_rest(1))/M1_rest(1));
