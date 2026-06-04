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

nvars = numel(p_vector);
lb = zeros(1, nvars);
ub = ones(1, nvars);
fm_options = optimset('Display', 'iter', 'MaxFunEvals', 5000, 'TolFun', 1e-6);
fminsearch(fh, p_vector, fm_options);

% Save results JSON and sentinel so monitoring agent can read outcome
results_dir = fileparts(opt_structure.best_opt_file_string);
k = numel(p_vector);
try
    target_raw = dlmread(opt_structure.job{1}.target_file_string);
    tmin = min(target_raw); tmax = max(target_raw);
    fa = find(target_raw > tmin + 0.05*(tmax-tmin), 1, 'first');
    if isempty(fa), fa = 1; end
    n_active = numel(target_raw) - fa + 1;
catch
    n_active = NaN;
end

fit_results.best_error     = best_e;
fit_results.n_free_params  = k;
fit_results.n_active_points = n_active;
if ~isnan(n_active) && best_e > 0
    fit_results.aic = n_active * log(best_e) + 2 * k;
else
    fit_results.aic = NaN;
end
fit_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

of = fopen(fullfile(results_dir, 'fit_results.json'), 'w');
fprintf(of, '%s', savejson('', fit_results));
fclose(of);

sentinel_file = fullfile(fileparts(results_dir), 'DONE.flag');
of = fopen(sentinel_file, 'w');
fprintf(of, 'done\n');
fclose(of);
fprintf('=== Fit complete: error=%.6f  AIC=%.1f ===\n', best_e, fit_results.aic);

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

