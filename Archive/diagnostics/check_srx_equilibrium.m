% check_srx_equilibrium.m
% Tests whether M1 (SRX fraction) self-equilibrates during the pre-activation
% passive phase (rows 1-352) before Ca onset at row 353 of protocol_1s.txt.
% Output written to code/demos/fitting/twitch_3state_control/temp/
%
% Usage: /Applications/MATLAB_R2026a.app/bin/matlab -batch "run('check_srx_equilibrium.m')"
% Must be run from MATMyoSim root directory.

cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

model_file   = 'code/demos/fitting/twitch_3state_control/sim_input/model_template.json';
protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_3state_control/sim_input/sim_options.json';
out_dir       = 'code/demos/fitting/twitch_3state_control/temp';

fprintf('Running 3-state control simulation (full protocol)...\n');

sim_output = simulation_driver( ...
    'model_json_file_string',          model_file, ...
    'simulation_protocol_file_string', protocol_file, ...
    'options_json_file_string',        options_file);

% protocol_1s.txt has 1486 rows; Ca onset is at row 353 (index 353)
% M1 is stored in sim_output.M1 (column vector, one value per timestep)
M1_all = sim_output.M1(:, 1);   % first (only) half-sarcomere
n_total = numel(M1_all);

% Row 353 in protocol = index 353 in sim_output
% Pre-activation = rows 1..352  => sim indices 1..352
passive_end = 352;

M1_t0        = M1_all(1);
M1_passive   = M1_all(passive_end);
M1_peak_act  = min(M1_all);     % minimum M1 (peak attachment)

fprintf('\n=== SRX EQUILIBRIUM CHECK (3-state control) ===\n');
fprintf('M1 at t=0 (start):                   %.6f\n', M1_t0);
fprintf('M1 at end of passive phase (row %d): %.6f\n', passive_end, M1_passive);
fprintf('M1 minimum (peak Ca activation):     %.6f\n', M1_peak_act);
fprintf('Change during passive phase:          %.6f (%.3f%%)\n', ...
    M1_passive - M1_t0, 100*(M1_passive - M1_t0)/M1_t0);

if abs(M1_passive - M1_t0) < 0.01
    fprintf('RESULT: M1 is STABLE during passive phase (change < 1%%)\n');
else
    fprintf('RESULT: M1 DRIFTS during passive phase (change >= 1%%)\n');
end

% Save results to text file
out_file = fullfile(out_dir, 'srx_equilibrium_result.txt');
fid = fopen(out_file, 'w');
fprintf(fid, 'SRX Equilibrium Check — 3-state control model\n');
fprintf(fid, 'Date: %s\n\n', datestr(now));
fprintf(fid, 'M1 at t=0 (start):                   %.6f\n', M1_t0);
fprintf(fid, 'M1 at end of passive phase (row %d): %.6f\n', passive_end, M1_passive);
fprintf(fid, 'M1 minimum (peak Ca activation):     %.6f\n', M1_peak_act);
fprintf(fid, 'Change during passive phase:          %.6f (%.3f%%)\n', ...
    M1_passive - M1_t0, 100*(M1_passive - M1_t0)/M1_t0);
fclose(fid);
fprintf('\nResults saved to: %s\n', out_file);
