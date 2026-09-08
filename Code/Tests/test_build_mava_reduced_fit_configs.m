function test_build_mava_reduced_fit_configs
% Reduced kinetic fits must create distinct deterministic multistarts.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

names = {'k_1','k_3','k_5_0','k_4_0','k_7_3'};
files = build_mava_reduced_fit_configs(out_dir, 25, 2, names);
assert(numel(files) == 8, 'Expected genotype x ratio x restart configs.');
starts = nan(2, numel(names));
for i = 1:2
    opt = loadjson(files{i});
    P = opt.MyoSim_optimization.parameter;
    assert(isequal(cellfun(@(x) x.name, P, 'UniformOutput', false), names), ...
        'Reduced fit parameter list is incorrect.');
    assert(opt.MyoSim_optimization.job{1}.fit_start_index == 481, ...
        'Reduced Mava fits must use the protocol onset.');
    assert(opt.MyoSim_optimization.tol_fun == 1e-5 && ...
        opt.MyoSim_optimization.tol_x == 1e-3, ...
        'Reduced fits must stop after practical flat-basin convergence.');
    starts(i,:) = cellfun(@(x) x.p_value, P);
end
assert(any(abs(starts(1,:)-starts(2,:)) > 0.01), ...
    'Restarts must use distinct starting points.');

fprintf('PASS: reduced Mava fit configs\n');
end
