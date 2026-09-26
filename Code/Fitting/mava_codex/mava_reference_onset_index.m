function onset_index = mava_reference_onset_index(protocol_file)
% Return the first protocol sample at the calcium-activation reference.

if ~isfile(protocol_file)
    error('mava_reference_onset_index:missingProtocol', ...
        'Protocol file not found: %s', protocol_file);
end
protocol = readtable(protocol_file, 'FileType', 'text', 'Delimiter', '\t');
if ~ismember('pCa', protocol.Properties.VariableNames)
    error('mava_reference_onset_index:missingPCa', ...
        'Protocol must contain a pCa column.');
end
onset_index = find(protocol.pCa < 6.70, 1, 'first');
if isempty(onset_index)
    error('mava_reference_onset_index:noActivation', ...
        'Protocol never reaches the calcium-activation reference.');
end
end
