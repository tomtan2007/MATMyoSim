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
