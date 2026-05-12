function demo_fit_twitch_6state_exp
% Fit 6-state model with EXPONENTIAL M3 detachment (matches 3-state baseline).
% Fits 6 params: k_3, k_on, k_off, k_4_0, k_coop, k_7_0
% This is the fair AIC comparison vs 3-state's 5-param fit.

clear classes; clear functions;

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));

base = fileparts(mfilename('fullpath'));
cd(base);

opt_file = fullfile(base, 'optimization_exp.json');
opt_structure = loadjson(opt_file);

fprintf('Launching exp 6-state fit (6 params)...\n');
fprintf('Optimization config: %s\n', opt_file);

fit_controller(opt_structure.MyoSim_optimization);

end
