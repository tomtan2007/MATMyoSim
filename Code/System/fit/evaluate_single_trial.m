function [e, sim_output, y_attempt, target_data] = evaluate_single_trial(varargin)
% Runs one simulation for one fitting job and scores it against target data

p = inputParser;
p.addParamValue('model_json_file_string','');
p.addParamValue('simulation_protocol_file_string','');
p.addParamValue('options_file_string','');
p.addParamValue('fit_mode','fit_in_time_domain');
p.addParamValue('fit_variable','muscle_force');
p.addParamValue('target_data',[]);
p.addParamValue('fit_start_index',[]);
parse(p,varargin{:});
p = p.Results;

sim_output = simulation_driver( ...
    'model_json_file_string', p.model_json_file_string, ...
    'simulation_protocol_file_string', p.simulation_protocol_file_string, ...
    'options_json_file_string', p.options_file_string);

[e, y_attempt] = evaluate_time_fit(sim_output, p.target_data, ...
    'fit_variable', p.fit_variable, ...
    'fit_start_index', p.fit_start_index);

target_data = p.target_data;
end
