function recompute_error
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, '..', '..', '..', '..', 'code')));

opt = loadjson('optimization.json');
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;
p_vec = [0.000 0.301 0.157 0.260 1.000 0.914 0.881 0.195 0.509 0.852 0.827 0.225];
update_json_model_file(opt_structure, 1, p_vec, {});

sim_output = simulation_driver( ...
    'model_json_file_string',          'temp/model_worker.json', ...
    'simulation_protocol_file_string', opt_structure.job{1}.protocol_file_string, ...
    'options_json_file_string',        opt_structure.job{1}.options_file_string);

target = dlmread('target/H251N_target.txt');
[e, ~] = evaluate_time_fit(sim_output, target, 'fit_variable', 'muscle_force');
fprintf('Recomputed e = %.6f\n', e);
fprintf('target min=%.3f max=%.3f range=%.3f n=%d\n', ...
    min(target), max(target), max(target)-min(target), numel(target));
end
