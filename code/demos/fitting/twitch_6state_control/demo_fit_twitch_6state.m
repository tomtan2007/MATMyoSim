function demo_fit_twitch_6state
% Fit 6-state titin-coupled SRX model to control twitch data
% Parameters: k_3, k_on, k_off, k_4_0, k_7_0 (5 params, same count as 3-state best)
% k_H and k_minus_H are fixed from Jezek et al. Table 2 (18 and 1.8 s^-1)

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));

opt_file = fullfile(fileparts(mfilename('fullpath')), 'optimization.json');
opt_structure = loadjson(opt_file);

fit_controller(opt_structure.MyoSim_optimization);
