function test_configurable_k2_ratio
% Optional k_2_k_1_ratio must override the legacy 10x default.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));

tmp_dir = tempname;
mkdir(tmp_dir);
cleanup = onCleanup(@() rmdir(tmp_dir, 's'));

template = fullfile(repo_root, 'Code', 'Fitting', 'twitch_6state_control', ...
    'temp', 'best', 'model_best.json');

base = struct;
base.model_template_file_string = template;
base.job = {struct('model_file_string', fullfile(tmp_dir, 'model.json'))};
base.parameter = {struct('name', 'k_1', 'min_value', 0, ...
    'max_value', 2, 'p_mode', 'log')};

legacy = update_json_model_file(base, 1, 0.5, []);
assert(abs(legacy{1}.MyoSim_model.hs_props.parameters.k_2 - 100) < 1e-10, ...
    'Legacy default must remain k_2 = 10*k_1.');

base.k_2_k_1_ratio = 20;
configured = update_json_model_file(base, 1, 0.5, []);
assert(abs(configured{1}.MyoSim_model.hs_props.parameters.k_2 - 200) < 1e-10, ...
    'Configured ratio must set k_2 = 20*k_1.');

workbook = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');
assert(strcmp(mava_sha256(workbook), ...
    '941afa7cfd8afc625bcc887e16c1d5d839c39e9eaf409c7f018b5a759ed14ba0'), ...
    'The repository workbook must match the verified source bytes.');

fprintf('PASS: configurable k_2/k_1 ratio\n');
end
