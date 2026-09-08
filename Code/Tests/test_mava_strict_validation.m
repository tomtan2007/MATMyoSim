function test_mava_strict_validation
% Signed production capsules must reject semantic tampering before reporting.

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
run_dir = tempname;
blocker_dir = [run_dir '_simulation_blocker'];
mkdir(blocker_dir);
write_text(fullfile(blocker_dir, 'simulation_driver.m'), ...
    ['function varargout=simulation_driver(varargin)' newline ...
    'error(''fixture:simulationLaunched'',''Simulation launched.'');' newline ...
    'end' newline]);
cleanup = onCleanup(@() remove_fixture(run_dir, blocker_dir));
build_signed_fixture(repo_root, run_dir);
manifest = loadjson(fullfile(run_dir, 'manifest.json'));
active = cellfun(@(record) logical(record.required), manifest.inventory);
assert(sum(active) >= 2, ...
    'Summary preflight regression requires at least two active records.');

item = manifest.inventory{1};
validated = validate_mava_run_semantics(manifest, 1, 'signed');
expected_hashes = manifest.materialization.results{1};
assert(strcmp(validated{1}.model_best, ...
    expected_hashes.model_best_sha256) && ...
    strcmp(validated{1}.best_optimization, ...
    expected_hashes.best_optimization_sha256) && ...
    strcmp(validated{1}.fit_results, ...
    expected_hashes.fit_results_sha256) && ...
    strcmp(validated{1}.status, expected_hashes.status_sha256), ...
    'Strict validation must return all four verified result hashes.');

unsigned_manifest = manifest;
hash_fields = {'model_best_sha256','best_optimization_sha256', ...
    'fit_results_sha256','status_sha256'};
for i = 1:numel(hash_fields)
    unsigned_manifest.materialization.results{1}.(hash_fields{i}) = '';
end
unsigned_manifest = resign_manifest(unsigned_manifest);
write_json(fullfile(run_dir, 'manifest.json'), unsigned_manifest);
unsigned_hashes = validate_mava_run_semantics( ...
    unsigned_manifest, 1, 'unsigned');
sealed = mava_seal_result_materialization( ...
    run_dir, unsigned_manifest, 1, unsigned_hashes{1});
persisted = loadjson(fullfile(run_dir, 'manifest.json'));
mava_run_manifest(run_dir, fixture_settings(repo_root), 'resume');
validate_mava_run_semantics(persisted, 1, 'signed');
assert(strcmp(sealed.materialization.results{1}.status_sha256, ...
    unsigned_hashes{1}.status), ...
    'Successful synthetic completion must immediately seal all result hashes.');
sealed_bytes = fileread(fullfile(run_dir, 'manifest.json'));
different_hashes = unsigned_hashes{1};
different_hashes.model_best(1) = ...
    char('0' + (different_hashes.model_best(1) == '0'));
assert_throws(@() mava_seal_result_materialization( ...
    run_dir, sealed, 1, different_hashes), ...
    'mava_run_manifest:resumeMismatch', ...
    'A nonempty completed-result materialization must be append-only.');
assert(strcmp(fileread(fullfile(run_dir, 'manifest.json')), sealed_bytes), ...
    'Rejected result resealing must leave manifest bytes unchanged.');
write_json(fullfile(run_dir, 'manifest.json'), manifest);

config_bytes = fileread(item.config_file);
result_bytes = capture_result_bytes(item.result_dir);
out_of_bounds_manifest = make_valid_out_of_bounds_result(manifest, item);
validate_mava_run_semantics(out_of_bounds_manifest, 1, 'signed');
restore_result_bytes(item.result_dir, result_bytes);
write_json(fullfile(run_dir, 'manifest.json'), manifest);

boundary_manifest = make_rounding_boundary_result( ...
    manifest, item, 0.1256860070210033);
boundary_model = loadjson(fullfile(item.result_dir, 'model_best.json'));
assert(boundary_model.MyoSim_model.hs_props.parameters.k_1 == 1.00002, ...
    'Boundary fixture must preserve the real writer''s 1.00002 witness.');
