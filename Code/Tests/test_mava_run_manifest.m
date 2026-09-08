function test_mava_run_manifest
% Run manifests must be immutable and validate all provenance on resume.

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
run_dir = tempname;
cleanup = onCleanup(@() remove_if_present(run_dir));
settings = fixture_settings(repo_root);

manifest = mava_run_manifest(run_dir, settings, 'dry_run');
assert(isfile(fullfile(run_dir, 'manifest.json')), ...
    'Creating a run must atomically publish manifest.json.');
assert(strcmp(manifest.run_id, 'manifest_fixture') && ...
    strcmp(manifest.run_dir, run_dir), ...
    'Manifest must identify the exact run capsule.');
assert(strcmp(manifest.mode, 'dry_run') && strcmp(manifest.status, 'created'), ...
    'A new dry run must begin in created status.');
assert(strcmp(manifest.hashes.workbook.sha256, ...
    mava_sha256(settings.workbook_file)), ...
    'Manifest did not record the workbook hash.');
assert(strcmp(manifest.hashes.protocol.sha256, ...
    mava_sha256(settings.protocol_file)), ...
    'Manifest did not record the protocol hash.');
assert(strcmp(manifest.hashes.baseline_templates.Control.sha256, ...
    mava_sha256(settings.baseline_templates.Control)), ...
    'Manifest did not record the Control baseline-template hash.');
assert(strcmp(manifest.hashes.baseline_templates.H251N.sha256, ...
    mava_sha256(settings.baseline_templates.H251N)), ...
    'Manifest did not record the H251N baseline-template hash.');
assert(numel(manifest.hashes.sources) >= 3, ...
    'Manifest must hash enough fitting sources to audit behavior.');
assert(manifest.settings.fit_start_index == 481 && ...
    manifest.settings.restarts == 4 && ...
    manifest.settings.extra_final_restarts == 4, ...
    'Manifest omitted immutable fit controls.');
assert(numel(manifest.groups) == 2 && numel(manifest.stages) == 4, ...
    'Manifest omitted the exact alignment groups or parameter stages.');
required_inventory = cellfun(@(item) item.required, manifest.inventory);
assert(numel(required_inventory) == 60 && sum(required_inventory) == 48, ...
    ['Default manifest must plan 48 active base fits while declaring 12 ' ...
    'inactive optional final-stage restarts.']);

duplicate_id = '';
try
    mava_run_manifest(run_dir, settings, 'execute');
catch ME
    duplicate_id = ME.identifier;
end
assert(strcmp(duplicate_id, 'mava_run_manifest:runExists'), ...
    'Duplicate run creation must fail instead of overwriting the capsule.');

resumed = mava_run_manifest(run_dir, settings, 'resume');
assert(strcmp(resumed.run_id, manifest.run_id), ...
    'Matching resume settings must validate the existing manifest.');

manifest_bytes = fileread(fullfile(run_dir, 'manifest.json'));
legacy = resumed;
legacy.schema_version = 3;
legacy = resign_manifest(legacy);
write_json(fullfile(run_dir, 'manifest.json'), legacy);
[legacy_id, legacy_message] = manifest_resume_error(run_dir, settings);
assert(strcmp(legacy_id, 'mava_run_manifest:unsupportedSchemaVersion') && ...
    contains(legacy_message, 'schema version 3') && ...
    contains(legacy_message, 'version 4'), ...
    'Schema-v3 capsules must receive an explicit unsupported-version error.');
write_text(fullfile(run_dir, 'manifest.json'), manifest_bytes);

item = resumed.inventory{1};
if ~isfolder(item.result_dir), mkdir(item.result_dir); end
model_file = fullfile(item.result_dir, 'model_best.json');
best_file = fullfile(item.result_dir, 'best_optimization.json');
fit_file = fullfile(item.result_dir, 'fit_results.json');
status_file = fullfile(item.result_dir, 'status.json');
write_json(model_file, struct('MyoSim_model', struct));
write_json(best_file, struct('MyoSim_optimization', struct));
write_json(fit_file, struct('best_error', 0.1));
status = struct('status', 'complete', ...
    'alignment_policy', item.alignment_policy, ...
    'genotype', item.genotype, 'stage', item.stage, ...
    'restart', item.restart);
write_json(status_file, status);
unsigned_snapshot = result_snapshot(item.result_dir);
unsigned_id = manifest_resume_identifier(run_dir, settings);
assert(strcmp(unsigned_id, 'mava_run_manifest:resumeMismatch'), ...
    ['A completed-looking result without a signed materialization entry ' ...
    'must fail closed.']);
assert(isequal(unsigned_snapshot, result_snapshot(item.result_dir)), ...
    'Fail-closed validation must not change completed result bytes.');

