function test_build_mava_fit_configs
% Four acute fits must vary only k_1, k_3, k_5_0 at 10x/20x coupling.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

configs = build_mava_fit_configs(out_dir, 25);
assert(numel(configs) == 4, 'Expected Control/H251N x 10/20 ratio configs.');

expected_names = {'k_1','k_3','k_5_0'};
seen = strings(0);
for i = 1:numel(configs)
    loaded = loadjson(configs{i});
    opt = loaded.MyoSim_optimization;
    names = cellfun(@(p) p.name, opt.parameter, 'UniformOutput', false);
    assert(isequal(names, expected_names), 'Only k_1, k_3, k_5_0 may be free.');
    assert(any(opt.k_2_k_1_ratio == [10 20]), 'Ratio must be 10 or 20.');
    assert(opt.max_fun_evals == 25, 'Evaluation cap was not propagated.');
    assert(opt.job{1}.fit_start_index == 481, ...
        'Mava fits must start scoring at the calcium-transient onset.');
    assert(contains(opt.job{1}.target_file_string, '_acute_target.txt'), ...
        'Fit target must be the acute mavacamten trace.');
    seen(end+1) = string(opt.job{1}.target_file_string) + "|" + ...
        string(opt.k_2_k_1_ratio); %#ok<AGROW>
end
assert(numel(unique(seen)) == 4, 'Fit configurations must be unique.');

fprintf('PASS: mavacamten fit configuration\n');
end