validate_mava_run_semantics(boundary_manifest, 1, 'signed');
noncanonical_tamper = tamper_result( ...
    boundary_manifest, item, 'model_noncanonical_boundary', 1);
assert_throws(@() validate_mava_run_semantics( ...
    noncanonical_tamper, 1, 'signed'), ...
    'validate_mava_run_semantics:invalidModel', ...
    'The noncanonical 1.000019 value cannot be emitted by the %%g writer.');
nearby_tamper = tamper_result( ...
    boundary_manifest, item, 'model_nearby_boundary', 1);
assert_throws(@() validate_mava_run_semantics( ...
    nearby_tamper, 1, 'signed'), ...
    'validate_mava_run_semantics:invalidModel', ...
    'The adjacent 1.00003 model value must be outside the producer interval.');
restore_result_bytes(item.result_dir, result_bytes);
write_json(fullfile(run_dir, 'manifest.json'), manifest);

power_manifest = make_rounding_boundary_result( ...
    manifest, item, 0.12568188124611682);
power_model = loadjson(fullfile(item.result_dir, 'model_best.json'));
assert(power_model.MyoSim_model.hs_props.parameters.k_1 == 0.999996, ...
    'Power-boundary fixture must preserve the real writer''s 0.999996.');
validate_mava_run_semantics(power_manifest, 1, 'signed');
power_tamper = tamper_result( ...
    power_manifest, item, 'model_power_boundary', 1);
assert_throws(@() validate_mava_run_semantics( ...
    power_tamper, 1, 'signed'), ...
    'validate_mava_run_semantics:invalidModel', ...
    'Canonical 1.0 must not match the finer %%g cell below the boundary.');
restore_result_bytes(item.result_dir, result_bytes);
write_json(fullfile(run_dir, 'manifest.json'), manifest);

cases = {'target_path','protocol_path','options_path','template_path', ...
    'worker_path','results_path','result_directory','parameter_name', ...
    'parameter_order','parameter_bound','parameter_mode', ...
    'parameter_coordinate','fit_setting','job_template_override', ...
    'extra_job','initial_delta_hsl','parameter_target_name','parameter_job'};
for i = 1:numel(cases)
    write_text(item.config_file, config_bytes);
    tampered = tamper_config(loadjson(item.config_file), cases{i});
    write_json(item.config_file, tampered);
    changed_manifest = manifest;
    changed_manifest.materialization.configs{1}.sha256 = ...
        mava_sha256(item.config_file);
    changed_manifest.materialization.configs{1}.resolved_seed = ...
        cellfun(@(parameter) parameter.p_value, ...
        tampered.MyoSim_optimization.parameter);
    changed_manifest = resign_manifest(changed_manifest);
    write_json(fullfile(run_dir, 'manifest.json'), changed_manifest);
    assert_throws(@() validate_mava_run_semantics( ...
        changed_manifest, 1, 'signed'), ...
        'validate_mava_run_semantics:invalidConfig', ...
        'Coherently re-signed config tampering (%s) must be rejected.', ...
        cases{i});
end

write_text(item.config_file, config_bytes);
result_cases = {'status_identity','status_config_path','status_artifact_hash', ...
    'fit_missing_field','fit_nonfinite','fit_bad_string','fit_uppercase_aic', ...
    'fit_negative_error','fit_objective_below_error','fit_active_count', ...
    'fit_bad_aic', ...
    'best_parameter_name','best_parameter_bound','best_parameter_mode', ...
    'best_parameter_coordinate','best_raw_clamp_inconsistent', ...
    'best_noncanonical_raw_upper_model', ...
    'model_scheme','model_parameter', ...
    'best_job_template_override','best_extra_job', ...
    'best_initial_delta_hsl','best_parameter_target_name', ...
    'best_parameter_job','best_working_path','best_working_type', ...
    'best_model_path','best_model_type', ...
    'model_fixed_parameter','model_missing_structure'};
