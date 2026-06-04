% Run all 4 twitch fits (4-state and 6-state, control and HCM)
% Same 5 params: k_1, k_3, k_on, k_off, k_7_0
% Optimizer: particleswarm (global search, apples-to-apples comparison)

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));

demos = {
    'twitch_4state_control', 'demo_fit_twitch_4state_control';
    'twitch_4state_HCM',     'demo_fit_twitch_4state_HCM';
    'twitch_6state_control', 'demo_fit_twitch_6state';
    'twitch_6state_HCM',     'demo_fit_twitch_6state_HCM';
};

base = fileparts(mfilename('fullpath'));

for i = 1:size(demos, 1)
    demo_dir  = fullfile(base, demos{i,1});
    demo_func = demos{i,2};
    fprintf('\n============================\n');
    fprintf('Running: %s\n', demos{i,1});
    fprintf('============================\n');
    cd(demo_dir);
    feval(demo_func);
end

fprintf('\nAll fits complete.\n');
