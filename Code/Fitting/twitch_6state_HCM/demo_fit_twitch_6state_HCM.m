function demo_fit_twitch_6state_HCM(opt_file)
repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
cd(fileparts(mfilename('fullpath')));
if nargin < 1, opt_file = 'sim_input/optimization.json'; end

if isfile('temp/DONE.flag'), delete('temp/DONE.flag'); end
if ~isfolder('temp/best'), mkdir('temp/best'); end

opt = loadjson(opt_file);
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;
if isfield(opt_structure, 'best_model_folder')
    best_dir = opt_structure.best_model_folder;
else
    best_dir = 'temp/best';
end
if ~isfolder(best_dir), mkdir(best_dir); end
opt_structure.best_model_file_string    = fullfile(best_dir, 'model_best.json');

fit_controller(opt_structure);
end
