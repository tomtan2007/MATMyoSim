function run = run_mava_sequential_analysis(run_id, mode, varargin)
% Build, execute, resume, or summarize one immutable sequential Mava run.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(script_dir);

run_id = char(string(run_id));
mode = char(string(mode));
valid_modes = {'dry_run','execute','resume','summarize'};
if ~ismember(mode, valid_modes)
    error('run_mava_sequential_analysis:badMode', ...
        'Mode must be dry_run, execute, resume, or summarize.');
end
if isempty(run_id) || contains(run_id, '/') || contains(run_id, '\\') || ...
        contains(run_id, '..')
    error('run_mava_sequential_analysis:badRunId', ...
        'Run ID must be a nonempty directory name.');
end

defaults = default_settings(repo_root, script_dir, run_id);
p = inputParser;
addParameter(p, 'output_root', defaults.output_root);
addParameter(p, 'restarts', defaults.restarts);
addParameter(p, 'extra_final_restarts', defaults.extra_final_restarts);
addParameter(p, 'max_fun_evals', defaults.max_fun_evals);
addParameter(p, 'tol_fun', defaults.tol_fun);
addParameter(p, 'tol_x', defaults.tol_x);
addParameter(p, 'fit_start_index', defaults.fit_start_index);
addParameter(p, 'scale_mode', defaults.scale_mode);
parse(p, varargin{:});

settings = defaults;
parsed = p.Results;
names = fieldnames(parsed);
for i = 1:numel(names)
    settings.(names{i}) = parsed.(names{i});
end
settings.run_id = run_id;
settings = validate_settings(settings);
run_dir = fullfile(settings.output_root, run_id);

manifest = mava_run_manifest(run_dir, settings, mode);
if strcmp(mode, 'summarize')
    if exist('summarize_mava_sequential_run', 'file') ~= 2
        error('run_mava_sequential_analysis:summarizerUnavailable', ...
            'Task 6 summarizer is not available on the current path.');
    end
    run = manifest;
    run.summary = summarize_mava_sequential_run(run_dir);
    return;
end

try
    if ismember(mode, {'dry_run','execute'})
        preprocess_policies(run_dir, settings);
    else
        validate_preprocessed_data(run_dir, settings);
    end

    if strcmp(mode, 'dry_run')
        records = plan_dry_run(run_dir, settings);
        manifest.records_planned = numel(records);
        manifest.status = 'dry_run_complete';
        write_json_atomic(fullfile(run_dir, 'manifest.json'), manifest);
        run = manifest;
        return;
    end

    manifest.status = 'running';
    manifest.mode = mode;
    write_json_atomic(fullfile(run_dir, 'manifest.json'), manifest);
    run_fits_serially(run_dir, settings, strcmp(mode, 'resume'));
    manifest.status = 'complete';
    write_json_atomic(fullfile(run_dir, 'manifest.json'), manifest);
    run = manifest;
catch ME
    record_run_failure(run_dir, ME);
    rethrow(ME);
end
end

function settings = default_settings(repo_root, script_dir, run_id)
settings = struct;
settings.run_id = run_id;
settings.repository_root = repo_root;
settings.output_root = fullfile(script_dir, 'output', 'runs');
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
settings.source_files = { ...
    fullfile(script_dir, 'prepare_mava_data.m'), ...
    fullfile(script_dir, 'detect_mava_trace_landmarks.m'), ...
    fullfile(script_dir, 'mava_alignment_shifts.m'), ...
    fullfile(script_dir, 'mava_parameter_stages.m'), ...
    fullfile(script_dir, 'mava_deterministic_start.m'), ...
    fullfile(script_dir, 'build_mava_sequential_fit_config.m'), ...
    fullfile(repo_root, 'Code', 'System', 'fit', 'fit_controller.m'), ...
    fullfile(repo_root, 'Code', 'System', 'fit', 'fit_worker.m'), ...
    fullfile(repo_root, 'Code', 'System', 'fit', 'update_json_model_file.m'), ...
    fullfile(repo_root, 'Code', 'System', 'fit', 'evaluate_time_fit.m')};
