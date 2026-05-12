function demo_fit_twitch_3state_HCM
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

opt = loadjson('optimization.json');
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;
opt_structure.best_model_file_string    = 'temp/best/model_best.json';

fit_controller(opt_structure);
end
