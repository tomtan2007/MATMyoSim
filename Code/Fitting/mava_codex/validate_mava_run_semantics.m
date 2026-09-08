function result_hashes = validate_mava_run_semantics( ...
    manifest, record_indices, completion_mode)
% Validate signed Mava config/result semantics without running simulations.

if nargin < 2 || isempty(record_indices)
    record_indices = 1:numel(manifest.inventory);
end
if nargin < 3 || isempty(completion_mode)
    completion_mode = 'signed';
end
completion_mode = char(string(completion_mode));
if ~ismember(completion_mode, {'optional','unsigned','signed'})
    error('validate_mava_run_semantics:badMode', ...
        'Completion mode must be optional, unsigned, or signed.');
end

inventory = as_cells(manifest.inventory);
data_records = as_cells(manifest.materialization.data_files);
config_records = as_cells(manifest.materialization.configs);
result_records = as_cells(manifest.materialization.results);
stages = as_cells(manifest.stages);
validate_unique_inventory(inventory);
result_hashes = cell(1, numel(record_indices));
for output_index = 1:numel(record_indices)
    index = record_indices(output_index);
    if ~isscalar(index) || index < 1 || index > numel(inventory) || ...
            index ~= floor(index)
        error('validate_mava_run_semantics:invalidManifest', ...
            'Record index is outside manifest inventory.');
    end
    item = inventory{index};
    validate_inventory_identity(manifest, item, stages);
    group_id = sprintf('%s__%s', char(string(item.alignment_policy)), ...
        char(string(item.genotype)));
    data_matches = cellfun(@(record) strcmp( ...
        char(string(record.id)), group_id), data_records);
    if nnz(data_matches) ~= 1
        error('validate_mava_run_semantics:invalidManifest', ...
            'Inventory record %s has no unique signed data record.', item.id);
    end
    data = data_records{find(data_matches, 1)};
    validate_data_paths(manifest, item, data);
    try
        root = loadjson(item.config_file);
        if ~has_exact_fields(root, {'MyoSim_optimization'})
            invalid_config(item, ...
                'Config must contain exactly the MyoSim_optimization root.');
        end
        opt = root.MyoSim_optimization;
        if ~isfield(opt, 'job')
            invalid_config(item, 'Config is missing its job.');
        end
        jobs = as_cells(opt.job);
        if numel(jobs) ~= 1 || ~isstruct(jobs{1}) || ~isscalar(jobs{1})
            invalid_config(item, 'Config must contain exactly one job.');
        end
        job = jobs{1};
    catch ME
        if strcmp(ME.identifier, 'validate_mava_run_semantics:invalidConfig')
            rethrow(ME);
        end
        error('validate_mava_run_semantics:invalidConfig', ...
            'Could not read config for %s: %s', item.id, ME.message);
    end
    validate_config(manifest, item, index, opt, job, data, ...
        config_records, stages);
    result_hashes{output_index} = validate_result( ...
        manifest, item, index, result_records, completion_mode, opt);
end
end

function hashes = validate_result(manifest, item, index, records, mode, config)
if index > numel(records)
    error('validate_mava_run_semantics:unsignedResult', ...
        'Result has no materialization entry: %s.', item.id);
end
entry = records{index};
hash_fields = {'model_best_sha256','best_optimization_sha256', ...
    'fit_results_sha256','status_sha256'};
populated = all(cellfun(@(name) isfield(entry, name) && ...
    ~isempty(entry.(name)), hash_fields));
if strcmp(mode, 'optional') && ~populated
    hashes = struct;
    return;
end
if strcmp(mode, 'signed') && ~populated
    error('validate_mava_run_semantics:unsignedResult', ...
        'Completed result is not bound by signed hashes: %s.', item.id);
end
files = {fullfile(item.result_dir, 'model_best.json'), ...
    fullfile(item.result_dir, 'best_optimization.json'), ...
    fullfile(item.result_dir, 'fit_results.json'), ...
    fullfile(item.result_dir, 'status.json')};
