function summary = run_mava_joint_feature_multistart(run_id, stage_parameters, varargin)
% Run bounded, trace-specific joint Control/H251N feature fits.
%
% Each restart is isolated so its configuration, models, feature residuals,
% and optimizer result can be inspected independently. stage_parameters are
% condition-specific; k_2 and thin-filament parameters remain fixed.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(script_dir);

p = inputParser;
addRequired(p, 'run_id', @(x) ischar(x) || isstring(x));
addRequired(p, 'stage_parameters', @(x) iscell(x) || isstring(x));
addParameter(p, 'output_root', fullfile(script_dir, 'output', ...
    'feature_multistart_runs'));
addParameter(p, 'restarts', 8, @(x) isscalar(x) && x >= 1 && x == floor(x));
addParameter(p, 'max_fun_evals', 300, @(x) isscalar(x) && x >= 1 && x == floor(x));
addParameter(p, 'previous_best_file', '');
addParameter(p, 'restart_offset', 0, @(x) isscalar(x) && x >= 0 && x == floor(x));
addParameter(p, 'start_vectors', []);
addParameter(p, 'resume', false, @(x) islogical(x) && isscalar(x));
parse(p, run_id, stage_parameters, varargin{:});
settings = p.Results;
run_id = char(string(settings.run_id));
stage_parameters = cellstr(string(settings.stage_parameters));
if isempty(run_id) || contains(run_id, {'/','\\','..'})
    error('run_mava_joint_feature_multistart:badRunId', ...
        'run_id must be a simple, nonempty directory name.');
end
if any(strcmp(stage_parameters, 'k_2'))
    error('run_mava_joint_feature_multistart:k2Fixed', ...
        'k_2 is constrained to k_1 and cannot be free.');
end

run_dir = fullfile(char(string(settings.output_root)), run_id);
if isfolder(run_dir)
    if ~settings.resume
        error('run_mava_joint_feature_multistart:existingRun', ...
            'Refusing to overwrite existing run: %s', run_dir);
    end
else
    mkdir(run_dir);
end
previous_start = load_previous_start(settings.previous_best_file, stage_parameters);
n_parameters = 2 * numel(stage_parameters);
if ~isempty(settings.start_vectors) && ...
        (~isnumeric(settings.start_vectors) || ...
        ~isequal(size(settings.start_vectors), [settings.restarts n_parameters]) || ...
        any(~isfinite(settings.start_vectors), 'all') || ...
        any(settings.start_vectors < 0, 'all') || any(settings.start_vectors > 1, 'all'))
    error('run_mava_joint_feature_multistart:badStartVectors', ...
        'start_vectors must be restarts-by-n_parameters values in [0,1].');
end
rows = repmat(struct('restart', NaN, 'best_error', NaN, ...
    'control_feature_error', NaN, 'h251n_feature_error', NaN, ...
    'exitflag', NaN, 'func_count', NaN, 'result_dir', ''), settings.restarts, 1);
if settings.resume
    rows = load_completed_rows(run_dir, rows, settings.restart_offset);
end

for restart = 1:settings.restarts
    restart_number = settings.restart_offset + restart;
    if isfinite(rows(restart).best_error)
        continue;
    end
    restart_dir = fullfile(run_dir, sprintf('s%02d', restart_number));
    if isempty(settings.start_vectors)
        start_vector = mava_deterministic_start(n_parameters, restart_number, previous_start);
    else
        start_vector = settings.start_vectors(restart, :);
    end
    build_settings = struct('max_fun_evals', settings.max_fun_evals, ...
        'tol_fun', 1e-4, 'tol_x', 1e-3, 'start_vector', start_vector);
    [config_file, record] = build_mava_joint_feature_fit_config( ...
        restart_dir, stage_parameters, build_settings);
    opt = loadjson(config_file).MyoSim_optimization;
    fit = fit_controller(opt);
    [ctrl_error, hcm_error] = job_errors(fit, opt, record.result_dir);
    rows(restart) = struct('restart', restart_number, 'best_error', fit.best_error, ...
        'control_feature_error', ctrl_error, 'h251n_feature_error', hcm_error, ...
        'exitflag', fit.exitflag, 'func_count', fit.func_count, ...
        'result_dir', record.result_dir);
    write_completed_rows(run_dir, rows);
end

if any(~isfinite([rows.best_error]))
    error('run_mava_joint_feature_multistart:incompleteRun', ...
        'Not all requested restarts completed. Re-run with resume=true.');