settings.alignment_groups = { ...
    struct('policy', 'shared_by_genotype', ...
    'genotypes', {{'Control','H251N'}}), ...
    struct('policy', 'independent_trace', ...
    'genotypes', {{'Control'}})};
settings.scale_mode = 'peak';
settings.fit_start_index = 481;
settings.restarts = 4;
settings.extra_final_restarts = 4;
settings.max_fun_evals = 1200;
settings.tol_fun = 1e-5;
settings.tol_x = 1e-3;
settings.stages = mava_parameter_stages();
end

function settings = validate_settings(settings)
settings.output_root = char(string(settings.output_root));
settings.scale_mode = char(string(settings.scale_mode));
if ~ismember(settings.scale_mode, {'peak','p95','least_squares'})
    error('run_mava_sequential_analysis:badScaleMode', ...
        'Unknown scaling mode: %s.', settings.scale_mode);
end
integer_fields = {'fit_start_index','restarts','extra_final_restarts', ...
    'max_fun_evals'};
for i = 1:numel(integer_fields)
    value = settings.(integer_fields{i});
    if ~isscalar(value) || ~isfinite(value) || value < 0 || value ~= floor(value)
        error('run_mava_sequential_analysis:badSetting', ...
            '%s must be a nonnegative integer.', integer_fields{i});
    end
end
if settings.fit_start_index < 1 || settings.restarts < 1 || ...
        settings.max_fun_evals < 1 || settings.tol_fun <= 0 || ...
        settings.tol_x <= 0
    error('run_mava_sequential_analysis:badSetting', ...
        'Fit controls must be positive (extra final restarts may be zero).');
end
end

function preprocess_policies(run_dir, settings)
policies = cellfun(@(g) g.policy, settings.alignment_groups, ...
    'UniformOutput', false);
policies = unique(policies, 'stable');
for i = 1:numel(policies)
    data_dir = fullfile(run_dir, 'data', policies{i});
    prepare_mava_data(settings.workbook_file, data_dir, ...
        settings.scale_mode, policies{i});
end
end

function validate_preprocessed_data(run_dir, settings)
policies = cellfun(@(g) g.policy, settings.alignment_groups, ...
    'UniformOutput', false);
policies = unique(policies, 'stable');
for i = 1:numel(policies)
    metrics_file = fullfile(run_dir, 'data', policies{i}, ...
        'experimental_metrics.csv');
    if ~isfile(metrics_file)
        error('run_mava_sequential_analysis:missingPreparedData', ...
            'Resume data are incomplete: %s.', metrics_file);
    end
end
end

function records = plan_dry_run(run_dir, settings)
records = {};
for group_index = 1:numel(settings.alignment_groups)
    group = settings.alignment_groups{group_index};
    for genotype_index = 1:numel(group.genotypes)
        genotype = group.genotypes{genotype_index};
        for stage_index = 1:numel(settings.stages)
            stage = settings.stages(stage_index);
            for restart = 1:settings.restarts
                [~, record] = build_mava_sequential_fit_config(run_dir, ...
                    group.policy, genotype, stage, restart, [], settings);
                write_result_status(record, 'planned', struct);
                records{end+1} = record; %#ok<AGROW>
            end
        end
    end
end
end

function run_fits_serially(run_dir, settings, is_resume)
for group_index = 1:numel(settings.alignment_groups)
    group = settings.alignment_groups{group_index};
    for genotype_index = 1:numel(group.genotypes)
        genotype = group.genotypes{genotype_index};
        previous_best = [];
        for stage_index = 1:numel(settings.stages)
            stage = settings.stages(stage_index);
            restart_count = settings.restarts;
            if stage_index == numel(settings.stages)
                restart_count = restart_count + settings.extra_final_restarts;
            end
            for restart = 1:restart_count
                inherited = [];
                if restart == 1 && stage_index > 1
                    inherited = previous_best;
                end
                [config_file, record] = get_or_create_config(run_dir, ...
                    group.policy, genotype, stage, restart, inherited, ...
                    settings, is_resume);
                if is_resume && result_is_complete(record)
                    continue;
                end
                execute_one_fit(config_file, record);
            end
            previous_best = best_stage_coordinates(run_dir, group.policy, ...
                genotype, stage, restart_count);
        end
    end
