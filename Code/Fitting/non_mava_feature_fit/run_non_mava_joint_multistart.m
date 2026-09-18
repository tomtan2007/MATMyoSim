function summary = run_non_mava_joint_multistart(run_id, stage_parameters, varargin)
% Run deterministic bounded multistarts for the non-Mava Control/H251N pair.
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
p = inputParser;
addRequired(p, 'run_id'); addRequired(p, 'stage_parameters');
addParameter(p, 'restarts', 8); addParameter(p, 'max_fun_evals', 300);
addParameter(p, 'output_root', fullfile(script_dir, 'output'));
addParameter(p, 'start_vectors', []);
parse(p, run_id, stage_parameters, varargin{:}); s = p.Results;
run_dir = fullfile(char(string(s.output_root)), char(string(run_id)));
if isfolder(run_dir)
    error('run_non_mava_joint_multistart:existingRun', ...
        'Refusing to overwrite %s.', run_dir);
end
mkdir(run_dir);
names = cellstr(string(stage_parameters)); npar = 2*numel(names);
if ~isempty(s.start_vectors) && ...
        ~isequal(size(s.start_vectors), [s.restarts npar])
    error('run_non_mava_joint_multistart:badStarts', ...
        'start_vectors must be restarts-by-%d.', npar);
end
rows = table('Size', [s.restarts 7], ...
    'VariableTypes', {'double','double','double','double','double','double','string'}, ...
    'VariableNames', {'restart','best_error','control_error','h251n_error', ...
    'exitflag','func_count','result_dir'});
for r = 1:s.restarts
    if isempty(s.start_vectors)
        start = mava_deterministic_start(npar, r, []);
    else
        start = s.start_vectors(r,:);
    end
    restart_dir = fullfile(run_dir, sprintf('s%02d', r));
    [config, record] = build_non_mava_joint_config(restart_dir, names, ...
        struct('max_fun_evals', s.max_fun_evals, 'start_vector', start));
    opt = loadjson(config).MyoSim_optimization;
    fit = fit_controller(opt);
    rows(r,:) = {r, fit.best_error, fit.job_errors(1), fit.job_errors(2), ...
        fit.exitflag, fit.func_count, string(record.result_dir)};
    writetable(rows(1:r,:), fullfile(run_dir, 'restart_summary.csv'));
end
[~, best_row] = min(rows.best_error);
summary = struct('run_id', char(string(run_id)), ...
    'stage_parameters', {names}, 'restarts', s.restarts, ...
    'max_fun_evals', s.max_fun_evals, 'best_restart', best_row, ...
    'best_error', rows.best_error(best_row), ...
    'best_result_dir', char(rows.result_dir(best_row)), ...
    'feature_aic_calculated', false, 'mava_data_used', false);
fid = fopen(fullfile(run_dir, 'summary.json'), 'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(summary, PrettyPrint=true));
summarize_non_mava_feature_run(run_dir);
end
