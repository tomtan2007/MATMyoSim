function manifest = mava_run_manifest(run_dir, settings, mode)
% Create a new immutable run manifest or validate an existing capsule.

run_dir = char(string(run_dir));
mode = char(string(mode));
creation_modes = {'dry_run', 'execute'};
validation_modes = {'resume', 'summarize'};
if ~ismember(mode, [creation_modes validation_modes])
    error('mava_run_manifest:badMode', 'Unsupported run mode: %s.', mode);
end

manifest_file = fullfile(run_dir, 'manifest.json');
if ismember(mode, creation_modes) && (isfolder(run_dir) || isfile(run_dir))
    error('mava_run_manifest:runExists', ...
        'Run capsule already exists: %s.', run_dir);
end
expected = build_manifest(run_dir, settings, mode);
if ismember(mode, creation_modes)
    mkdir(run_dir);
    write_json_atomic(manifest_file, expected);
    manifest = expected;
    return;
end

if ~isfile(manifest_file)
    error('mava_run_manifest:missingManifest', ...
        'Existing run has no manifest: %s.', manifest_file);
end
try
    manifest = loadjson(manifest_file);
catch ME
    error('mava_run_manifest:invalidManifest', ...
        'Could not read manifest %s: %s', manifest_file, ME.message);
end

try
    stored_integrity = value_signature(immutable_projection(manifest));
    stored_inputs = value_signature(input_projection(manifest));
    stored_materialization = value_signature(manifest.materialization);
    stored_state = value_signature(state_projection(manifest));
catch
    resume_mismatch('Stored manifest is missing integrity-protected fields.');
end
if ~strcmp(stored_integrity, manifest.immutable_signature)
    resume_mismatch('Stored immutable content does not match its signature.');
end
if ~strcmp(stored_inputs, manifest.input_signature)
    resume_mismatch('Stored input content does not match its signature.');
end
if ~strcmp(stored_materialization, manifest.materialization_signature)
    resume_mismatch('Stored materialization does not match its signature.');
end
if ~strcmp(stored_state, manifest.state_signature)
    resume_mismatch('Stored run state does not match its signature.');
end
if ~strcmp(value_signature(input_projection(expected)), ...
        manifest.input_signature)
    resume_mismatch('Current settings or input hashes do not match the run.');
end
validate_materialized_files(manifest);
end

function manifest = build_manifest(run_dir, settings, mode)
required = {'run_id','repository_root','workbook_file','protocol_file', ...
    'baseline_templates','options_files','source_files','alignment_groups', ...
    'scale_mode','fit_start_index','restarts','extra_final_restarts', ...
    'max_fun_evals','tol_fun','tol_x','stages'};
for i = 1:numel(required)
    if ~isfield(settings, required{i})
        error('mava_run_manifest:missingSetting', ...
            'Required manifest setting is missing: %s.', required{i});
    end
end

hashes = struct;
hashes.workbook = hash_record(settings.workbook_file);
hashes.protocol = hash_record(settings.protocol_file);
hashes.baseline_templates = struct( ...
    'Control', hash_record(settings.baseline_templates.Control), ...
    'H251N', hash_record(settings.baseline_templates.H251N));
hashes.options = struct( ...
    'Control', hash_record(settings.options_files.Control), ...
    'H251N', hash_record(settings.options_files.H251N));
hashes.sources = cell(1, numel(settings.source_files));
for i = 1:numel(settings.source_files)
    hashes.sources{i} = hash_record(settings.source_files{i});
end

controls = struct( ...
    'scale_mode', settings.scale_mode, ...
    'fit_start_index', settings.fit_start_index, ...
    'restarts', settings.restarts, ...
    'extra_final_restarts', settings.extra_final_restarts, ...
    'max_fun_evals', settings.max_fun_evals, ...
    'tol_fun', settings.tol_fun, ...
    'tol_x', settings.tol_x);
inventory = build_inventory(run_dir, settings);
materialization = struct( ...
    'optional_final_restarts_active', 0, ...
    'data_files', {build_data_inventory(run_dir, settings)}, ...
    'configs', {build_config_materialization(inventory)});

manifest = struct( ...
    'schema_version', 2, ...
    'run_id', settings.run_id, ...
    'run_dir', run_dir, ...
    'repository_root', settings.repository_root, ...
    'created_at', char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'repository_head', repository_head(settings.repository_root), ...
    'matlab_version', version, ...
    'hashes', hashes, ...
    'settings', controls, ...
    'groups', {settings.alignment_groups}, ...
    'stages', settings.stages, ...
    'inventory', {inventory}, ...
    'materialization', materialization, ...
    'creation_mode', mode, ...
    'mode', mode, ...
    'status', 'created', ...
    'records_planned', 0);
