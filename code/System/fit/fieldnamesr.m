function fields = fieldnamesr(s, prefix)
% fieldnamesr - Recursively get all fieldnames of a nested struct
% Returns a cell array of dot-notation paths to every field, e.g.:
%   'MyoSim_model.hs_props.parameters.k_1'

if nargin < 2
    prefix = '';
end

fields = {};
fn = fieldnames(s);

for i = 1 : numel(fn)
    if isempty(prefix)
        full_name = fn{i};
    else
        full_name = [prefix '.' fn{i}];
    end

    val = s.(fn{i});

    if isstruct(val) && ~isempty(val)
        sub_fields = fieldnamesr(val, full_name);
        fields = [fields(:); sub_fields(:)]; %#ok<AGROW>
    else
        fields{end+1} = full_name; %#ok<AGROW>
    end
end
