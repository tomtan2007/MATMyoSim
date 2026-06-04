function plot_4state_ctrl_v2
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));
BASE     = fileparts(mfilename('fullpath'));
PROTOCOL = fullfile(BASE, '..', 'System', 'protocols', 'protocol_1s.txt');

best_model  = fullfile(BASE, 'twitch_4state_control', 'temp', 'best', 'model_best.json');
opts_file   = fullfile(BASE, 'twitch_4state_control', 'sim_input', 'sim_options.json');
target_path = fullfile(BASE, '..', 'System', 'target_data', 'Con_target.txt');

tgt = dlmread(target_path);
n   = numel(tgt);

s = simulation(best_model, PROTOCOL, opts_file);
s.implement_protocol;
sim_all = s.sim_output.muscle_force;
sim_w   = sim_all(end-n+1:end);

tgt_min = min(tgt); tgt_max = max(tgt);
fa = find(tgt > tgt_min + 0.05*(tgt_max-tgt_min), 1, 'first');
if isempty(fa) || fa < 2, fa = 2; end
lp = 1:(fa-1);
if numel(lp) > 5, lp = lp(round(0.5*end):end); end
sim_al = sim_w - mean(sim_w(lp)) + mean(tgt(lp));

prot = readtable(PROTOCOL, 'FileType', 'text', 'Delimiter', '\t');
dt   = prot.(1)(1);
t    = (0:n-1)' * dt;

fig = figure('Visible', 'off', 'Position', [0 0 700 420]);
hold on;
plot(t, tgt,    'k-', 'LineWidth', 1.8, 'DisplayName', 'Data (Control)');
plot(t, sim_al, '-',  'LineWidth', 2, 'Color', [0.85 0.33 0.10], 'DisplayName', '4-state fit (e=0.025)');
xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state control — new fit vs data', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'northeast', 'Box', 'off', 'FontSize', 10);
grid on; set(gca, 'FontSize', 10);

out = fullfile(BASE, '4state_control_fit_v2.png');
exportgraphics(fig, out, 'Resolution', 150);
fprintf('Saved: %s\n', out);