manifest.input_signature = value_signature(input_projection(manifest));
manifest.immutable_signature = value_signature(immutable_projection(manifest));
manifest.materialization_signature = value_signature(manifest.materialization);
manifest.state_signature = value_signature(state_projection(manifest));
end

function inventory = build_inventory(run_dir, settings)
comparison_count = sum(cellfun(@(group) numel(group.genotypes), ...
    settings.alignment_groups));
records_per_comparison = numel(settings.stages) * settings.restarts + ...
    settings.extra_final_restarts;
inventory = cell(1, comparison_count * records_per_comparison);
record_index = 0;
for group_index = 1:numel(settings.alignment_groups)
    group = settings.alignment_groups{group_index};
    for genotype_index = 1:numel(group.genotypes)
        genotype = group.genotypes{genotype_index};
        for stage_index = 1:numel(settings.stages)
            stage = settings.stages(stage_index);
            restart_count = settings.restarts;
            if stage_index == numel(settings.stages)
                restart_count = restart_count + settings.extra_final_restarts;
            end
            for restart = 1:restart_count
                required = double(restart <= settings.restarts);
                [strategy, seed, dry_run_seed] = declared_seed(stage_index, ...
                    numel(stage.parameters), restart);
                id = record_id(group.policy, genotype, stage.id, restart);
                config_file = fullfile(run_dir, 'configs', [id '.json']);
                result_dir = fullfile(run_dir, 'results', group.policy, ...
                    genotype, stage.id, sprintf('s%02d', restart));
                record_index = record_index + 1;
                inventory{record_index} = struct( ...
                    'id', id, ...
                    'alignment_policy', group.policy, ...
                    'genotype', genotype, ...
                    'stage', stage.id, ...
                    'restart', restart, ...
                    'required', required, ...
                    'config_file', config_file, ...
                    'result_dir', result_dir, ...
                    'seed_strategy', strategy, ...
                    'seed', seed, ...
                    'dry_run_seed', dry_run_seed, ...
                    'parameter_names', {stage.parameters}, ...
                    'bounds', {parameter_bounds(settings, genotype, stage)});
            end
        end
    end
end
end

function [strategy, seed, dry_run_seed] = declared_seed( ...
    stage_index, n_parameters, restart)
if restart == 1 && stage_index > 1
    strategy = 'preceding_stage_best_or_dry_run_midpoint';
    seed = [];
    dry_run_seed = 0.5 * ones(1, n_parameters);
elseif restart == 1
    strategy = 'midpoint';
    seed = 0.5 * ones(1, n_parameters);
    dry_run_seed = seed;
else
    strategy = 'deterministic_sequence';
    seed = mava_deterministic_start(n_parameters, restart, []);
    dry_run_seed = seed;
end
end

function bounds = parameter_bounds(settings, genotype, stage)
template_file = settings.baseline_templates.(genotype);
base = loadjson(template_file);
parameters = base.MyoSim_model.hs_props.parameters;
bounds = cell(1, numel(stage.parameters));
for i = 1:numel(stage.parameters)
    name = stage.parameters{i};
    center = log10(parameters.(name));
    bounds{i} = struct('name', name, 'min_value', center - 1, ...
        'max_value', center + 1, 'p_mode', 'log');
end
end

function records = build_data_inventory(run_dir, settings)
comparison_count = sum(cellfun(@(group) numel(group.genotypes), ...
    settings.alignment_groups));
records = cell(1, comparison_count);
record_index = 0;
for group_index = 1:numel(settings.alignment_groups)
    group = settings.alignment_groups{group_index};
    for genotype_index = 1:numel(group.genotypes)
        genotype = group.genotypes{genotype_index};
        target_id = genotype_target_id(genotype);
        data_dir = fullfile(run_dir, 'data', group.policy);
        id = sprintf('%s__%s', group.policy, genotype);
        record_index = record_index + 1;
        records{record_index} = struct( ...
            'id', id, ...
            'target_file', fullfile(data_dir, [target_id '_target.txt']), ...
            'target_sha256', '', ...
            'protocol_file', fullfile(data_dir, [target_id '_protocol.txt']), ...
            'protocol_sha256', '');
    end
