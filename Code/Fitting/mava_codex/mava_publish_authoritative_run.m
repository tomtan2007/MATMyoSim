function manifest = mava_publish_authoritative_run(run_dir, manifest)
% Atomically select a fully validated final run as authoritative.

run_dir = char(string(run_dir));
if ~strcmp(char(string(manifest.creation_mode)), 'execute') || ...
        ~strcmp(char(string(manifest.status)), 'complete')
    error('mava_publish_authoritative_run:incompleteRun', ...
        'Only complete executed capsules may be published.');
end
mava_validate_summary_materialization(manifest);
if ~strcmp(char(string(manifest.materialization.summary.state)), 'final')
    error('mava_publish_authoritative_run:provisionalSummary', ...
        'A provisional summary cannot be published.');
end
active = active_indices(manifest);
validate_mava_run_semantics(manifest, active, 'signed');
runs_dir = fileparts(run_dir);
[output_dir, leaf] = fileparts(runs_dir);
if ~strcmp(leaf, 'runs') || ~strcmp(fileparts(run_dir), runs_dir) || ...
        ~strcmp(char(string(manifest.run_dir)), run_dir)
    error('mava_publish_authoritative_run:badLayout', ...
        'Authority publication requires an output/runs/<run_id> capsule.');
end
pointer = fullfile(output_dir, 'AUTHORITATIVE_RUN.txt');
temporary = [tempname(output_dir) '.txt'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary,'w');
if fid < 0, error('mava_publish_authoritative_run:writeFailed', ...
        'Could not write temporary authority pointer.'); end
file_cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',char(string(manifest.run_id)));
clear file_cleanup;

if ~manifest.materialization.summary.published
    manifest.materialization.summary.published = true;
    manifest = write_signed_manifest(run_dir, manifest);
end
[ok,message] = movefile(temporary,pointer,'f');
if ~ok, error('mava_publish_authoritative_run:writeFailed', ...
        'Could not publish authority pointer: %s',message); end
end

function indices = active_indices(manifest)
selected = cellstr(string( ...
    manifest.materialization.optional_final_restart_groups));
active = cellfun(@(item) logical(item.required) || ismember( ...
    [char(string(item.alignment_policy)) '__' ...
    char(string(item.genotype))], selected), manifest.inventory);
indices = find(active);
end

function manifest = write_signed_manifest(run_dir, manifest)
manifest.materialization_signature = value_signature(manifest.materialization);
state = struct('mode', manifest.mode, 'status', manifest.status, ...
    'records_planned', manifest.records_planned);
if isfield(manifest,'failure'), state.failure = manifest.failure; end
manifest.state_signature = value_signature(state);
write_json_atomic(fullfile(run_dir,'manifest.json'),manifest);
end

function signature = value_signature(value)
bytes = unicode2native(jsonencode(value),'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw = typecast(engine.digest(),'uint8');
signature = lower(reshape(dec2hex(raw,2).',1,[]));
end

function write_json_atomic(file,value)
temporary = [tempname(fileparts(file)) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary,'w');
if fid < 0, error('mava_publish_authoritative_run:writeFailed', ...
        'Could not write temporary manifest.'); end
file_cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(value));
clear file_cleanup;
[ok,message] = movefile(temporary,file,'f');
if ~ok, error('mava_publish_authoritative_run:writeFailed', ...
        'Could not publish manifest: %s',message); end
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
