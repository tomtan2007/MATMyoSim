function shifts = mava_alignment_shifts(trough_times, genotypes, calcium_onset, policy)
% Return shifts that align detected troughs to the calcium onset.

if ~iscolumn(trough_times) || ~all(isfinite(trough_times))
    error('mava_alignment_shifts:badInput', ...
        'trough_times must be a finite column vector.');
end
if ~(isstring(genotypes) || iscellstr(genotypes)) || numel(genotypes) ~= numel(trough_times)
    error('mava_alignment_shifts:badInput', ...
        'genotypes must have one entry per trough time.');
end
if ~isscalar(calcium_onset) || ~isfinite(calcium_onset)
    error('mava_alignment_shifts:badInput', ...
        'calcium_onset must be a finite scalar.');
end
if ~(ischar(policy) || isstring(policy)) || ~isscalar(string(policy))
    error('mava_alignment_shifts:badPolicy', 'Unknown alignment policy.');
end
policy = char(string(policy));
codes = string(genotypes(:));

switch policy
    case 'independent_trace'
        shifts = calcium_onset - trough_times;
    case 'shared_by_genotype'
        shifts = nan(size(trough_times));
        labels = ["Control", "H251N"];
        for label = labels
            idx = find(codes == label, 1, 'first');
            if isempty(idx)
                error('mava_alignment_shifts:missingGenotype', ...
                    'No %s trace was provided.', label);
            end
            shifts(codes == label) = calcium_onset - trough_times(idx);
        end
        if any(isnan(shifts))
            error('mava_alignment_shifts:unknownGenotype', ...
                'Only Control and H251N genotypes are supported.');
        end
    otherwise
        error('mava_alignment_shifts:badPolicy', ...
            'Unknown alignment policy: %s', policy);
end
end
