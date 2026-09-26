function result = run_mava_feature_smoke_fit(max_fun_evals, run_id, ...
        parameter_names, genotype, alignment_policy)
% Run a bounded optimizer smoke test on feature error.

if nargin < 1 || isempty(max_fun_evals)
    max_fun_evals = 12;
end
if nargin < 2 || isempty(run_id)
    run_id = ['feature_smoke_' datestr(now, 'yyyymmdd_HHMMSS')];
end
if nargin < 3 || isempty(parameter_names)
    parameter_names = {'k_5_0'};
end
if nargin < 4 || isempty(genotype)
    genotype = 'Control';
end
if nargin < 5 || isempty(alignment_policy)
    alignment_policy = 'shared_by_genotype';
end
if ~isscalar(max_fun_evals) || max_fun_evals < 1 || ...
        max_fun_evals ~= floor(max_fun_evals)
    error('run_mava_feature_smoke_fit:badBudget', ...
        'max_fun_evals must be a positive integer.');
end
alignment_policy = char(string(alignment_policy));
if ~ismember(alignment_policy, {'shared_by_genotype', 'independent_trace'})
    error('run_mava_feature_smoke_fit:badAlignment', ...
        'alignment_policy must be shared_by_genotype or independent_trace.');
end

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(script_dir);

run_dir = fullfile(script_dir, 'output', 'feature_smoke_runs', run_id);
if isfolder(run_dir)
    error('run_mava_feature_smoke_fit:existingRun', ...
        'Refusing to overwrite existing run: %s', run_dir);
end
data_dir = fullfile(run_dir, 'data', alignment_policy);
prepare_mava_data([], data_dir, 'peak', alignment_policy);
fit_start_index = mava_reference_onset_index( ...
    fullfile(data_dir, [genotype '_protocol.txt']));

stage_id = strjoin(strrep(parameter_names, '_', ''), '_');
stage = struct('id', stage_id, 'parameters', {parameter_names});
settings = struct('fit_start_index', fit_start_index, ...
    'max_fun_evals', max_fun_evals, 'tol_fun', 1e-4, 'tol_x', 1e-3, ...
    'figure_current_fit', 0, 'figure_optimization_progress', 0);
[base_config, record] = build_mava_sequential_fit_config(run_dir, ...
    alignment_policy, genotype, stage, 1, [], settings);
loaded = loadjson(base_config);
opt = loaded.MyoSim_optimization;
opt.fit_mode = 'fit_twitch_features';
opt.model_working_file_string = opt.job{1}.model_file_string;
opt.best_model_file_string = fullfile(record.result_dir, 'model_best.json');

config_file = fullfile(run_dir, 'feature_optimization.json');
fid = fopen(config_file, 'w');
if fid < 0
    error('run_mava_feature_smoke_fit:writeFailed', ...
        'Could not write %s.', config_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('MyoSim_optimization', opt, ...
    'FloatFormat', '%.17g'));
clear cleanup;

fit_results = fit_controller(opt);
target = load(opt.job{1}.target_file_string);
best_sim = simulation_driver( ...
    'model_json_file_string', opt.best_model_file_string, ...
    'simulation_protocol_file_string', opt.job{1}.protocol_file_string, ...
    'options_json_file_string', opt.job{1}.options_file_string);
[final_error, ~, feature_details] = evaluate_mava_feature_fit( ...
    best_sim, target, 'fit_start_index', opt.job{1}.fit_start_index);
writetable(feature_details, fullfile(run_dir, 'feature_residuals.csv'));
plot_mava_feature_fit_review(best_sim, target, ...
    opt.job{1}.fit_start_index, feature_details, ...
    fullfile(run_dir, 'feature_fit_review.png'));

result = struct('run_id', run_id, 'run_dir', run_dir, ...
    'config_file', config_file, 'initial_budget', max_fun_evals, ...
    'genotype', genotype, 'alignment_policy', alignment_policy, ...
    'parameter_names', {parameter_names}, ...
    'final_error', final_error, 'fit_results', fit_results, ...
    'feature_details', feature_details);
fid = fopen(fullfile(run_dir, 'smoke_summary.json'), 'w');
if fid < 0
    error('run_mava_feature_smoke_fit:summaryWriteFailed', ...
        'Could not write smoke-test summary.');
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
serializable = rmfield(result, {'fit_results','feature_details'});
fprintf(fid, '%s', savejson('', serializable, 'FloatFormat', '%.17g'));
end