signed = resumed;
entry = signed.materialization.results{1};
entry.model_best_sha256 = mava_sha256(model_file);
entry.best_optimization_sha256 = mava_sha256(best_file);
entry.fit_results_sha256 = mava_sha256(fit_file);
entry.status_sha256 = mava_sha256(status_file);
signed.materialization.results{1} = entry;
signed = resign_manifest(signed);
write_json(fullfile(run_dir, 'manifest.json'), signed);
mava_run_manifest(run_dir, settings, 'resume');

artifact_files = {model_file,best_file,fit_file,status_file};
for i = 1:numel(artifact_files)
    original = fileread(artifact_files{i});
    write_text(artifact_files{i}, [original ' ']);
    tampered_snapshot = result_snapshot(item.result_dir);
    tamper_id = manifest_resume_identifier(run_dir, settings);
    assert(strcmp(tamper_id, 'mava_run_manifest:resumeMismatch'), ...
        'Tampering with completed artifact %d must fail closed.', i);
    assert(isequal(tampered_snapshot, result_snapshot(item.result_dir)), ...
        'Completed artifact validation must not rewrite result bytes.');
    write_text(artifact_files{i}, original);
end

manifest_bytes = fileread(fullfile(run_dir, 'manifest.json'));
tampered = resumed;
tampered.settings.fit_start_index = 777;
tampered.groups{1}.policy = 'tampered_policy';
tampered.hashes.workbook.sha256(1) = '0';
write_json(fullfile(run_dir, 'manifest.json'), tampered);
integrity_id = '';
try
    mava_run_manifest(run_dir, settings, 'resume');
catch ME
    integrity_id = ME.identifier;
end
assert(strcmp(integrity_id, 'mava_run_manifest:resumeMismatch'), ...
    'Persisted settings/groups/hashes must be checked against their signature.');
write_text(fullfile(run_dir, 'manifest.json'), manifest_bytes);

tampered = resumed;
tampered.created_at = '2099-01-01T00:00:00-05:00';
write_json(fullfile(run_dir, 'manifest.json'), tampered);
created_at_id = '';
try
    mava_run_manifest(run_dir, settings, 'resume');
catch ME
    created_at_id = ME.identifier;
end
assert(strcmp(created_at_id, 'mava_run_manifest:resumeMismatch'), ...
    'Creation time must be part of the signed immutable projection.');
write_text(fullfile(run_dir, 'manifest.json'), manifest_bytes);

changed = settings;
changed.fit_start_index = 482;
mismatch_id = '';
try
    mava_run_manifest(run_dir, changed, 'resume');
catch ME
    mismatch_id = ME.identifier;
end
assert(strcmp(mismatch_id, 'mava_run_manifest:resumeMismatch'), ...
    'Changed fit_start_index must raise the exact resume-mismatch identifier.');

fprintf('PASS: immutable Mava run manifest\n');
end

function settings = fixture_settings(repo_root)
settings = struct;
settings.run_id = 'manifest_fixture';
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
settings.source_files = { ...
    fullfile(repo_root, 'Code', 'Fitting', 'mava_codex', 'prepare_mava_data.m'), ...
    fullfile(repo_root, 'Code', 'Fitting', 'mava_codex', ...
        'build_mava_sequential_fit_config.m'), ...
    fullfile(repo_root, 'Code', 'System', 'fit', 'fit_controller.m')};
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

function remove_if_present(folder)
if isfolder(folder), rmdir(folder, 's'); end
end

function write_json(file, value)
write_text(file, jsonencode(value));
end

function write_text(file, value)
fid = fopen(file, 'w');
assert(fid >= 0, 'Could not write manifest integrity fixture.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', value);
clear cleanup;
end

function identifier = manifest_resume_identifier(run_dir, settings)
[identifier, ~] = manifest_resume_error(run_dir, settings);
end

function [identifier, message] = manifest_resume_error(run_dir, settings)
identifier = '';
message = '';
try
    mava_run_manifest(run_dir, settings, 'resume');
catch ME
    identifier = ME.identifier;
    message = ME.message;
end
end

function manifest = resign_manifest(manifest)
inputs = struct( ...
    'schema_version', manifest.schema_version, ...
    'run_id', manifest.run_id, ...
    'run_dir', manifest.run_dir, ...
    'repository_root', manifest.repository_root, ...
    'hashes', manifest.hashes, ...
    'settings', manifest.settings, ...
    'groups', {manifest.groups}, ...
    'stages', {manifest.stages}, ...
    'inventory', {manifest.inventory});
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

function signature = test_signature(value)
bytes = unicode2native(jsonencode(value), 'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw_digest = typecast(engine.digest(), 'uint8');
signature = lower(reshape(dec2hex(raw_digest, 2).', 1, []));
end

function snapshot = result_snapshot(result_dir)
files = dir(fullfile(result_dir, '*'));
files = files(~[files.isdir]);
snapshot = cell(1, numel(files));
for i = 1:numel(files)
    file = fullfile(files(i).folder, files(i).name);
    snapshot{i} = sprintf('%s|%d|%s', files(i).name, files(i).bytes, ...
        mava_sha256(file));
end
snapshot = sort(snapshot);
end