if ~all(cellfun(@isfile, files))
    error('validate_mava_run_semantics:missingResult', ...
        'Completed result is missing artifacts: %s.', item.id);
end
hashes = struct('model_best', mava_sha256(files{1}), ...
    'best_optimization', mava_sha256(files{2}), ...
    'fit_results', mava_sha256(files{3}), ...
    'status', mava_sha256(files{4}));
if strcmp(mode, 'signed') && ...
        (~strcmp(hashes.model_best, entry.model_best_sha256) || ...
        ~strcmp(hashes.best_optimization, entry.best_optimization_sha256) || ...
        ~strcmp(hashes.fit_results, entry.fit_results_sha256) || ...
        ~strcmp(hashes.status, entry.status_sha256))
    error('validate_mava_run_semantics:resultHashMismatch', ...
        'Completed result hashes disagree with materialization: %s.', item.id);
end
validate_status(item, files{4}, hashes);
fit = validate_fit_result(manifest, item, files{3}, config);
best = validate_best_optimization(manifest, item, files{2}, config);
validate_model(item, files{1}, config, best);
if fit.n_free_params ~= numel(as_cells(best.parameter))
    error('validate_mava_run_semantics:invalidFitResult', ...
        'Fit free-parameter count disagrees with best optimization: %s.', ...
        item.id);
end
end

function validate_status(item, status_file, hashes)
try
    status = loadjson(status_file);
catch ME
    error('validate_mava_run_semantics:invalidStatus', ...
        'Could not read status for %s: %s', item.id, ME.message);
end
required = {'alignment_policy','genotype','stage','restart','config_file', ...
    'config_sha256','status','updated_at','artifact_hashes'};
if ~isstruct(status) || ~all(isfield(status, required)) || ...
        ~strcmp(char(string(status.status)), 'complete') || ...
        ~strcmp(char(string(status.alignment_policy)), ...
        char(string(item.alignment_policy))) || ...
        ~strcmp(char(string(status.genotype)), char(string(item.genotype))) || ...
        ~strcmp(char(string(status.stage)), char(string(item.stage))) || ...
        ~isfinite_scalar(status.restart) || status.restart ~= item.restart || ...
        ~strcmp(char(string(status.config_file)), ...
        char(string(item.config_file))) || ...
        ~strcmp(char(string(status.config_sha256)), ...
        mava_sha256(char(string(item.config_file)))) || ...
        ~is_text_scalar(status.updated_at) || ...
        isempty(char(string(status.updated_at))) || ...
        ~isstruct(status.artifact_hashes)
    error('validate_mava_run_semantics:invalidStatus', ...
        'Completion status identity or schema is invalid: %s.', item.id);
end
required_hashes = {'model_best','best_optimization','fit_results'};
if ~all(isfield(status.artifact_hashes, required_hashes)) || ...
        ~strcmp(char(string(status.artifact_hashes.model_best)), ...
        hashes.model_best) || ...
        ~strcmp(char(string(status.artifact_hashes.best_optimization)), ...
        hashes.best_optimization) || ...
        ~strcmp(char(string(status.artifact_hashes.fit_results)), ...
        hashes.fit_results)
    error('validate_mava_run_semantics:invalidStatus', ...
        'Completion status artifact hashes are invalid: %s.', item.id);
end
end

function fit = validate_fit_result(manifest, item, fit_file, config)
try
    fit = loadjson(fit_file);
catch ME
    error('validate_mava_run_semantics:invalidFitResult', ...
        'Could not read fit result for %s: %s', item.id, ME.message);
end
numeric_fields = {'best_error','best_objective','n_free_params', ...
    'n_active_points','aic','exitflag','iterations','func_count', ...
    'tol_fun','tol_x'};
text_fields = {'timestamp','algorithm','message'};
if ~has_exact_fields(fit, [numeric_fields text_fields])
    invalid_fit(item, ...
        'Fit result contains missing or unsupported diagnostic fields.');
