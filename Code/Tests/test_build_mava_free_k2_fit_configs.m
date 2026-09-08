function test_build_mava_free_k2_fit_configs
% Free-k2 fits must optimize k1/k2/k3 independently without ratio duplication.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

files = build_mava_free_k2_fit_configs(out_dir, 25, 1);
assert(numel(files) == 2, 'Expected one Control and one H251N config.');
for i = 1:numel(files)
    loaded = loadjson(files{i});
    opt = loaded.MyoSim_optimization;
    names = cellfun(@(x) x.name, opt.parameter, 'UniformOutput', false);
    assert(isequal(names, {'k_1','k_2','k_3'}), ...
        'Only k_1, k_2, and k_3 may be free.');
    assert(~isfield(opt, 'k_2_k_1_ratio'), ...
        'An independent k_2 fit must not carry a ratio constraint.');
    assert(opt.job{1}.fit_start_index == 481, ...
        'Free-k_2 fits must start scoring at calcium onset.');
end

fprintf('PASS: free-k_2 Mava fit configs\n');
end
