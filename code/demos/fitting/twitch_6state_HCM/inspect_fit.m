function inspect_fit
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

f = sim_output.muscle_force;
target = dlmread('target/H251N_target.txt');
fprintf('sim length: %d, target length: %d\n', numel(f), numel(target));
fprintf('sim force: min=%.2f max=%.2f mean=%.2f\n', min(f), max(f), mean(f));
fprintf('sim force in passive (rows 1-352): min=%.2f max=%.2f\n', ...
    min(f(1:352)), max(f(1:352)));
fprintf('sim force in active (rows 353-end): min=%.2f max=%.2f\n', ...
    min(f(353:end)), max(f(353:end)));
fprintf('target peak: %.2f at row %d\n', max(target), find(target==max(target),1));
fprintf('sim peak: %.2f at row %d\n', max(f), find(f==max(f),1));

% Try also cb_force / hs_force
if isfield(sim_output, 'hs_force')
    fprintf('hs_force: min=%.2f max=%.2f\n', min(sim_output.hs_force), max(sim_output.hs_force));
end
if isfield(sim_output, 'cb_force')
    fprintf('cb_force: min=%.2f max=%.2f\n', min(sim_output.cb_force), max(sim_output.cb_force));
end
end