end
for i = 1:numel(numeric_fields)
    if ~isfinite_scalar(fit.(numeric_fields{i}))
        invalid_fit(item, sprintf('Fit field %s must be finite scalar.', ...
            numeric_fields{i}));
    end
end
for i = 1:numel(text_fields)
    if ~is_text_scalar(fit.(text_fields{i}))
        invalid_fit(item, sprintf('Fit field %s must be text.', ...
            text_fields{i}));
    end
end
integer_fields = {'n_free_params','n_active_points','iterations','func_count'};
for i = 1:numel(integer_fields)
    value = fit.(integer_fields{i});
    if value < 0 || value ~= floor(value)
        invalid_fit(item, sprintf('Fit field %s must be nonnegative integer.', ...
            integer_fields{i}));
    end
end
config_jobs = as_cells(config.job);
target = readmatrix(config_jobs{1}.target_file_string);
[first_active, ~] = resolve_time_fit_start_index(target, ...
    config_jobs{1}.fit_start_index);
expected_active = numel(target) - first_active + 1;
if fit.best_error <= 0 || fit.best_objective < fit.best_error || ...
        fit.n_free_params ~= numel(text_cells(item.parameter_names)) || ...
        fit.n_active_points ~= expected_active || ...
        ~producer_number_equal(fit.tol_fun, ...
        manifest.settings.tol_fun, '%.10g') || ...
        ~producer_number_equal(fit.tol_x, ...
        manifest.settings.tol_x, '%.10g') || ...
        ~aic_is_serialization_compatible(fit)
    invalid_fit(item, ...
        'Fit objective, counts, tolerances, or AIC are inconsistent.');
end
end

function best = validate_best_optimization(manifest, item, best_file, config)
try
    root = loadjson(best_file);
    if ~has_exact_fields(root, {'MyoSim_optimization'})
        invalid_best(item, ...
            'Best file must contain exactly the MyoSim_optimization root.');
    end
    best = root.MyoSim_optimization;
    if ~isfield(best, 'job')
        invalid_best(item, 'Best optimization is missing its job.');
    end
    best_jobs = as_cells(best.job);
    config_jobs = as_cells(config.job);
    if numel(best_jobs) ~= 1 || ~isstruct(best_jobs{1}) || ...
            ~isscalar(best_jobs{1}) || numel(config_jobs) ~= 1
        invalid_best(item, ...
            'Best optimization must contain exactly one job.');
    end
    best_job = best_jobs{1};
    config_job = config_jobs{1};
catch ME
    if strcmp(ME.identifier, ...
            'validate_mava_run_semantics:invalidBestOptimization')
        rethrow(ME);
    end
    error('validate_mava_run_semantics:invalidBestOptimization', ...
        'Could not read best optimization for %s: %s', item.id, ME.message);
end
[best_fields, job_fields, parameter_fields, path_fields, control_fields] = ...
    optimization_contract('best');
if ~has_exact_fields(best, best_fields) || ...
        ~has_exact_fields(best_job, job_fields)
    invalid_best(item, ...
        'Best optimization contains missing or undeclared fields.');
end
for i = 1:numel(path_fields)
    if ~strcmp(char(string(best.(path_fields{i}))), ...
            char(string(config.(path_fields{i}))))
        invalid_best(item, 'Best optimization identity differs from config.');
    end
end
if ~is_text_scalar(best.model_working_file_string) || ...
        ~strcmp(char(string(best.model_working_file_string)), ...
        char(string(best_job.model_file_string))) || ...
        ~is_text_scalar(best.best_model_file_string) || ...
        ~strcmp(char(string(best.best_model_file_string)), ...
        fullfile(char(string(item.result_dir)), 'model_best.json'))
    invalid_best(item, ...
        'Best optimization model paths disagree with the signed record.');
end
for i = 1:numel(job_fields)
    left = best_job.(job_fields{i});
    right = config_job.(job_fields{i});
    if isnumeric(left) || isnumeric(right)
        if ~isfinite_scalar(left) || ~isfinite_scalar(right) || left ~= right
            invalid_best(item, 'Best optimization job differs from config.');
        end
    elseif ~strcmp(char(string(left)), char(string(right)))
        invalid_best(item, 'Best optimization job differs from config.');
    end
