function test_run_mava_joint_feature_multistart_inputs
% Invalid joint-stage requests must fail before any simulation is launched.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
threw = false;
try
    run_mava_joint_feature_multistart('bad_k2', {'k_1','k_2'});
catch ME
    threw = strcmp(ME.identifier, ...
        'run_mava_joint_feature_multistart:k2Fixed');
end
assert(threw, 'k_2 must be rejected before fitting begins.');
fprintf('PASS: joint feature multistart input validation\n');
end