end
end

function records = build_config_materialization(inventory)
records = cell(1, numel(inventory));
for i = 1:numel(inventory)
    records{i} = struct('id', inventory{i}.id, 'sha256', '');
end
end

function id = genotype_target_id(genotype)
switch genotype
    case 'Control'
        id = 'ctrl_acute';
    case 'H251N'
        id = 'hcm_acute';
    otherwise
        error('mava_run_manifest:unknownGenotype', ...
            'Unknown genotype in manifest: %s.', genotype);
end
end

function id = record_id(policy, genotype, stage, restart)
id = sprintf('%s__%s__%s__s%02d', policy, genotype, stage, restart);
end

function projection = input_projection(manifest)
projection = struct( ...
    'schema_version', manifest.schema_version, ...
    'run_id', manifest.run_id, ...
    'run_dir', manifest.run_dir, ...
    'repository_root', manifest.repository_root, ...
    'hashes', manifest.hashes, ...
    'settings', manifest.settings, ...
    'groups', {manifest.groups}, ...
    'stages', {normalize_stages(manifest.stages)}, ...
    'inventory', {manifest.inventory});
end

function projection = immutable_projection(manifest)
projection = input_projection(manifest);
projection.repository_head = manifest.repository_head;
projection.matlab_version = manifest.matlab_version;
projection.creation_mode = manifest.creation_mode;
end

function projection = state_projection(manifest)
projection = struct('mode', manifest.mode, 'status', manifest.status, ...
    'records_planned', manifest.records_planned);
if isfield(manifest, 'failure')
    projection.failure = manifest.failure;
end
end

function stages = normalize_stages(stages)
if isstruct(stages)
    stages = arrayfun(@(item) item, stages, 'UniformOutput', false);
end
end

function validate_materialized_files(manifest)
data_files = manifest.materialization.data_files;
for i = 1:numel(data_files)
    item = data_files{i};
    if strcmp(manifest.status, 'created') && ...
            isempty(item.target_sha256) && isempty(item.protocol_sha256) && ...
            ~isfile(item.target_file) && ~isfile(item.protocol_file)
        continue;
    end
    validate_required_hash(item.target_file, item.target_sha256, ...
        'prepared target');
    validate_required_hash(item.protocol_file, item.protocol_sha256, ...
        'prepared protocol');
end

configs = manifest.materialization.configs;
for i = 1:numel(configs)
    item = configs{i};
    inventory = manifest.inventory{i};
    if isempty(item.sha256)
        if isfile(inventory.config_file)
            resume_mismatch(sprintf( ...
                'Config exists without a manifest hash: %s.', ...
                inventory.config_file));
        end
    else
        validate_required_hash(inventory.config_file, item.sha256, 'config');
    end
end
end

function validate_required_hash(file, expected_hash, kind)
if isempty(expected_hash) || ~isfile(file) || ...
        ~strcmp(mava_sha256(file), expected_hash)
    resume_mismatch(sprintf('%s hash mismatch: %s.', kind, file));
end
end

function resume_mismatch(message)
error('mava_run_manifest:resumeMismatch', '%s', message);
end

function signature = value_signature(value)
bytes = unicode2native(jsonencode(value), 'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw_digest = typecast(engine.digest(), 'uint8');
signature = lower(reshape(dec2hex(raw_digest, 2).', 1, []));
end

function record = hash_record(file)
file = char(string(file));
if ~isfile(file)
    error('mava_run_manifest:missingInput', ...
        'Manifest input does not exist: %s.', file);
end
record = struct('path', file, 'sha256', mava_sha256(file));
end

function head = repository_head(repository_root)
quoted_root = strrep(char(string(repository_root)), '"', '\"');
[status, output] = system(sprintf('git -C "%s" rev-parse HEAD', quoted_root));
if status ~= 0
    error('mava_run_manifest:gitHeadFailed', ...
        'Could not resolve repository HEAD for %s.', repository_root);
end
head = strtrim(output);
end

function write_json_atomic(file, value)
parent = fileparts(file);
temporary = [tempname(parent) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary, 'w');
if fid < 0
    error('mava_run_manifest:writeFailed', ...
        'Could not write temporary manifest: %s.', temporary);
end
file_cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(value));
clear file_cleanup;
[ok, message] = movefile(temporary, file, 'f');
if ~ok
    error('mava_run_manifest:writeFailed', ...
        'Could not publish manifest %s: %s', file, message);
end
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