result_ids = {'invalidStatus','invalidStatus','invalidStatus', ...
    'invalidFitResult','invalidFitResult','invalidFitResult', ...
    'invalidFitResult','invalidFitResult','invalidFitResult', ...
    'invalidFitResult','invalidFitResult', ...
    'invalidBestOptimization','invalidBestOptimization', ...
    'invalidBestOptimization','invalidBestOptimization', ...
    'invalidBestOptimization', ...
    'invalidBestOptimization', ...
    'invalidModel','invalidModel','invalidBestOptimization', ...
    'invalidBestOptimization','invalidBestOptimization', ...
    'invalidBestOptimization','invalidBestOptimization', ...
    'invalidBestOptimization','invalidBestOptimization', ...
    'invalidBestOptimization','invalidBestOptimization', ...
    'invalidModel','invalidModel'};
for i = 1:numel(result_cases)
    restore_result_bytes(item.result_dir, result_bytes);
    changed_manifest = tamper_result(manifest, item, result_cases{i});
    write_json(fullfile(run_dir, 'manifest.json'), changed_manifest);
    assert_throws(@() validate_mava_run_semantics( ...
        changed_manifest, 1, 'signed'), ...
        ['validate_mava_run_semantics:' result_ids{i}], ...
        'Coherently re-signed result tampering (%s) must be rejected.', ...
        result_cases{i});
end

restore_result_bytes(item.result_dir, result_bytes);
write_text(item.config_file, config_bytes);
later_index = find(active, 1, 'last');
later_item = manifest.inventory{later_index};
later_result_bytes = capture_result_bytes(later_item.result_dir);
path_cases = {'best_working_path','best_model_path'};
addpath(blocker_dir, '-begin');
for i = 1:numel(path_cases)
    restore_result_bytes(later_item.result_dir, later_result_bytes);
    path_manifest = tamper_result( ...
        manifest, later_item, path_cases{i}, later_index);
    write_json(fullfile(run_dir, 'manifest.json'), path_manifest);
    [path_id, path_message] = capture_error( ...
        @() summarize_mava_sequential_run(run_dir));
    assert(strcmp(path_id, ...
        'validate_mava_run_semantics:invalidBestOptimization') && ...
        contains(path_message, later_item.id), ...
        ['Summary must reject later-record %s before the first ' ...
        'simulation. Got %s: %s'], path_cases{i}, path_id, path_message);
    assert(~isfolder(fullfile(run_dir, 'tables')) && ...
        ~isfolder(fullfile(run_dir, 'figures')), ...
        'Best-model path preflight must precede all summary output.');
end
restore_result_bytes(later_item.result_dir, later_result_bytes);
raw_escape_manifest = tamper_result(manifest, later_item, ...
    'best_noncanonical_raw_upper_model', later_index);
write_json(fullfile(run_dir, 'manifest.json'), raw_escape_manifest);
[raw_escape_id, raw_escape_message] = capture_error( ...
    @() summarize_mava_sequential_run(run_dir));
assert(strcmp(raw_escape_id, ...
    'validate_mava_run_semantics:invalidBestOptimization') && ...
    contains(raw_escape_message, later_item.id), ...
    ['Summary must reject the later-record noncanonical raw coordinate ' ...
    'before simulation. Got %s: %s'], raw_escape_id, raw_escape_message);
assert(~isfolder(fullfile(run_dir, 'tables')) && ...
    ~isfolder(fullfile(run_dir, 'figures')), ...
    'Noncanonical raw-coordinate preflight must precede summary output.');
rmpath(blocker_dir);
restore_result_bytes(later_item.result_dir, later_result_bytes);
write_json(fullfile(run_dir, 'manifest.json'), manifest);

preflight_manifest = manifest;
config = loadjson(later_item.config_file);
config.MyoSim_optimization.job{1}.target_file_string = ...
    config.MyoSim_optimization.job{1}.protocol_file_string;
write_json(later_item.config_file, config);
preflight_manifest.materialization.configs{later_index}.sha256 = ...
    mava_sha256(later_item.config_file);
