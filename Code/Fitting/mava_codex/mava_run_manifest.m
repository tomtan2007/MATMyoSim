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
expected = build_manifest(run_dir, settings, mode);
if ismember(mode, creation_modes)
    if isfolder(run_dir) || isfile(run_dir)
        error('mava_run_manifest:runExists', ...
            'Run capsule already exists: %s.', run_dir);
    end
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
if ~isfield(manifest, 'immutable_signature') || ...
        ~strcmp(manifest.immutable_signature, expected.immutable_signature)
    error('mava_run_manifest:resumeMismatch', ...
        'Current settings or input hashes do not match the run manifest.');
end
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
hashes.sources = repmat(struct('path', '', 'sha256', ''), ...
    1, numel(settings.source_files));
for i = 1:numel(settings.source_files)
    hashes.sources(i) = hash_record(settings.source_files{i});
end

controls = struct( ...
    'scale_mode', settings.scale_mode, ...
    'fit_start_index', settings.fit_start_index, ...
    'restarts', settings.restarts, ...
    'extra_final_restarts', settings.extra_final_restarts, ...
    'max_fun_evals', settings.max_fun_evals, ...
    'tol_fun', settings.tol_fun, ...
    'tol_x', settings.tol_x);
immutable = struct( ...
    'run_id', settings.run_id, ...
    'run_dir', run_dir, ...
    'repository_root', settings.repository_root, ...
    'hashes', hashes, ...
    'settings', controls, ...
    'groups', {settings.alignment_groups}, ...
    'stages', settings.stages);

manifest = immutable;
manifest.schema_version = 1;
manifest.created_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.repository_head = repository_head(settings.repository_root);
manifest.matlab_version = version;
manifest.mode = mode;
manifest.status = 'created';
manifest.immutable_signature = savejson('', immutable, ...
    'Compact', 1, 'FloatFormat', '%.17g');
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
fprintf(fid, '%s', savejson('', value, 'FloatFormat', '%.17g'));
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
