function test_build_mava_joint_feature_fit_config
% Joint feature config must keep k_2 constrained and thin rates shared/fixed.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

settings = struct('max_fun_evals', 3);
[config_file, record] = build_mava_joint_feature_fit_config(out_dir, ...
    {'k_1','k_3','k_5_0'}, settings);
loaded = loadjson(config_file);
opt = loaded.MyoSim_optimization;
names = string(cellfun(@(x) x.name, opt.parameter, ...
    'UniformOutput', false));
assert(strcmp(opt.fit_mode, 'fit_twitch_features') && numel(opt.job) == 2, ...
    'Config must define a two-condition feature fit.');
assert(~any(names == "k_2"), 'k_2 must remain constrained.');
assert(~any(ismember(["k_on"; "k_off"; "k_coop"], names)), ...
    'Thin-filament parameters must remain fixed initially.');
fixed_names = string(cellfun(@(x) x.name, opt.fixed_parameter, ...
    'UniformOutput', false));
assert(all(ismember(["k_on"; "k_off"; "k_coop"], fixed_names)), ...
    'Thin-filament parameters must be common fixed values.');
assert(all(ismember(["k_1_control"; "k_1_h251n"; ...
    "k_3_control"; "k_3_h251n"; "k_5_0_control"; "k_5_0_h251n"], names)), ...
    'Core kinetic parameters must be condition-specific entries.');
assert(record.n_free_params == 6, 'Unexpected free-parameter count.');
fprintf('PASS: joint Mava feature config\n');
end