status_file = fullfile(later_item.result_dir, 'status.json');
status = loadjson(status_file);
status.config_sha256 = mava_sha256(later_item.config_file);
write_json(status_file, status);
preflight_manifest.materialization.results{later_index}.status_sha256 = ...
    mava_sha256(status_file);
preflight_manifest = resign_manifest(preflight_manifest);
write_json(fullfile(run_dir, 'manifest.json'), preflight_manifest);
addpath(blocker_dir, '-begin');
[preflight_id, preflight_message] = capture_error( ...
    @() summarize_mava_sequential_run(run_dir));
assert(strcmp(preflight_id, 'validate_mava_run_semantics:invalidConfig') && ...
    contains(preflight_message, later_item.id), ...
    ['Summary must reject the later invalid record before launching the ' ...
    'first simulation. Got %s: %s'], preflight_id, preflight_message);
rmpath(blocker_dir);
assert(~isfolder(fullfile(run_dir, 'tables')) && ...
    ~isfolder(fullfile(run_dir, 'figures')), ...
    'Semantic validation must fail before creating summary outputs.');

fprintf('PASS: strict Mava capsule semantic validation\n');
end

function manifest = build_signed_fixture(repo_root, run_dir)
settings = fixture_settings(repo_root);
manifest = mava_run_manifest(run_dir, settings, 'execute');
data = manifest.materialization.data_files{1};
if ~isfolder(fileparts(data.target_file)), mkdir(fileparts(data.target_file)); end
target = (0:19)';
protocol = table(0.001*ones(20,1), 6.5*ones(20,1), ...
    'VariableNames', {'dt','pCa'});
metrics = table(["ctrl_before";"ctrl_acute"], ...
    ["Control";"Control"], [100;35], ...
    'VariableNames', {'id','genotype','peak_force'});
writematrix(target, data.target_file, 'Delimiter', 'tab');
writetable(protocol, data.protocol_file, 'FileType', 'text', ...
    'Delimiter', '\t');
writetable(metrics, data.metrics_file);
data.target_sha256 = mava_sha256(data.target_file);
data.protocol_sha256 = mava_sha256(data.protocol_file);
data.metrics_sha256 = mava_sha256(data.metrics_file);
manifest.materialization.data_files{1} = data;

for record_index = 1:numel(manifest.inventory)
    item = manifest.inventory{record_index};
    [config_file, ~] = build_mava_sequential_fit_config(run_dir, ...
        item.alignment_policy, item.genotype, settings.stages(1), ...
        item.restart, [], settings);
    config = loadjson(config_file);
    opt = config.MyoSim_optimization;
    materialized = manifest.materialization.configs{record_index};
    materialized.sha256 = mava_sha256(config_file);
    materialized.resolved_seed = ...
        cellfun(@(parameter) parameter.p_value, opt.parameter);
    manifest.materialization.configs{record_index} = materialized;
    artifact_hashes = write_real_result(item, opt);
    entry = manifest.materialization.results{record_index};
    entry.model_best_sha256 = artifact_hashes.model_best;
    entry.best_optimization_sha256 = artifact_hashes.best_optimization;
    entry.fit_results_sha256 = artifact_hashes.fit_results;
    entry.status_sha256 = artifact_hashes.status;
    manifest.materialization.results{record_index} = entry;
end
manifest.mode = 'execute';
manifest.status = 'complete';
manifest.records_planned = numel(manifest.inventory);
manifest = resign_manifest(manifest);
write_json(fullfile(run_dir, 'manifest.json'), manifest);
end

function hashes = write_real_result(item, opt)
if ~isfolder(item.result_dir), mkdir(item.result_dir); end
model_file = fullfile(item.result_dir, 'model_best.json');
best_file = fullfile(item.result_dir, 'best_optimization.json');
fit_file = fullfile(item.result_dir, 'fit_results.json');
status_file = fullfile(item.result_dir, 'status.json');
opt.model_working_file_string = opt.job{1}.model_file_string;
opt.best_model_file_string = model_file;
start = cellfun(@(parameter) parameter.p_value, opt.parameter);
update_json_model_file(opt, 1, start, {});
opt.test_objective = @(p) 0.1 + sum((p - start).^2);
fit_controller(opt);
hashes = struct('model_best', mava_sha256(model_file), ...
    'best_optimization', mava_sha256(best_file), ...
    'fit_results', mava_sha256(fit_file));
