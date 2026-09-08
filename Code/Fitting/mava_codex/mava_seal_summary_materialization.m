function manifest = mava_seal_summary_materialization(run_dir, manifest, state)
% Hash generated summaries and atomically bind them to active results.

state = char(string(state));
if ~ismember(state, {'provisional_optional_requested','final'})
    error('mava_seal_summary_materialization:badState', ...
        'Cannot seal summary state %s.', state);
end
if ~strcmp(char(string(manifest.materialization.summary.state)), 'none')
    mava_validate_summary_materialization(manifest);
    if strcmp(char(string(manifest.materialization.summary.state)), state)
        return;
    end
    error('mava_seal_summary_materialization:immutableSummary', ...
        'Existing signed summary requires an explicit invalidation transition.');
end
artifacts = manifest.materialization.summary.artifacts;
for i = 1:numel(artifacts)
    if ~isfile(artifacts{i}.path)
        error('mava_seal_summary_materialization:missingArtifact', ...
            'Required summary artifact is missing: %s.', artifacts{i}.path);
    end
    artifacts{i}.sha256 = mava_sha256(artifacts{i}.path);
end
manifest.materialization.summary.state = state;
manifest.materialization.summary.active_result_fingerprint = ...
    mava_active_result_fingerprint(manifest);
manifest.materialization.summary.artifacts = artifacts;
manifest.materialization.summary.published = false;
decision_index = find(cellfun(@(item) ...
    strcmp(item.id,'adaptive_restart_decision'), artifacts));
manifest.materialization.adaptive_restart_decision.sha256 = ...
    artifacts{decision_index}.sha256;
mava_validate_summary_materialization(manifest);
manifest = write_signed_manifest(run_dir, manifest);
end

function manifest = write_signed_manifest(run_dir, manifest)
manifest.materialization_signature = value_signature(manifest.materialization);
state = struct('mode', manifest.mode, 'status', manifest.status, ...
    'records_planned', manifest.records_planned);
if isfield(manifest, 'failure'), state.failure = manifest.failure; end
manifest.state_signature = value_signature(state);
write_json_atomic(fullfile(run_dir,'manifest.json'), manifest);
end

function signature = value_signature(value)
bytes = unicode2native(jsonencode(value), 'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw = typecast(engine.digest(), 'uint8');
signature = lower(reshape(dec2hex(raw,2).',1,[]));
end

function write_json_atomic(file, value)
temporary = [tempname(fileparts(file)) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary,'w');
if fid < 0, error('mava_seal_summary_materialization:writeFailed', ...
        'Could not write temporary manifest.'); end
file_cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(value));
clear file_cleanup;
[ok,message] = movefile(temporary,file,'f');
if ~ok, error('mava_seal_summary_materialization:writeFailed', ...
        'Could not publish manifest: %s',message); end
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