end
for i = 1:numel(control_fields)
    left = best.(control_fields{i});
    right = config.(control_fields{i});
    if ~producer_number_equal(left, right, '%.10g')
        invalid_best(item, 'Best optimization controls differ from config.');
    end
end
parameters = as_cells(best.parameter);
config_parameters = as_cells(config.parameter);
expected_names = text_cells(item.parameter_names);
bounds = as_cells(item.bounds);
if numel(parameters) ~= numel(expected_names) || ...
        numel(config_parameters) ~= numel(expected_names)
    invalid_best(item, 'Best optimization parameter count is invalid.');
end
for i = 1:numel(parameters)
    parameter = parameters{i};
    base = config_parameters{i};
    if ~has_exact_fields(parameter, parameter_fields)
        invalid_best(item, ...
            'Best parameter identity, bounds, mode, or coordinate is invalid.');
    end
    [raw_low, raw_high] = serialized_decimal_interval( ...
        parameter.p_value_raw, 10);
    if ~strcmp(char(string(parameter.name)), expected_names{i}) || ...
            ~strcmp(char(string(parameter.name)), char(string(base.name))) || ...
            ~producer_number_equal(parameter.min_value, ...
            bounds{i}.min_value, '%.10g') || ...
            ~producer_number_equal(parameter.min_value, ...
            base.min_value, '%.10g') || ...
            ~producer_number_equal(parameter.max_value, ...
            bounds{i}.max_value, '%.10g') || ...
            ~producer_number_equal(parameter.max_value, ...
            base.max_value, '%.10g') || ...
            ~strcmp(char(string(parameter.p_mode)), ...
            char(string(bounds{i}.p_mode))) || ...
            ~strcmp(char(string(parameter.p_mode)), ...
            char(string(base.p_mode))) || ...
            ~isfinite_scalar(parameter.p_value) || ...
            parameter.p_value < 0 || parameter.p_value > 1 || ...
            ~isfinite_scalar(parameter.p_value_raw) || ...
            ~is_finite_ordered_interval(raw_low, raw_high) || ...
            ~producer_number_equal(parameter.p_value, ...
            max(0, min(1, parameter.p_value_raw)), '%.10g')
        invalid_best(item, ...
            'Best parameter identity, bounds, mode, or coordinate is invalid.');
    end
end
if isfield(best, 'constraint') || isfield(best, 'k_2_k_1_ratio')
    invalid_best(item, 'Best optimization reintroduced a k_2 constraint.');
end
if manifest.settings.fit_start_index ~= best_job.fit_start_index
    invalid_best(item, 'Best optimization scoring start is invalid.');
end
end

function validate_model(item, model_file, config, best)
try
    root = loadjson(model_file);
    if ~has_exact_fields(root, {'MyoSim_model'})
        invalid_model(item, 'Model must contain exactly the MyoSim_model root.');
    end
    model = root.MyoSim_model;
    template_root = loadjson(config.model_template_file_string);
    expected = template_root.MyoSim_model;
catch ME
    if strcmp(ME.identifier, 'validate_mava_run_semantics:invalidModel')
        rethrow(ME);
    end
    error('validate_mava_run_semantics:invalidModel', ...
        'Could not read model for %s: %s', item.id, ME.message);
end
best_parameters = as_cells(best.parameter);
config_parameters = as_cells(config.parameter);
for i = 1:numel(best_parameters)
    parameter = best_parameters{i};
    name = char(string(parameter.name));
    if ~isfield(expected.hs_props.parameters, name) || ...
            ~isfield(model.hs_props.parameters, name)
        invalid_model(item, sprintf( ...
            'Template or result model is missing fitted parameter %s.', name));
    end
    actual = model.hs_props.parameters.(name);
    if ~model_value_is_producer_compatible( ...
            actual, config_parameters{i}, parameter)
        invalid_model(item, sprintf( ...
            'Model fitted value is producer-incompatible for %s.', name));
    end
    expected.hs_props.parameters.(name) = actual;