status = struct('alignment_policy', item.alignment_policy, ...
    'genotype', item.genotype, 'stage', item.stage, ...
    'restart', item.restart, 'config_file', item.config_file, ...
    'config_sha256', mava_sha256(item.config_file), ...
    'status', 'complete', 'updated_at', '2026-09-08T12:00:00-04:00', ...
    'artifact_hashes', hashes);
write_json(status_file, status);
hashes.status = mava_sha256(status_file);
end

function settings = fixture_settings(repo_root)
settings = struct;
settings.run_id = 'strict_fixture';
settings.repository_root = repo_root;
settings.workbook_file = fullfile(repo_root, 'Code', 'System', ...
    'experimental_data', 'Mava data.xlsx');
settings.protocol_file = fullfile(repo_root, 'Code', 'System', ...
    'protocols', 'protocol_1s.txt');
settings.baseline_templates = struct( ...
    'Control', fullfile(repo_root, 'Code', 'Fitting', ...
    'twitch_6state_control', 'temp', 'best', 'model_best.json'), ...
    'H251N', fullfile(repo_root, 'Code', 'Fitting', ...
    'twitch_6state_HCM', 'temp', 'best', 'model_best.json'));
settings.options_files = struct( ...
    'Control', fullfile(repo_root, 'Code', 'Fitting', ...
    'twitch_6state_control', 'sim_input', 'sim_options.json'), ...
    'H251N', fullfile(repo_root, 'Code', 'Fitting', ...
    'twitch_6state_HCM', 'sim_input', 'sim_options.json'));
settings.source_files = {fullfile(repo_root, 'Code', 'Fitting', ...
    'mava_codex', 'mava_run_manifest.m')};
settings.alignment_groups = {struct('policy', 'shared_by_genotype', ...
    'genotypes', {{'Control'}})};
settings.scale_mode = 'peak';
settings.fit_start_index = 5;
settings.restarts = 2;
settings.extra_final_restarts = 0;
settings.max_fun_evals = 10;
settings.tol_fun = 1e-5;
settings.tol_x = 1e-3;
all_stages = mava_parameter_stages();
settings.stages = all_stages(1);
end

function manifest = resign_manifest(manifest)
normalized_stages = manifest.stages;
if isstruct(normalized_stages)
    normalized_stages = arrayfun(@(item) item, normalized_stages, ...
        'UniformOutput', false);
end
inputs = struct('schema_version', manifest.schema_version, ...
    'run_id', manifest.run_id, 'run_dir', manifest.run_dir, ...
    'repository_root', manifest.repository_root, 'hashes', manifest.hashes, ...
    'settings', manifest.settings, 'groups', {manifest.groups}, ...
    'stages', {normalized_stages}, 'inventory', {manifest.inventory});
immutable = inputs;
immutable.created_at = manifest.created_at;
immutable.repository_head = manifest.repository_head;
immutable.matlab_version = manifest.matlab_version;
immutable.creation_mode = manifest.creation_mode;
state = struct('mode', manifest.mode, 'status', manifest.status, ...
    'records_planned', manifest.records_planned);
manifest.input_signature = test_signature(inputs);
manifest.immutable_signature = test_signature(immutable);
manifest.materialization_signature = test_signature(manifest.materialization);
manifest.state_signature = test_signature(state);
end

