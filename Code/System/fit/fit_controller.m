function fit_results = fit_controller(opt_structure, varargin)

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
best_objective = inf;
best_fit_error = inf;
all_e_values = [];
y_best = [];
best_p = p_vector;

fh = @(x)run_trial(x, opt_structure);

nvars = numel(p_vector);
lb = zeros(1, nvars);
ub = ones(1, nvars);
% Optional override (opt_structure.max_fun_evals) so exploratory runs
% (joint fits, profile-likelihood scans) can cap runtime without
% touching the default used by all existing single-condition demos.
if isfield(opt_structure, 'max_fun_evals')
    max_fun_evals = opt_structure.max_fun_evals;
else
    max_fun_evals = 5000;
end
tol_fun = 1e-6;
tol_x = 1e-4;
if isfield(opt_structure, 'tol_fun'), tol_fun = opt_structure.tol_fun; end
if isfield(opt_structure, 'tol_x'), tol_x = opt_structure.tol_x; end
fm_options = optimset('Display', 'iter', 'MaxFunEvals', max_fun_evals, ...
    'TolFun', tol_fun, 'TolX', tol_x);
[~, ~, exitflag, fm_output] = fminsearch(fh, p_vector, fm_options);

% Save results JSON and sentinel so monitoring agent can read outcome
results_dir = fileparts(opt_structure.best_opt_file_string);
k = numel(p_vector);
% For multi-job (joint) fits, sum active-window point counts across all
% jobs. NOTE: when there is more than one job, best_e is a MEAN of
% per-job normalized MSEs (see fit_worker.m), not a single SSE/n_total,
% so n_active*log(best_e)+2k is only an approximation of a true joint
% AIC here (exact when all jobs have equal n_active). Treat joint-fit
% AIC values as comparative/approximate, not literal.
try
    n_active = 0;
    for jbi = 1 : numel(opt_structure.job)
        target_raw = dlmread(opt_structure.job{jbi}.target_file_string);
        if isfield(opt_structure.job{jbi}, 'fit_start_index')
            configured_start = opt_structure.job{jbi}.fit_start_index;
        else
            configured_start = [];
        end
        fa = resolve_time_fit_start_index(target_raw, configured_start);
        n_active = n_active + (numel(target_raw) - fa + 1);
    end
catch ME
    if startsWith(ME.identifier, 'resolve_time_fit_start_index:')
        rethrow(ME);
    end
    n_active = NaN;
end

fit_results.best_error     = best_fit_error;
fit_results.best_objective = best_objective;
fit_results.n_free_params  = k;
fit_results.n_active_points = n_active;
if ~isnan(n_active) && best_fit_error > 0
    fit_results.aic = n_active * log(best_fit_error) + 2 * k;
else
    fit_results.aic = NaN;
end
fit_results.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
fit_results.exitflag = exitflag;
fit_results.iterations = fm_output.iterations;
fit_results.func_count = fm_output.funcCount;
fit_results.algorithm = fm_output.algorithm;
fit_results.message = fm_output.message;
fit_results.tol_fun = tol_fun;
fit_results.tol_x = tol_x;

of = fopen(fullfile(results_dir, 'fit_results.json'), 'w');
fprintf(of, '%s', savejson('', fit_results));
fclose(of);

sentinel_file = fullfile(fileparts(results_dir), 'DONE.flag');
of = fopen(sentinel_file, 'w');
fprintf(of, 'done\n');
fclose(of);
fprintf('=== Fit complete: error=%.6f  objective=%.6f  AIC=%.1f ===\n', ...
    best_fit_error, best_objective, fit_results.aic);

    function e = run_trial(p_vector, opt_structure)

        if isfield(opt_structure, 'test_objective')
            boundary_penalty = 1e4 * (sum(max(0, p_vector - 1).^2) + ...
                sum(max(0, -p_vector).^2));
            p_clamped = max(0, min(1, p_vector));
            trial_e = opt_structure.test_objective(p_clamped);
            e = trial_e + boundary_penalty;
            sim_output = [];
            y_attempt = [];
            target_data = [];
        else
            [e, trial_e, sim_output, y_attempt, target_data] = ...
                fit_worker(p_vector,opt_structure);
        end

        fit_error = mean(trial_e);
        all_e_values = [all_e_values e];

        % First time
        if (numel(all_e_values) == 1)
            y_best = y_attempt;
        end

        if (e <= best_objective)
            best_objective = e;
            best_fit_error = fit_error;
            y_best = y_attempt;
            best_p = p_vector;
            if (isfield(opt_structure, 'model_working_file_string'))
                if iscell(opt_structure.model_working_file_string)
                    % Joint fit: one working/best model file per job
                    for jbi = 1 : numel(opt_structure.model_working_file_string)
                        copyfile(opt_structure.model_working_file_string{jbi}, ...
                            opt_structure.best_model_file_string{jbi});
                    end
                else
                    copyfile(opt_structure.model_working_file_string, ...
                        opt_structure.best_model_file_string);
                end
            end
            
            % Update best_opt_file
            best_opt_job = opt_structure;
            if isfield(best_opt_job, 'test_objective')
                best_opt_job = rmfield(best_opt_job, 'test_objective');
            end
            p_counter = 0;
            for i = 1 : numel(best_opt_job.parameter)
                p_counter = p_counter + 1;
                best_opt_job.parameter{i}.p_value_raw = p_vector(p_counter);
                best_opt_job.parameter{i}.p_value = ...
                    max(0, min(1, p_vector(p_counter)));
            end
            if isfield(best_opt_job, 'constraint')
                for i = 1 : numel(best_opt_job.constraint)
                    if isfield(best_opt_job.constraint{i}, ...
                            'parameter_multiplier')
                        for j = 1 : numel(best_opt_job.constraint{i}. ...
                                parameter_multiplier)
                            p_counter = p_counter + 1;
                            multiplier = best_opt_job.constraint{i}. ...
                                parameter_multiplier{j};
                            multiplier.p_value_raw = p_vector(p_counter);
                            multiplier.p_value = max(0, ...
                                min(1, p_vector(p_counter)));
                            best_opt_job.constraint{i}. ...
                                parameter_multiplier{j} = multiplier;
                        end
                    end
                end
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

