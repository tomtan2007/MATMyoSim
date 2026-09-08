function all_models = update_json_model_file(opt_structure, job_counter, ...
                        p_vector, all_models)
% Function creates a new model file based on opt structure and p vector

% Pull of the filnames we want
% A job may override the global template with its own
% model_template_file_string (used for joint fits where each job/
% condition needs different fixed baseline parameters that are not
% part of the shared optimizer parameter set).
if isfield(opt_structure.job{job_counter}, 'model_template_file_string')
    original_json_model_file_string = ...
        opt_structure.job{job_counter}.model_template_file_string;
else
    original_json_model_file_string = opt_structure.model_template_file_string;
end
new_json_model_file_string = ...
    opt_structure.job{job_counter}.model_file_string;

% Load original model
model_struct = loadjson(original_json_model_file_string);

% Set parameter data
par_structure = opt_structure.parameter;

% Get the fieldnames
model_fields = fieldnamesr(model_struct);

% Loop through the parameters
%
% Joint-fit support (backward compatible): a parameter entry may carry
% an optional "job" field restricting it to a single job_counter (used
% for parameters that are allowed to differ between conditions, e.g.
% k_1_ctrl / k_1_hcm), and an optional "target_name" field giving the
% actual model field name to write (defaults to "name" if absent).
% Parameters with no "job" field are written identically into every
% job's model (the normal shared-parameter / single-job behavior).
for i = 1 : numel(par_structure)

    this_par = par_structure{i};

    % Skip parameters that are restricted to a different job
    if isfield(this_par, 'job') && this_par.job ~= job_counter
        continue;
    end

    % Set the parameter value
    par_value = return_parameter_value( ...
        this_par, p_vector(i));

    % Resolve the model field name (target_name overrides name)
    if isfield(this_par, 'target_name')
        write_name = this_par.target_name;
    else
        write_name = this_par.name;
    end

    % Create the par_string
    par_string = sprintf('parameters.%s', write_name);

    % Update model struct
    update_model_struct(par_string, par_value);

end

% Update hsl if required
if (isfield(opt_structure, 'initial_delta_hsl'))
    model_struct.MyoSim_model.hs_props.hs_length = ...
        model_struct.MyoSim_model.hs_props.hs_length + ...
            opt_structure.initial_delta_hsl(job_counter);
end

% Set counter for constrain p values
p_counter = numel(par_structure);

% Check for constraints
if (isfield(opt_structure, 'constraint'))
   
    % Now we search for a job number
    for i = 1 : numel(opt_structure.constraint)
        constrained_jobs(i) = opt_structure.constraint{i}.job_number;
    end
   
    vi = find(constrained_jobs == job_counter);
   
    % Do some checking
    if (numel(vi)>1)
        error('Constrained job duplicate in optimization structure');
    end
   
    if (numel(vi)==1)
        % Handle the constraints for the job
        constraint = opt_structure.constraint{vi};
        
        % Check for parameter modifiers
        if (isfield(constraint, 'parameter_multiplier'))
            for i = 1 : numel(constraint.parameter_multiplier)
                
                % Get the base value
                base_job_number = constraint.parameter_multiplier{i}. ...
                    base_job_number;
                par_name = constraint.parameter_multiplier{i}.name;
                
                base_value = all_models{base_job_number}.MyoSim_model. ...
                    hs_props.parameters.(par_name);

                % Set the par string
                par_string = sprintf('parameters.%s', ...
                    constraint.parameter_multiplier{i}.name);

                % Set the multiplier value
                p_counter = p_counter + 1;
                
                multiplier_value = return_parameter_value( ...
                    constraint.parameter_multiplier{i}, ...
                    p_vector(p_counter));

                % Update model
                update_model_struct(par_string, ...
                    multiplier_value * base_value);
            end
        end

        if (isfield(constraint, 'parameter_copy'))
            for i = 1 : numel(constraint.parameter_copy)
                % Get the parameter value
                job_copy = constraint.parameter_copy{i}.copy_job_number;
                par_value = all_models{job_copy}.MyoSim_model.hs_props. ...
                    parameters.(constraint.parameter_copy{i}.name);

                % Set the par string
                par_string = sprintf('parameters.%s', ...
                    constraint.parameter_copy{i}.name);

                % Update model
                update_model_struct(par_string, par_value);
            end
        end
   end
end       

% Enforce a coupled k_2/k_1 ratio (legacy default = 10).
% This runs after all free parameters are written, so k_1 reflects
% the optimizer's current value before k_2 is overwritten.
% Override: if k_2 is itself listed as a free parameter for this
% optimization, skip the auto-set so k_2 fits independently.
k_2_is_free = false;
for i = 1 : numel(par_structure)
    if strcmp(par_structure{i}.name, 'k_2')
        k_2_is_free = true;
    end
end
if ~k_2_is_free && ...
   isfield(model_struct.MyoSim_model.hs_props.parameters, 'k_1') && ...
   isfield(model_struct.MyoSim_model.hs_props.parameters, 'k_2')
    k2_k1_ratio = 10;
    if isfield(opt_structure, 'k_2_k_1_ratio')
        k2_k1_ratio = opt_structure.k_2_k_1_ratio;
    end
    if ~isnumeric(k2_k1_ratio) || ~isreal(k2_k1_ratio) || ...
            ~isscalar(k2_k1_ratio) || ~isfinite(k2_k1_ratio) || ...
            k2_k1_ratio <= 0
        error('update_json_model_file:badK2K1Ratio', ...
            'k_2_k_1_ratio must be a positive finite numeric scalar.');
    end
    k1_val = model_struct.MyoSim_model.hs_props.parameters.k_1;
    update_model_struct('parameters.k_2', k2_k1_ratio * k1_val);
end

% Save the model for a potential next job
all_models{job_counter} = model_struct;

% Write it out
% Check for directory and make it if required
path_string = fileparts(new_json_model_file_string);
if (~isfolder(path_string))
    mkdir(fullfile(cd, path_string))
end

% Dump struct to json
out_string = savejson('MyoSim_model', model_struct.MyoSim_model);
out_string = strrep(out_string, '\/', '/');

out_file = fopen(new_json_model_file_string, 'w');
fprintf(out_file, '%s', out_string);
fclose(out_file);

    % Nested function
    function update_model_struct(par_string, par_value)
        needle = ['.' par_string];
        vi = find(cellfun(@(f) endsWith(f, needle) || strcmp(f, par_string), ...
            model_fields));

        % Check
        if (numel(vi)==0)
            error(sprintf('Parameter %s not found in %s', ...
                par_string, original_json_model_file_string));
        end
        if (numel(vi)>1)
            error(sprintf('Parameter %s found more than once in %s', ...
                par_string, original_json_model_file_string));
        end

        % Set the field
        temp_string = sprintf('model_struct.%s = %g;', ...
            model_fields{vi}, par_value);
        eval(temp_string)
    end
end
   
   
