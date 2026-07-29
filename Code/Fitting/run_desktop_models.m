% Runs twitch_Con_model_6s and twitch_H251N_model_6s.
% Tries protocol_1s_slow (PI supplied) and protocol_1s (target protocol).
% Aligns by Ca onset, zeros both sim and target at pre-activation baseline.

repo_root = fileparts(mfilename('fullpath'));
code_root = fileparts(repo_root);
addpath(genpath(code_root));
addpath(genpath(fullfile(code_root, 'System')));

con_model        = fullfile(repo_root, 'twitch_6state_control', 'sim_input', 'twitch_Con_model_6s.json');
hcm_model        = fullfile(repo_root, 'twitch_6state_HCM',     'sim_input', 'twitch_H251N_model_6s.json');
options_file_con = fullfile(repo_root, 'twitch_6state_control', 'sim_input', 'sim_options.json');
options_file_hcm = fullfile(repo_root, 'twitch_6state_HCM',     'sim_input', 'sim_options.json');
proto_slow       = fullfile(code_root, 'System', 'protocols', 'protocol_1s_slow.txt');
proto_norm       = fullfile(code_root, 'System', 'protocols', 'protocol_1s.txt');

% Load targets (built on protocol_1s.txt, onset at row 481 = t=0.480s)
con_tgt_raw = load(fullfile(code_root, 'System', 'target_data', 'Con_target.txt'));
hcm_tgt_raw = load(fullfile(code_root, 'System', 'target_data', 'H251N_target.txt'));
tgt_t_raw   = (0:numel(con_tgt_raw)-1)' * 0.001;
tgt_onset   = 0.480;

% Run both protocols
protocols = {proto_slow, proto_norm};
labels    = {'slow', 'normal (target protocol)'};

con_sims = cell(2,1);  hcm_sims = cell(2,1);
for k = 1:2
    cd(fullfile(repo_root, 'twitch_6state_control'));
    fprintf('Running control [%s]...\n', labels{k});
    con_sims{k} = simulation_driver('model_json_file_string', con_model, ...
        'simulation_protocol_file_string', protocols{k}, ...
        'options_json_file_string', options_file_con);

    cd(fullfile(repo_root, 'twitch_6state_HCM'));
    fprintf('Running H251N   [%s]...\n', labels{k});
    hcm_sims{k} = simulation_driver('model_json_file_string', hcm_model, ...
        'simulation_protocol_file_string', protocols{k}, ...
        'options_json_file_string', options_file_hcm);
end

% Helper: zero a trace using first pre_n rows, return column vector
zero_trace = @(x, pre_n) x(:) - mean(x(1:pre_n));

% Target: 400 pre-activation rows safely before onset
pre_n_tgt = 400;
con_tgt   = zero_trace(con_tgt_raw, pre_n_tgt);
hcm_tgt   = zero_trace(hcm_tgt_raw, pre_n_tgt);
tgt_t_rel = tgt_t_raw - tgt_onset;

% --- Plot ---
fig = figure('Name', 'Desktop 6s models', 'Position', [30 30 1200 500], 'Color', 'w');
colors_sim  = {[0.0 0.45 0.85], [0.85 0.20 0.10]};   % con, hcm
linestyles  = {'-', '--'};                              % slow, normal
proto_names = {'slow protocol', 'normal protocol'};

for k = 1:2
    % Get sim time relative to Ca onset (find first pCa < 6.70)
    proto_tbl  = readtable(protocols{k}, 'FileType','text','Delimiter','\t');
    sim_t_abs  = cumsum(proto_tbl.dt) - proto_tbl.dt(1);
    onset_idx  = find(proto_tbl.pCa < 6.70, 1);
    t_onset    = sim_t_abs(onset_idx);

    % Baseline: 50 rows immediately before Ca onset (equilibrated passive plateau)
    % Cannot use mean of all pre-activation rows — model ramps from init at row 1.
    pre_win = (onset_idx-50):(onset_idx-1);
    con_f   = con_sims{k}.muscle_force(:) - mean(con_sims{k}.muscle_force(pre_win));
    hcm_f   = hcm_sims{k}.muscle_force(:) - mean(hcm_sims{k}.muscle_force(pre_win));
    sim_t_rel = con_sims{k}.time_s(:) - t_onset;

    subplot(1,2,1); hold on;
    plot(sim_t_rel, con_f, 'Color', colors_sim{1}, 'LineStyle', linestyles{k}, 'LineWidth', 2, ...
         'DisplayName', ['Con ' proto_names{k}]);

    subplot(1,2,2); hold on;
    plot(sim_t_rel, hcm_f, 'Color', colors_sim{2}, 'LineStyle', linestyles{k}, 'LineWidth', 2, ...
         'DisplayName', ['H251N ' proto_names{k}]);

    fprintf('%s con peak=%.0f  hcm peak=%.0f\n', labels{k}, max(con_f), max(hcm_f));
end

% Add targets to both panels
subplot(1,2,1);
plot(tgt_t_rel, con_tgt, 'Color', [0.55 0.55 0.55], 'LineWidth', 1.5, 'DisplayName', 'Target (Con)');
xline(0,'--k','Alpha',0.25, 'HandleVisibility','off');
xlim([-0.1 1.0]); xlabel('Time re Ca onset (s)'); ylabel('Force (N m^{-2})');
title('Control'); legend('Location','northeast'); box off; grid on;

subplot(1,2,2);
plot(tgt_t_rel, hcm_tgt, 'Color', [0.55 0.55 0.55], 'LineWidth', 1.5, 'DisplayName', 'Target (H251N)');
xline(0,'--k','Alpha',0.25, 'HandleVisibility','off');
xlim([-0.1 1.0]); xlabel('Time re Ca onset (s)'); ylabel('Force (N m^{-2})');
title('H251N'); legend('Location','northeast'); box off; grid on;

sgtitle('Slow vs normal protocol', 'FontSize', 12);
saveas(fig, fullfile(repo_root, 'desktop_models_result.png'));
fprintf('Saved: Code/Fitting/desktop_models_result.png\n');