function root = tamper_config(root, kind)
opt = root.MyoSim_optimization;
job = opt.job{1};
switch kind
    case 'target_path'
        job.target_file_string = job.protocol_file_string;
    case 'protocol_path'
        job.protocol_file_string = job.target_file_string;
    case 'options_path'
        job.options_file_string = opt.model_template_file_string;
    case 'template_path'
        opt.model_template_file_string = job.options_file_string;
    case 'worker_path'
        job.model_file_string = job.target_file_string;
    case 'results_path'
        job.results_file_string = job.target_file_string;
    case 'result_directory'
        opt.best_model_folder = fileparts(job.target_file_string);
    case 'parameter_name'
        opt.parameter{1}.name = 'not_k_1';
    case 'parameter_order'
        opt.parameter = opt.parameter([2 1 3]);
    case 'parameter_bound'
        opt.parameter{1}.min_value = opt.parameter{1}.min_value + 0.1;
    case 'parameter_mode'
        opt.parameter{1}.p_mode = 'linear';
    case 'parameter_coordinate'
        opt.parameter{1}.p_value = 0.7;
    case 'fit_setting'
        opt.max_fun_evals = opt.max_fun_evals + 1;
    case 'job_template_override'
        job.model_template_file_string = opt.model_template_file_string;
    case 'extra_job'
        opt.job{2} = job;
    case 'initial_delta_hsl'
        opt.initial_delta_hsl = 100;
    case 'parameter_target_name'
        opt.parameter{1}.target_name = 'k_2';
    case 'parameter_job'
        opt.parameter{1}.job = 1;
    otherwise
        error('test_mava_strict_validation:badCase', ...
            'Unknown config tamper case %s.', kind);
end
opt.job{1} = job;
root.MyoSim_optimization = opt;
end

function manifest = tamper_result(manifest, item, kind, index)
if nargin < 4, index = 1; end
model_file = fullfile(item.result_dir, 'model_best.json');
best_file = fullfile(item.result_dir, 'best_optimization.json');
fit_file = fullfile(item.result_dir, 'fit_results.json');
status_file = fullfile(item.result_dir, 'status.json');
model = loadjson(model_file);
best = loadjson(best_file);
fit = loadjson(fit_file);
status = loadjson(status_file);
switch kind
    case 'status_identity'
        status.genotype = 'H251N';
    case 'status_config_path'
        status.config_file = fit_file;
    case 'status_artifact_hash'
        status.artifact_hashes.fit_results(1) = '0';
    case 'fit_missing_field'
        fit = rmfield(fit, 'n_active_points');
    case 'fit_nonfinite'
        fit.best_error = [];
    case 'fit_bad_string'
        fit.algorithm = 7;
    case 'fit_uppercase_aic'
        fit.AIC = [];
    case 'fit_negative_error'
        fit.best_error = -1;
    case 'fit_objective_below_error'
        fit.best_objective = 0.5 * fit.best_error;
    case 'fit_active_count'
        fit.n_active_points = fit.n_active_points + 1;
    case 'fit_bad_aic'
        fit.aic = fit.aic + 10;
    case 'best_parameter_name'
        best.MyoSim_optimization.parameter{1}.name = 'not_k_1';
    case 'best_parameter_bound'
        best.MyoSim_optimization.parameter{1}.max_value = ...
            best.MyoSim_optimization.parameter{1}.max_value + 0.1;
    case 'best_parameter_mode'
        best.MyoSim_optimization.parameter{1}.p_mode = 'linear';
    case 'best_parameter_coordinate'
        best.MyoSim_optimization.parameter{1}.p_value = [];
    case 'best_raw_clamp_inconsistent'
        best.MyoSim_optimization.parameter{1}.p_value_raw = 42;
    case 'best_noncanonical_raw_upper_model'
        best.MyoSim_optimization.parameter{1}.p_value = 0.125686007;
        best.MyoSim_optimization.parameter{1}.p_value_raw = ...
            0.1256860070210033;
        model.MyoSim_model.hs_props.parameters.k_1 = 56.0576;
    case 'model_scheme'
        model.MyoSim_model.hs_props.kinetic_scheme = 'wrong_scheme';
    case 'model_parameter'
        name = best.MyoSim_optimization.parameter{1}.name;
        model.MyoSim_model.hs_props.parameters.(name) = ...
            model.MyoSim_model.hs_props.parameters.(name) * 2;
    case 'model_nearby_boundary'
        model.MyoSim_model.hs_props.parameters.k_1 = 1.00003;
    case 'model_noncanonical_boundary'
        model.MyoSim_model.hs_props.parameters.k_1 = 1.000019;
    case 'model_power_boundary'
        model.MyoSim_model.hs_props.parameters.k_1 = 1.0;
    case 'best_job_template_override'
        best.MyoSim_optimization.job{1}.model_template_file_string = ...
            best.MyoSim_optimization.model_template_file_string;
    case 'best_extra_job'
        best.MyoSim_optimization.job{2} = ...
            best.MyoSim_optimization.job{1};
    case 'best_initial_delta_hsl'
        best.MyoSim_optimization.initial_delta_hsl = 100;
    case 'best_parameter_target_name'
        best.MyoSim_optimization.parameter{1}.target_name = 'k_2';
    case 'best_parameter_job'
        best.MyoSim_optimization.parameter{1}.job = 1;
    case 'best_working_path'
        best.MyoSim_optimization.model_working_file_string = fit_file;
    case 'best_working_type'
        best.MyoSim_optimization.model_working_file_string = 7;
    case 'best_model_path'
        best.MyoSim_optimization.best_model_file_string = fit_file;
    case 'best_model_type'
        best.MyoSim_optimization.best_model_file_string = 7;
    case 'model_fixed_parameter'
        model.MyoSim_model.hs_props.parameters.k_cb = 42;
    case 'model_missing_structure'
        hs_props = struct( ...
            'kinetic_scheme', model.MyoSim_model.hs_props.kinetic_scheme, ...
            'parameters', model.MyoSim_model.hs_props.parameters);
        model.MyoSim_model = struct('hs_props', hs_props);
    otherwise
        error('test_mava_strict_validation:badCase', ...
            'Unknown result tamper case %s.', kind);