end
expected_json = strrep(savejson('MyoSim_model', expected), '\/', '/');
actual_json = strrep(savejson('MyoSim_model', model), '\/', '/');
if ~strcmp(actual_json, expected_json)
    invalid_model(item, ...
        'Model differs from the signed template plus fitted parameters.');
end
end

function invalid_fit(item, message)
error('validate_mava_run_semantics:invalidFitResult', ...
    '%s Record: %s.', message, item.id);
end

function invalid_best(item, message)
error('validate_mava_run_semantics:invalidBestOptimization', ...
    '%s Record: %s.', message, item.id);
end

function invalid_model(item, message)
error('validate_mava_run_semantics:invalidModel', ...
    '%s Record: %s.', message, item.id);
end

function validate_unique_inventory(inventory)
ids = cellfun(@(item) char(string(item.id)), inventory, ...
    'UniformOutput', false);
if numel(unique(ids)) ~= numel(ids)
    error('validate_mava_run_semantics:invalidManifest', ...
        'Manifest inventory IDs must be unique.');
end
end

function validate_inventory_identity(manifest, item, stages)
required = {'id','alignment_policy','genotype','stage','restart', ...
    'required','config_file','result_dir','parameter_names','bounds'};
if ~isstruct(item) || ~all(isfield(item, required)) || ...
        ~is_text_scalar(item.id) || ~is_text_scalar(item.alignment_policy) || ...
        ~is_text_scalar(item.genotype) || ~is_text_scalar(item.stage) || ...
        ~isfinite_scalar(item.restart) || item.restart < 1 || ...
        item.restart ~= floor(item.restart)
    invalid_manifest('Inventory record has missing or invalid identity fields.');
end
expected_id = sprintf('%s__%s__%s__s%02d', ...
    char(string(item.alignment_policy)), char(string(item.genotype)), ...
    char(string(item.stage)), item.restart);
expected_config = fullfile(char(string(manifest.run_dir)), 'configs', ...
    [expected_id '.json']);
expected_result = fullfile(char(string(manifest.run_dir)), 'results', ...
    char(string(item.alignment_policy)), char(string(item.genotype)), ...
    char(string(item.stage)), sprintf('s%02d', item.restart));
if ~strcmp(char(string(item.id)), expected_id) || ...
        ~strcmp(char(string(item.config_file)), expected_config) || ...
        ~strcmp(char(string(item.result_dir)), expected_result)
    invalid_manifest(sprintf( ...
        'Inventory path or record identity is inconsistent for %s.', ...
        char(string(item.id))));
end
stage_matches = cellfun(@(stage) strcmp(char(string(stage.id)), ...
    char(string(item.stage))), stages);
if nnz(stage_matches) ~= 1
    invalid_manifest(sprintf('Inventory stage is not unique for %s.', item.id));
end
stage = stages{find(stage_matches, 1)};
if ~isequal(text_cells(item.parameter_names), text_cells(stage.parameters))
    invalid_manifest(sprintf( ...
        'Inventory parameters disagree with stage %s.', item.id));
end
end

function validate_data_paths(manifest, item, data)
switch char(string(item.genotype))
    case 'Control'
        target_id = 'ctrl_acute';
    case 'H251N'
        target_id = 'hcm_acute';
    otherwise
        invalid_manifest(sprintf('Unknown genotype for %s.', item.id));
end
data_dir = fullfile(char(string(manifest.run_dir)), 'data', ...
    char(string(item.alignment_policy)));
expected = {fullfile(data_dir, [target_id '_target.txt']), ...
    fullfile(data_dir, [target_id '_protocol.txt']), ...
    fullfile(data_dir, 'experimental_metrics.csv')};
