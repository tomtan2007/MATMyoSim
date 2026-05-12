function demo_fit_twitch_6state_HCM
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

opt_file = 'optimization.json';
opt = loadjson(opt_file);
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;
opt_structure.best_model_file_string    = fullfile('temp/best', 'model_best.json');

if ~isfolder('temp/best'), mkdir('temp/best'); end

fit_controller(opt_structure);
end
