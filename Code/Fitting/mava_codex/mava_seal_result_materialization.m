function manifest = mava_seal_result_materialization( ...
    run_dir, manifest, index, hashes)
% Append verified result hashes and atomically reseal the run manifest.

run_dir = char(string(run_dir));
if ~isscalar(index) || ~isnumeric(index) || ~isfinite(index) || ...
        index < 1 || index ~= floor(index) || ...
        index > numel(manifest.materialization.results)
    error('mava_run_manifest:resumeMismatch', ...
        'Completed-result materialization index is invalid.');
end
hash_names = {'model_best','best_optimization','fit_results','status'};
if ~isstruct(hashes) || ~isscalar(hashes) || ...
        ~isequal(sort(fieldnames(hashes)), sort(hash_names(:)))
    error('mava_run_manifest:resumeMismatch', ...
        'Completed-result hashes have an invalid schema.');
end
values = cellfun(@(name) char(string(hashes.(name))), hash_names, ...
    'UniformOutput', false);
if any(cellfun(@(value) isempty(regexp(value, ...
        '^[0-9a-f]{64}$', 'once')), values))
    error('mava_run_manifest:resumeMismatch', ...
        'Completed-result hashes must be lowercase SHA-256 values.');
end

entry = manifest.materialization.results{index};
field_names = {'model_best_sha256','best_optimization_sha256', ...
    'fit_results_sha256','status_sha256'};
existing = cellfun(@(name) char(string(entry.(name))), field_names, ...
    'UniformOutput', false);
if any(~cellfun(@isempty, existing))
    if ~isequal(existing, values)
        error('mava_run_manifest:resumeMismatch', ...
            'Refusing to replace completed result hashes for %s.', entry.id);
    end
    return;
end
for i = 1:numel(field_names)
    entry.(field_names{i}) = values{i};
end
manifest.materialization.results{index} = entry;
manifest.materialization_signature = value_signature(manifest.materialization);
state = struct('mode', manifest.mode, 'status', manifest.status, ...
    'records_planned', manifest.records_planned);
if isfield(manifest, 'failure')
    state.failure = manifest.failure;
end
manifest.state_signature = value_signature(state);
write_json_atomic(fullfile(run_dir, 'manifest.json'), manifest);
end

function signature = value_signature(value)
bytes = unicode2native(jsonencode(value), 'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw_digest = typecast(engine.digest(), 'uint8');
signature = lower(reshape(dec2hex(raw_digest, 2).', 1, []));
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
fprintf(fid, '%s', jsonencode(value));
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
