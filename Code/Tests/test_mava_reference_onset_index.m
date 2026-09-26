function tests = test_mava_reference_onset_index
tests = functiontests(localfunctions);
end

function testMatchesCanonicalProtocol(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
protocol = fullfile(root, 'System', 'protocols', 'protocol_1s.txt');
verifyEqual(testCase, mava_reference_onset_index(protocol), 481);
end