fields = {'target_file','protocol_file','metrics_file'};
for i = 1:numel(fields)
    if ~isfield(data, fields{i}) || ...
            ~strcmp(char(string(data.(fields{i}))), expected{i})
        invalid_manifest(sprintf( ...
            'Signed prepared-data path is inconsistent for %s.', item.id));
    end
end
end

function validate_config(manifest, item, index, opt, job, data, ...
        config_records, stages)
[config_fields, job_fields, parameter_fields] = ...
    optimization_contract('config');
if ~has_exact_fields(opt, config_fields) || ...
        ~has_exact_fields(job, job_fields)
    invalid_config(item, 'Config contains missing or undeclared fit fields.');
end
template_record = manifest.hashes.baseline_templates.(char(string(item.genotype)));
options_record = manifest.hashes.options.(char(string(item.genotype)));
expected_worker = fullfile(char(string(item.result_dir)), 'model_worker.json');
expected_results = fullfile(char(string(item.result_dir)), 'twitch.myo');
expected_best = fullfile(char(string(item.result_dir)), ...
    'best_optimization.json');
if ~strcmp(char(string(opt.model_template_file_string)), ...
        char(string(template_record.path))) || ...
        ~strcmp(char(string(opt.fit_mode)), 'fit_in_time_domain') || ...
        ~strcmp(char(string(opt.fit_variable)), 'muscle_force') || ...
        ~strcmp(char(string(opt.best_model_folder)), ...
        char(string(item.result_dir))) || ...
        ~strcmp(char(string(opt.best_opt_file_string)), expected_best) || ...
        ~strcmp(char(string(job.model_file_string)), expected_worker) || ...
        ~strcmp(char(string(job.results_file_string)), expected_results) || ...
        ~strcmp(char(string(job.target_file_string)), ...
        char(string(data.target_file))) || ...
        ~strcmp(char(string(job.protocol_file_string)), ...
        char(string(data.protocol_file))) || ...
        ~strcmp(char(string(job.options_file_string)), ...
        char(string(options_record.path)))
    invalid_config(item, 'Config path or model identity is inconsistent.');
end
if ~isfinite_scalar(job.fit_start_index) || ...
        job.fit_start_index ~= manifest.settings.fit_start_index || ...
        ~isfinite_scalar(opt.max_fun_evals) || ...
        opt.max_fun_evals ~= manifest.settings.max_fun_evals || ...
        ~isfinite_scalar(opt.tol_fun) || ...
        opt.tol_fun ~= manifest.settings.tol_fun || ...
        ~isfinite_scalar(opt.tol_x) || opt.tol_x ~= manifest.settings.tol_x || ...
        ~isfinite_scalar(opt.figure_current_fit) || ...
        opt.figure_current_fit ~= 0 || ...
        ~isfinite_scalar(opt.figure_optimization_progress) || ...
        opt.figure_optimization_progress ~= 0
    invalid_config(item, 'Config fit controls disagree with signed settings.');
end
if isfield(opt, 'constraint') || isfield(opt, 'k_2_k_1_ratio')
    invalid_config(item, 'Sequential configs must keep k_2 independently free.');
end

stage_matches = cellfun(@(stage) strcmp(char(string(stage.id)), ...
    char(string(item.stage))), stages);
stage = stages{find(stage_matches, 1)};
expected_names = text_cells(stage.parameters);
parameters = as_cells(opt.parameter);
bounds = as_cells(item.bounds);
if numel(parameters) ~= numel(expected_names) || ...
        numel(bounds) ~= numel(expected_names)
    invalid_config(item, 'Config parameter count disagrees with its stage.');
end
names = cellfun(@(parameter) char(string(parameter.name)), parameters, ...
    'UniformOutput', false);
if ~isequal(names, expected_names)
    invalid_config(item, 'Config parameter names or order are inconsistent.');