end
end

function [config_file, record] = get_or_create_config(run_dir, policy, ...
    genotype, stage, restart, previous_best, settings, is_resume)
config_file = fullfile(run_dir, 'configs', sprintf('%s__%s__%s__s%02d.json', ...
    policy, genotype, stage.id, restart));
result_dir = fullfile(run_dir, 'results', policy, genotype, stage.id, ...
    sprintf('s%02d', restart));
if ~isfile(config_file)
    [config_file, record] = build_mava_sequential_fit_config(run_dir, ...
        policy, genotype, stage, restart, previous_best, settings);
    write_result_status(record, 'planned', struct);
    return;
end
if ~is_resume
    error('run_mava_sequential_analysis:unexpectedExistingConfig', ...
        'New run unexpectedly contains a config: %s.', config_file);
end
record = struct('alignment_policy', policy, 'genotype', genotype, ...
    'stage', stage.id, 'restart', restart, 'config_file', config_file, ...
    'result_dir', result_dir, 'parameter_names', {stage.parameters});
validate_existing_config(config_file, stage, restart, previous_best, settings);
end

function validate_existing_config(config_file, stage, restart, ...
    previous_best, settings)
try
    loaded = loadjson(config_file);
    opt = loaded.MyoSim_optimization;
    names = cellfun(@(x) x.name, opt.parameter, 'UniformOutput', false);
    starts = cellfun(@(x) x.p_value, opt.parameter);
catch ME
    error('run_mava_sequential_analysis:invalidConfig', ...
        'Could not validate %s: %s', config_file, ME.message);
end
expected_start = mava_deterministic_start(numel(stage.parameters), ...
    restart, previous_best);
if ~isequal(names, stage.parameters) || ...
        max(abs(starts - expected_start)) > 1e-12 || ...
        opt.job{1}.fit_start_index ~= settings.fit_start_index || ...
        opt.max_fun_evals ~= settings.max_fun_evals || ...
        abs(opt.tol_fun - settings.tol_fun) > eps || ...
        abs(opt.tol_x - settings.tol_x) > eps
    error('run_mava_sequential_analysis:invalidConfig', ...
        'Existing config does not match immutable run settings: %s.', ...
        config_file);
end
end

function execute_one_fit(config_file, record)
write_result_status(record, 'running', struct);
try
    loaded = loadjson(config_file);
    opt = loaded.MyoSim_optimization;
    opt.model_working_file_string = opt.job{1}.model_file_string;
    opt.best_model_file_string = fullfile(record.result_dir, ...
        'model_best.json');
    fit_controller(opt);
    required = required_result_files(record.result_dir);
    for i = 1:numel(required)
        if ~isfile(required{i})
            error('run_mava_sequential_analysis:missingFitArtifact', ...
                'Fit did not create required artifact: %s.', required{i});
        end
    end
    details = struct('artifact_hashes', artifact_hashes(record.result_dir));
    write_result_status(record, 'complete', details);
catch ME
    details = struct('identifier', ME.identifier, 'message', ME.message);
    write_result_status(record, 'failed', details);
    rethrow(ME);
end
end

function complete = result_is_complete(record)
complete = false;
required = required_result_files(record.result_dir);
if ~all(cellfun(@isfile, required))
    return;
