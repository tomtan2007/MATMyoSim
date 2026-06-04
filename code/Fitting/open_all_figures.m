function open_all_figures
% Open all 4 diagnostic figures simultaneously in separate windows

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));

base = '/Users/tomtan/Research/MATMyoSim/code/demos/fitting';

% Each script calls figure(1); clf — renumber after each so the next
% script creates a fresh window instead of reusing the same one.

plot_control_fit_results;
set(figure(1), 'Number', 11);   % move fig 1 → 11

run_srx_all_models;
set(figure(1), 'Number', 12);   % move fig 1 → 12

cd(fullfile(base, 'twitch_3state_control'));
plot_series_k_comparison;
set(figure(1), 'Number', 13);   % move fig 1 → 13

plot_muscle_length_ecc;
set(figure(1), 'Number', 14);   % move fig 1 → 14

cd(base);
fprintf('All 4 figures open.\n');