end
coordinates = nan(1, numel(parameters));
for i = 1:numel(parameters)
    parameter = parameters{i};
    bound = bounds{i};
    if ~has_exact_fields(parameter, parameter_fields) || ...
            ~strcmp(char(string(bound.name)), expected_names{i}) || ...
            ~isfinite_scalar(parameter.min_value) || ...
            ~isfinite_scalar(parameter.max_value) || ...
            ~isfinite_scalar(parameter.p_value) || ...
            parameter.p_value < 0 || parameter.p_value > 1 || ...
            parameter.min_value ~= bound.min_value || ...
            parameter.max_value ~= bound.max_value || ...
            ~strcmp(char(string(parameter.p_mode)), ...
            char(string(bound.p_mode)))
        invalid_config(item, ...
            'Config parameter bounds, mode, or coordinate are inconsistent.');
    end
    coordinates(i) = parameter.p_value;
end
if index > numel(config_records)
    invalid_config(item, 'Config has no signed materialization entry.');
end
materialized = config_records{index};
if ~strcmp(char(string(materialized.id)), char(string(item.id))) || ...
        isempty(materialized.sha256) || ...
        ~strcmp(char(string(materialized.sha256)), ...
        mava_sha256(char(string(item.config_file)))) || ...
        isempty(materialized.resolved_seed) || ...
        numel(materialized.resolved_seed) ~= numel(coordinates) || ...
        any(~isfinite(materialized.resolved_seed)) || ...
        max(abs(materialized.resolved_seed(:)' - coordinates)) > 1e-12
    invalid_config(item, ...
        'Config hash or resolved seed disagrees with signed materialization.');
end
if isfield(item, 'seed') && ~isempty(item.seed) && ...
        (numel(item.seed) ~= numel(coordinates) || ...
        any(~isfinite(item.seed)) || ...
        max(abs(item.seed(:)' - coordinates)) > 1e-12)
    invalid_config(item, ...
        'Config coordinates disagree with the declared inventory seed.');
end
end

function invalid_manifest(message)
error('validate_mava_run_semantics:invalidManifest', '%s', message);
end

function invalid_config(item, message)
error('validate_mava_run_semantics:invalidConfig', '%s Record: %s.', ...
    message, char(string(item.id)));
end

function tf = is_text_scalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value));
end

function tf = isfinite_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function tf = producer_number_equal(actual, source, format)
tf = isfinite_scalar(actual) && isfinite_scalar(source) && ...
    actual == str2double(sprintf(format, actual)) && ...
    strcmp(sprintf(format, actual), sprintf(format, source));
end

function tf = aic_is_serialization_compatible(fit)
[error_low, error_high] = serialized_decimal_interval(fit.best_error, 10);
[aic_low, aic_high] = serialized_decimal_interval(fit.aic, 10);
if ~is_finite_ordered_interval(error_low, error_high) || ...
        error_low <= 0 || ...
        ~is_finite_ordered_interval(aic_low, aic_high)
    tf = false;
    return;
end
formula_low = fit.n_active_points * log(error_low) + ...
    2 * fit.n_free_params;
formula_high = fit.n_active_points * log(error_high) + ...
    2 * fit.n_free_params;
if ~is_finite_ordered_interval(formula_low, formula_high)
    tf = false;
    return;
end
scale = max([1, abs(aic_low), abs(aic_high), ...
    abs(formula_low), abs(formula_high)]);
roundoff = 8 * eps(scale);
tf = aic_high + roundoff >= formula_low && ...
    formula_high + roundoff >= aic_low;
end

function [low, high] = serialized_decimal_interval(value, digits)
format = sprintf('%%.%dg', digits);
if ~isfinite_scalar(value) || ...
        value ~= str2double(sprintf(format, value))
    low = NaN;
    high = NaN;
    return;
end
if value == 0
    low = 0;
    high = 0;
    return;
end
magnitude = abs(value);
exponent = floor(log10(magnitude));
quantum = 10^(exponent - digits + 1);
if ~isfinite_scalar(quantum) || quantum <= 0
    low = NaN;
    high = NaN;
    return;
end
if magnitude == 10^exponent
    previous_magnitude = magnitude - quantum / 10;
else
    previous_magnitude = magnitude - quantum;
end
next_magnitude = magnitude + quantum;
previous_magnitude = str2double(sprintf(format, previous_magnitude));
next_magnitude = str2double(sprintf(format, next_magnitude));
if value > 0
    previous = previous_magnitude;
    next = next_magnitude;
else
    previous = -next_magnitude;
    next = -previous_magnitude;
end
low = previous + (value - previous) / 2;
high = value + (next - value) / 2;
if str2double(sprintf(format, low)) ~= value
    low = next_double_toward(low, value);
end
if str2double(sprintf(format, high)) ~= value
    high = next_double_toward(high, value);
end
if ~is_finite_ordered_interval(low, high)
    low = NaN;
    high = NaN;
end
end

function tf = model_value_is_producer_compatible( ...
        actual, config_parameter, best_parameter)
if ~isfinite_scalar(actual) || ...
        actual ~= str2double(sprintf('%g', actual))
    tf = false;
    return;
end
[raw_low, raw_high] = serialized_decimal_interval( ...
    best_parameter.p_value_raw, 10);
if ~is_finite_ordered_interval(raw_low, raw_high)
    tf = false;
    return;
end
simulated = max(0, min(1, [raw_low raw_high]));
physical = [return_parameter_value(config_parameter, simulated(1)), ...
    return_parameter_value(config_parameter, simulated(2))];
if any(~isfinite(physical))
    tf = false;
    return;
end
writer_outputs = arrayfun( ...
    @(value) str2double(sprintf('%g', value)), physical);
if any(~isfinite(writer_outputs)) || writer_outputs(1) > writer_outputs(2)
    tf = false;
    return;
end
tf = actual >= min(writer_outputs) && actual <= max(writer_outputs);
end

function tf = is_finite_ordered_interval(low, high)
tf = isfinite_scalar(low) && isfinite_scalar(high) && low <= high;
end

function moved = next_double_toward(value, target)
if value == target
    moved = value;
    return;
end
if value == 0
    bits = uint64(1);
    if target < 0
        bits = bitor(bits, bitshift(uint64(1), 63));
    end
    moved = typecast(bits, 'double');
    return;
end
bits = typecast(value, 'uint64');
if (target > value) == (value > 0)
    bits = bits + uint64(1);
else
    bits = bits - uint64(1);
end
moved = typecast(bits, 'double');
end

function cells = text_cells(value)
if iscell(value)
    cells = cellfun(@(item) char(string(item)), value, ...
        'UniformOutput', false);
else
    cells = reshape(cellstr(string(value)), 1, []);
end
cells = reshape(cells, 1, []);
end

function tf = has_exact_fields(value, expected)
tf = isstruct(value) && isscalar(value) && ...
    isequal(sort(fieldnames(value)), sort(expected(:)));
end

function [top_fields, job_fields, parameter_fields, ...
        path_fields, control_fields] = optimization_contract(kind)
path_fields = {'model_template_file_string','fit_mode','fit_variable', ...
    'best_model_folder','best_opt_file_string'};
control_fields = {'max_fun_evals','tol_fun','tol_x', ...
    'figure_current_fit','figure_optimization_progress'};
job_fields = {'model_file_string','protocol_file_string', ...
    'options_file_string','results_file_string','fit_start_index', ...
    'target_file_string'};
top_fields = [path_fields control_fields {'parameter','job'}];
parameter_fields = {'name','min_value','max_value','p_value','p_mode'};
if strcmp(kind, 'best')
    top_fields = [top_fields ...
        {'model_working_file_string','best_model_file_string'}];
    parameter_fields{end+1} = 'p_value_raw';
elseif ~strcmp(kind, 'config')
    error('validate_mava_run_semantics:badContract', ...
        'Unknown optimization contract: %s.', kind);
end
end

function cells = as_cells(value)
if iscell(value)
    cells = value;
elseif isstruct(value)
    cells = num2cell(value);
else
    error('validate_mava_run_semantics:invalidManifest', ...
        'Expected a manifest cell or struct array.');
end
end