end
try
    model = loadjson(required{1});
    best = loadjson(required{2});
    fit = loadjson(required{3});
    status = loadjson(required{4});
    if ~isfield(model, 'MyoSim_model') || ...
            ~isfield(best, 'MyoSim_optimization') || ...
            ~isfield(fit, 'best_error') || ...
            ~isfield(status, 'status') || ~strcmp(status.status, 'complete') || ...
            ~strcmp(status.alignment_policy, record.alignment_policy) || ...
            ~strcmp(status.genotype, record.genotype) || ...
            ~strcmp(status.stage, record.stage) || ...
            status.restart ~= record.restart || ...
            ~isfield(status, 'artifact_hashes')
        return;
    end
    actual = artifact_hashes(record.result_dir);
    names = fieldnames(actual);
    for i = 1:numel(names)
        if ~strcmp(actual.(names{i}), status.artifact_hashes.(names{i}))
            return;
        end
    end
    complete = true;
catch
    complete = false;
end
end

function coordinates = best_stage_coordinates(run_dir, policy, genotype, ...
    stage, restart_count)
best_error = inf;
best_file = '';
for restart = 1:restart_count
    result_dir = fullfile(run_dir, 'results', policy, genotype, stage.id, ...
        sprintf('s%02d', restart));
    record = struct('alignment_policy', policy, 'genotype', genotype, ...
        'stage', stage.id, 'restart', restart, 'result_dir', result_dir);
    if ~result_is_complete(record)
        continue;
    end
    fit = loadjson(fullfile(result_dir, 'fit_results.json'));
    if fit.best_error < best_error
        best_error = fit.best_error;
        best_file = fullfile(result_dir, 'best_optimization.json');
    end
end
if isempty(best_file)
    error('run_mava_sequential_analysis:noCompleteStage', ...
        'Stage %s/%s/%s has no complete result.', policy, genotype, stage.id);
end
best = loadjson(best_file).MyoSim_optimization;
coordinates = cellfun(@(x) x.p_value, best.parameter);
end

function files = required_result_files(result_dir)
files = {fullfile(result_dir, 'model_best.json'), ...
    fullfile(result_dir, 'best_optimization.json'), ...
    fullfile(result_dir, 'fit_results.json'), ...
    fullfile(result_dir, 'status.json')};
end

function hashes = artifact_hashes(result_dir)
hashes = struct( ...
    'model_best', mava_sha256(fullfile(result_dir, 'model_best.json')), ...
    'best_optimization', mava_sha256(fullfile(result_dir, ...
    'best_optimization.json')), ...
    'fit_results', mava_sha256(fullfile(result_dir, 'fit_results.json')));
end

function write_result_status(record, status_name, details)
status = struct( ...
    'alignment_policy', record.alignment_policy, ...
    'genotype', record.genotype, ...
    'stage', record.stage, ...
    'restart', record.restart, ...
    'config_file', record.config_file, ...
    'config_sha256', mava_sha256(record.config_file), ...
    'status', status_name, ...
    'updated_at', char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')));
detail_names = fieldnames(details);
for i = 1:numel(detail_names)
    status.(detail_names{i}) = details.(detail_names{i});
end
write_json_atomic(fullfile(record.result_dir, 'status.json'), status);
end

function record_run_failure(run_dir, failure)
manifest_file = fullfile(run_dir, 'manifest.json');
if ~isfile(manifest_file), return; end
try
    manifest = loadjson(manifest_file);
    manifest.status = 'incomplete';
    manifest.failure = struct('identifier', failure.identifier, ...
        'message', failure.message);
    write_json_atomic(manifest_file, manifest);
catch
end
end

function write_json_atomic(file, value)
parent = fileparts(file);
if ~isfolder(parent), mkdir(parent); end
temporary = [tempname(parent) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary, 'w');
if fid < 0
    error('run_mava_sequential_analysis:writeFailed', ...
        'Could not write temporary JSON file: %s.', temporary);
end
file_cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', savejson('', value, 'FloatFormat', '%.17g'));
clear file_cleanup;
[ok, message] = movefile(temporary, file, 'f');
if ~ok
    error('run_mava_sequential_analysis:writeFailed', ...
        'Could not publish %s: %s', file, message);
end
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