end
write_json(model_file, model);
write_json(best_file, best);
write_json(fit_file, fit);
if ~strcmp(kind, 'status_artifact_hash')
    status.artifact_hashes = struct( ...
        'model_best', mava_sha256(model_file), ...
        'best_optimization', mava_sha256(best_file), ...
        'fit_results', mava_sha256(fit_file));
end
write_json(status_file, status);
entry = manifest.materialization.results{index};
entry.model_best_sha256 = mava_sha256(model_file);
entry.best_optimization_sha256 = mava_sha256(best_file);
entry.fit_results_sha256 = mava_sha256(fit_file);
entry.status_sha256 = mava_sha256(status_file);
manifest.materialization.results{index} = entry;
manifest = resign_manifest(manifest);
end

function manifest = make_valid_out_of_bounds_result(manifest, item)
model_file = fullfile(item.result_dir, 'model_best.json');
best_file = fullfile(item.result_dir, 'best_optimization.json');
fit_file = fullfile(item.result_dir, 'fit_results.json');
status_file = fullfile(item.result_dir, 'status.json');
best = loadjson(best_file).MyoSim_optimization;
best.parameter{1}.p_value_raw = 42;
best.parameter{1}.p_value = 1;
write_text(best_file, savejson('MyoSim_optimization', best));
coordinates = cellfun(@(parameter) parameter.p_value, best.parameter);
update_json_model_file(best, 1, coordinates, {});
copyfile(best.job{1}.model_file_string, model_file);
fit = loadjson(fit_file);
fit.best_objective = fit.best_error + 1e4 * (42 - 1)^2;
write_text(fit_file, savejson('', fit));
status = loadjson(status_file);
status.artifact_hashes = struct( ...
    'model_best', mava_sha256(model_file), ...
    'best_optimization', mava_sha256(best_file), ...
    'fit_results', mava_sha256(fit_file));