end
summary_table = struct2table(rows);
[~, best_index] = min(summary_table.best_error);
best = struct('run_id', run_id, 'stage_parameters', {stage_parameters}, ...
    'restarts', settings.restarts, 'max_fun_evals', settings.max_fun_evals, ...
    'alignment_policy', 'independent_trace', 'thin_filament_parameters', ...
    {{'k_on','k_off','k_coop'}}, 'best_restart', best_index, ...
    'best_result_dir', rows(best_index).result_dir, ...
    'best_error', rows(best_index).best_error);
fid = fopen(fullfile(run_dir, 'summary.json'), 'w');
if fid < 0
    error('run_mava_joint_feature_multistart:summaryWriteFailed', ...
        'Could not write run summary.');
end

function rows = load_completed_rows(run_dir, rows, restart_offset)
summary_file = fullfile(run_dir, 'restart_summary.csv');
if ~isfile(summary_file), return; end
prior = readtable(summary_file, 'TextType', 'string');
for i = 1:height(prior)
    slot = prior.restart(i) - restart_offset;
    if slot < 1 || slot > numel(rows) || ~isfinite(prior.best_error(i))
        continue;
    end
    done_file = fullfile(run_dir, sprintf('s%02d', prior.restart(i)), ...
        'results', 'DONE.flag');
    if isfile(done_file)
        rows(slot) = struct('restart', prior.restart(i), ...
            'best_error', prior.best_error(i), ...
            'control_feature_error', prior.control_feature_error(i), ...
            'h251n_feature_error', prior.h251n_feature_error(i), ...
            'exitflag', prior.exitflag(i), 'func_count', prior.func_count(i), ...
            'result_dir', char(prior.result_dir(i)));
    end
end
end

function write_completed_rows(run_dir, rows)
complete = isfinite([rows.best_error]);
writetable(struct2table(rows(complete)), fullfile(run_dir, 'restart_summary.csv'));
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('', best, 'FloatFormat', '%.17g'));
fprintf('Feature stage complete: %s, best restart %d, error %.6g\n', ...
    run_id, best_index, best.best_error);
summary = best;
summary.restart_summary = summary_table;
end

function prior = load_previous_start(previous_best_file, stage_parameters)
prior = [];
previous_best_file = char(string(previous_best_file));
if isempty(previous_best_file), return; end
if ~isfile(previous_best_file)
    error('run_mava_joint_feature_multistart:missingPreviousBest', ...
        'Previous best optimization file not found: %s', previous_best_file);
end
opt = loadjson(previous_best_file).MyoSim_optimization;
names = cellfun(@(x) string(x.name), opt.parameter, 'UniformOutput', false);
prior = zeros(1, 2 * numel(stage_parameters));
for i = 1:numel(stage_parameters)
    for j = 1:2
        condition_names = {'control','h251n'};
        name = sprintf('%s_%s', stage_parameters{i}, condition_names{j});
        index = find(strcmp(names, name), 1);
        if ~isempty(index)
            prior(2*(i-1)+j) = opt.parameter{index}.p_value;
        else
            prior(2*(i-1)+j) = 0.5;
        end
    end
end
end

function [ctrl_error, hcm_error] = job_errors(fit, opt, result_dir)
% Scores calculated at the best trial avoid a second simulation for a
% rejected parameter set that may be numerically unstable.
if isfield(fit, 'job_errors') && numel(fit.job_errors) == 2 && ...
        all(isfinite(fit.job_errors))
    ctrl_error = fit.job_errors(1);
    hcm_error = fit.job_errors(2);
    return;
end
[ctrl_error, hcm_error] = save_feature_residuals(opt, result_dir);
end

function [ctrl_error, hcm_error] = save_feature_residuals(opt, result_dir)
errors = nan(1, numel(opt.job));
labels = {'control','h251n'};
for j = 1:numel(opt.job)
    sim = simulation_driver('model_json_file_string', ...
        opt.best_model_file_string{j}, 'simulation_protocol_file_string', ...
        opt.job{j}.protocol_file_string, 'options_json_file_string', ...
        opt.job{j}.options_file_string);
    target = load(opt.job{j}.target_file_string);
    [errors(j), ~, details] = evaluate_mava_feature_fit(sim, target, ...
        'fit_start_index', opt.job{j}.fit_start_index);
    writetable(details, fullfile(result_dir, ...
        sprintf('feature_residuals_%s.csv', labels{j})));
end
ctrl_error = errors(1);
hcm_error = errors(2);
end
