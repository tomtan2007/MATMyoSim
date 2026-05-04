function demo_twitch_1
% Function illustrates how to run a simulation of a single-half-sarcomere
% held isometric and activated by a transient pulse of Ca2+

% Variables
protocol_file_string = 'protocol_1s.txt';
model_parameters_json_file_string = 'twitch_1_model.json';
options_file_string = 'twitch_1_options.json';
model_output_file_string = fullfile('..', '..', 'temp', 'twitch_1_output.myo');

% Make sure the path allows us to find the right files
script_dir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(script_dir, '..', '..', '..', '..', 'code')));

% Run a simulation
sim_output = simulation_driver( ...
    'simulation_protocol_file_string', protocol_file_string, ...
    'model_json_file_string', model_parameters_json_file_string, ...
    'options_json_file_string', options_file_string, ...
    'output_file_string', model_output_file_string);

% Load it back up and display to show how that can be done
sim = load(model_output_file_string,'-mat')
sim_output = sim.sim_output

figure(3);
clf;
subplot(3,1,1);
plot(sim_output.time_s,sim_output.muscle_force,'b-');
ylabel('Force (N m^{-2})');
subplot(3,1,2);
plot(sim_output.time_s,sim_output.hs_length,'b-');
ylabel('Half-sarcomere length (nm)');
subplot(3,1,3);
plot(sim_output.time_s,sim_output.M1,'b-');
ylabel('Myosin in SRX (M_{OFF})');
max(sim_output.M1)
max(sim_output.M2)
max(sim_output.M3)
max(sim_output.M4)