write_json(status_file, status);
entry = manifest.materialization.results{1};
entry.model_best_sha256 = status.artifact_hashes.model_best;
entry.best_optimization_sha256 = status.artifact_hashes.best_optimization;
entry.fit_results_sha256 = status.artifact_hashes.fit_results;
entry.status_sha256 = mava_sha256(status_file);
manifest.materialization.results{1} = entry;
manifest = resign_manifest(manifest);
write_json(fullfile(manifest.run_dir, 'manifest.json'), manifest);
end

function manifest = make_rounding_boundary_result( ...
        manifest, item, raw_coordinate)
model_file = fullfile(item.result_dir, 'model_best.json');
best_file = fullfile(item.result_dir, 'best_optimization.json');
fit_file = fullfile(item.result_dir, 'fit_results.json');
status_file = fullfile(item.result_dir, 'status.json');
config = loadjson(item.config_file).MyoSim_optimization;
config.model_working_file_string = config.job{1}.model_file_string;
config.best_model_file_string = model_file;
coordinates = cellfun(@(parameter) parameter.p_value, config.parameter);
coordinates(1) = raw_coordinate;
update_json_model_file(config, 1, coordinates, {});
copyfile(config.job{1}.model_file_string, model_file);
for i = 1:numel(config.parameter)
    config.parameter{i}.p_value_raw = coordinates(i);
    config.parameter{i}.p_value = max(0, min(1, coordinates(i)));
end
write_text(best_file, savejson('MyoSim_optimization', config));
status = loadjson(status_file);
status.artifact_hashes = struct( ...
    'model_best', mava_sha256(model_file), ...
    'best_optimization', mava_sha256(best_file), ...
    'fit_results', mava_sha256(fit_file));
write_json(status_file, status);
entry = manifest.materialization.results{1};
entry.model_best_sha256 = status.artifact_hashes.model_best;
entry.best_optimization_sha256 = status.artifact_hashes.best_optimization;
entry.fit_results_sha256 = status.artifact_hashes.fit_results;
entry.status_sha256 = mava_sha256(status_file);
manifest.materialization.results{1} = entry;
manifest = resign_manifest(manifest);
write_json(fullfile(manifest.run_dir, 'manifest.json'), manifest);
end

function bytes = capture_result_bytes(result_dir)
names = {'model_best.json','best_optimization.json', ...
    'fit_results.json','status.json'};
bytes = cell(1, numel(names));
for i = 1:numel(names)
    bytes{i} = fileread(fullfile(result_dir, names{i}));
end
end

function restore_result_bytes(result_dir, bytes)
names = {'model_best.json','best_optimization.json', ...
    'fit_results.json','status.json'};
for i = 1:numel(names)
    write_text(fullfile(result_dir, names{i}), bytes{i});
end
end

function signature = test_signature(value)
bytes = unicode2native(jsonencode(value), 'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw_digest = typecast(engine.digest(), 'uint8');
signature = lower(reshape(dec2hex(raw_digest, 2).', 1, []));
end

function write_json(file, value)
parent = fileparts(file);
if ~isfolder(parent), mkdir(parent); end
fid = fopen(file, 'w');
assert(fid >= 0, 'Could not write strict-validation fixture %s.', file);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(value));
end

function write_text(file, value)
fid = fopen(file, 'w');
assert(fid >= 0, 'Could not write strict-validation fixture %s.', file);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', value);
end

function assert_throws(f, identifier, message, varargin)
try
    f();
catch ME
    assert(strcmp(ME.identifier, identifier), ...
        [message ' Expected %s, got %s: %s'], varargin{:}, ...
        identifier, ME.identifier, ME.message);
    return;
end
error('test_mava_strict_validation:noError', message, varargin{:});
end

function [identifier, message] = capture_error(f)
identifier = '';
message = '';
try
    f();
catch ME
    identifier = ME.identifier;
    message = ME.message;
end
end

function remove_fixture(run_dir, blocker_dir)
if contains(path, blocker_dir), rmpath(blocker_dir); end
if isfolder(run_dir), rmdir(run_dir, 's'); end
if isfolder(blocker_dir), rmdir(blocker_dir, 's'); end
end
