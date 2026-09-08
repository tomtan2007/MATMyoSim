function fingerprint = mava_active_result_fingerprint(manifest)
% Hash the ordered identities and hashes of the active fitted result set.

selected = {};
if isfield(manifest.materialization, 'optional_final_restart_groups')
    selected = cellstr(string( ...
        manifest.materialization.optional_final_restart_groups));
end
records = {};
for i = 1:numel(manifest.inventory)
    item = manifest.inventory{i};
    group_id = [char(string(item.alignment_policy)) '__' ...
        char(string(item.genotype))];
    if ~(logical(item.required) || ismember(group_id, selected))
        continue;
    end
    result = manifest.materialization.results{i};
    hashes = {'model_best_sha256','best_optimization_sha256', ...
        'fit_results_sha256','status_sha256'};
    if any(cellfun(@(name) ~isfield(result,name) || ...
            isempty(regexp(char(string(result.(name))), ...
            '^[0-9a-f]{64}$','once')), hashes))
        error('mava_active_result_fingerprint:incompleteResult', ...
            'Active result %s is not fully hash-bound.', item.id);
    end
    config_hash = manifest.materialization.configs{i}.sha256;
    records{end+1} = struct('id', item.id, ... %#ok<AGROW>
        'config_sha256', config_hash, ...
        'model_best_sha256', result.model_best_sha256, ...
        'best_optimization_sha256', result.best_optimization_sha256, ...
        'fit_results_sha256', result.fit_results_sha256, ...
        'status_sha256', result.status_sha256);
end
bytes = unicode2native(jsonencode(records), 'UTF-8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw = typecast(engine.digest(), 'uint8');
fingerprint = lower(reshape(dec2hex(raw,2).',1,[]));
end
