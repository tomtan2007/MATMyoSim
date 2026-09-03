function demo_fit_6state_joint(opt_file, single_run)
% Joint control+HCM twitch fit for the 6-state model.
%
% Fits both conditions simultaneously with MOST parameters (k_3, k_on,
% k_off, k_coop, k_7_1, k_7_2, k_7_3) truly shared across the two jobs,
% and only k_1, k_5_0, k_4_0 allowed to take separate values per
% condition (k_1_ctrl/k_1_hcm etc, via the "job"+"target_name" fields
% in optimization_joint.json, resolved by the updated
% update_json_model_file.m). See CLAUDE.md priority-1 task.
%
% single_run=1 does one fminsearch evaluation then stops (smoke test).

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
cd(fileparts(mfilename('fullpath')));

if nargin < 1 || isempty(opt_file)
    opt_file = 'sim_input/optimization_joint.json';
end
if nargin < 2
    single_run = 0;
end

opt = loadjson(opt_file);
opt_structure = opt.MyoSim_optimization;

% Derive best-model output folder from the config itself (defaults to
% temp/best) so alternate-start restarts (different opt_file, different
% best_model_folder) don't collide with each other's outputs.
if isfield(opt_structure, 'best_model_folder')
    best_folder = opt_structure.best_model_folder;
else
    best_folder = 'temp/best';
end
if ~isfolder(best_folder), mkdir(best_folder); end
if isfile(fullfile(fileparts(best_folder), 'DONE.flag'))
    delete(fullfile(fileparts(best_folder), 'DONE.flag'));
end

% Per-job working/best model files (cell arrays) - fit_controller.m and
% update_json_model_file.m were extended to accept these for joint fits.
opt_structure.model_working_file_string = { ...
    opt_structure.job{1}.model_file_string, ...
    opt_structure.job{2}.model_file_string};
opt_structure.best_model_file_string = { ...
    fullfile(best_folder, 'model_best_ctrl.json'), ...
    fullfile(best_folder, 'model_best_hcm.json')};

% Cap runtime: 13 free params, each eval runs 2 simulations (ctrl+HCM).
% 2500 evals is enough for Nelder-Mead to make real progress on 13 dims
% without indefinitely occupying the shared MATLAB license slot.
opt_structure.max_fun_evals = 2500;

fit_controller(opt_structure, single_run);
end
