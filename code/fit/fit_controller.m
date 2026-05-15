function fit_controller(opt_structure, varargin)

p = inputParser;
addRequired(p, 'opt_structure');
addOptional(p, 'single_run', 0);
parse(p, opt_structure, varargin{:});
p = p.Results;
opt_structure = p.opt_structure;

% Pull out initial p_vector
p_vector = [];
for i=1:numel(opt_structure.parameter)
    p_vector(i) = opt_structure.parameter{i}.p_value;
end

% Append p_values from constraint parameter_multipliers
if (isfield(opt_structure, 'constraint'))
    for i = 1 : numel(opt_structure.constraint)
        if (isfield(opt_structure.constraint{i}, 'parameter_multiplier'))
            for j = 1 : numel(opt_structure.constraint{i}.parameter_multiplier)
                p_vector(end+1) = opt_structure.constraint{i}.parameter_multiplier{j}.p_value;
            end
        end
    end
end

% Set up for optimization
best_e = inf;
all_e_values = [];
y_best = [];
best_p = p_vector;

fh = @(x)run_trial(x, opt_structure);

fminsearch(fh, p_vector, optimset('Display', 'iter', 'MaxFunEvals', 5000));

    function e = run_trial(p_vector, opt_structure)

        [e, trial_e, sim_output, y_attempt, target_data] = ...
            fit_worker(p_vector,opt_structure);

        all_e_values = [all_e_values e];

        % First time
        if (numel(all_e_values) == 1)
            best_e = e;
            y_best = y_attempt;
        end
        
        if (e <= best_e)
            best_e = e;
            y_best = y_attempt;
            best_p = p_vector;
            if (isfield(opt_structure, 'model_working_file_string'))
                copyfile(opt_structure.model_working_file_string, ...
                    opt_structure.best_model_file_string);
            end
            
            % Update best_opt_file
            best_opt_job = opt_structure;
            for i=1:numel(p_vector)
                best_opt_job.parameter{i}.p_value = p_vector(i);
            end
            out_string = savejson('MyoSim_optimization', best_opt_job);
            best_opt_dir = fileparts(opt_structure.best_opt_file_string);
            if (~isempty(best_opt_dir) && ~isfolder(best_opt_dir))
                mkdir(fullfile(cd, best_opt_dir));
            end
            of = fopen(opt_structure.best_opt_file_string,'w');
            fprintf(of,'%s',out_string);
            fclose(of);
            
            
            
        end
        
        % Update figures
        if (opt_structure.figure_optimization_progress)
            draw_figure_optimization_progress(opt_structure, all_e_values);
        end
        
        if (opt_structure.figure_current_fit)
            draw_figure_current_fit(opt_structure, sim_output, ...
                y_attempt, target_data, ...
                trial_e, y_best, ...
                p_vector, best_p);
        end
        
        if (p.single_run)
            error('fit_controller stopped after single run');
        end
    end
end

