function run_variant_fit(demo_dir, opt_file)
% Run a twitch fit for a protocol/target variant without clobbering the
% canonical temp/best/model_best.json. Best output is redirected to the
% best_model_folder named inside opt_file (e.g. temp/best_slow).
repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
cd(demo_dir);

opt = loadjson(opt_file);
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;

bf = opt_structure.best_model_folder;
if ~isfolder(bf), mkdir(bf); end
opt_structure.best_model_file_string = fullfile(bf, 'model_best.json');

fit_controller(opt_structure);
fprintf('VARIANT FIT DONE: %s\n', demo_dir);
end
