function demo_fit_twitch_6state_HCM(opt_file)
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));
if nargin < 1, opt_file = 'sim_input/optimization.json'; end

if isfile('temp/DONE.flag'), delete('temp/DONE.flag'); end
if ~isfolder('temp/best'), mkdir('temp/best'); end

opt = loadjson(opt_file);
opt_structure = opt.MyoSim_optimization;
opt_structure.model_working_file_string = opt_structure.job{1}.model_file_string;
opt_structure.best_model_file_string    = 'temp/best/model_best.json';

fit_controller(opt_structure);
end
