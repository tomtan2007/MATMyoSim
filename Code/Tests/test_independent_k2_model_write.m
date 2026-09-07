function test_independent_k2_model_write
% A free k_2 parameter must not be overwritten by the legacy k_2/k_1 ratio.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

tmp_dir = tempname;
mkdir(tmp_dir);
cleanup = onCleanup(@() rmdir(tmp_dir, 's')); %#ok<NASGU>

opt = struct;
opt.model_template_file_string = fullfile(repo_root, 'Code', 'Fitting', ...
    'twitch_6state_control', 'sim_input', 'model_template.json');
opt.job = {struct('model_file_string', fullfile(tmp_dir, 'model.json'))};
opt.parameter = { ...
    struct('name', 'k_1', 'min_value', 0, 'max_value', 2, 'p_mode', 'log'), ...
    struct('name', 'k_2', 'min_value', 1, 'max_value', 3, 'p_mode', 'log')};

models = update_json_model_file(opt, 1, [0.25, 0.75], []);
params = models{1}.MyoSim_model.hs_props.parameters;

assert(abs(params.k_1 - 10^0.5) < 1e-5, ...
    'Expected independently mapped k_1 = 10^0.5.');
assert(abs(params.k_2 - 10^2.5) < 1e-3, ...
    'Expected independently mapped k_2 = 10^2.5.');
assert(abs(params.k_2 - 10 * params.k_1) > 1e-10, ...
    'Free k_2 must not be replaced by the legacy 10*k_1 rule.');

fprintf('PASS: independent k_2 model write\n');
end
