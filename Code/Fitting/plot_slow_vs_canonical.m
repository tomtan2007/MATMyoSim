function plot_slow_vs_canonical
% Before/after overlay: canonical fast-onset fit vs slow-onset+rezero fit.
% Runs each model_best.json through its OWN protocol/target and aligns using
% the same last-n-rows / passive-baseline logic as evaluate_time_fit.m.
% Saves a 2x2 figure (Control/HCM rows, before/after columns).

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

BASE   = fileparts(mfilename('fullpath'));
OUTDIR = fullfile(BASE, 'fit_comparison_figures');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end

P = @(f) fullfile(BASE, '..', 'System', 'protocols', f);
T = @(f) fullfile(BASE, '..', 'System', 'target_data', f);

% row = condition; each has canonical (before) and slow (after) setups
cfg = struct();
cfg(1).cond='control'; cfg(1).dir='twitch_6state_control';
cfg(1).before_prot=P('protocol_1s.txt');          cfg(1).before_tgt=T('Con_target.txt');
cfg(1).after_prot =P('protocol_1s_slowonset.txt'); cfg(1).after_tgt =T('Con_target_ext.txt');
cfg(1).title='Control';
cfg(2).cond='HCM'; cfg(2).dir='twitch_6state_HCM';
cfg(2).before_prot=P('protocol_1s.txt');          cfg(2).before_tgt=T('H251N_target.txt');
cfg(2).after_prot =P('protocol_1s_slowonset.txt'); cfg(2).after_tgt =T('H251N_target_ext.txt');
cfg(2).title='HCM (H251N)';

col_sim = [0.17 0.63 0.17];   % green sim
fig = figure('Visible','off','Position',[50 50 1200 800]);

for r = 1:2
    md = fullfile(BASE, cfg(r).dir);
    opts = fullfile(md, 'sim_input', 'sim_options.json');

    panels = {
        'BEFORE (fast onset)', fullfile(md,'temp','best','model_best.json'), ...
            cfg(r).before_prot, cfg(r).before_tgt;
        'AFTER (slow onset + rezero)', fullfile(md,'temp','best_slow','model_best.json'), ...
            cfg(r).after_prot, cfg(r).after_tgt;
    };

    for c = 1:2
        [t, tgt, sim, e] = run_and_align(panels{c,2}, panels{c,3}, panels{c,4}, opts);

        ax = subplot(2, 2, (r-1)*2 + c); hold(ax,'on');
        plot(ax, t, tgt, 'k-', 'LineWidth', 2, 'DisplayName', 'Data');
        plot(ax, t, sim, '-', 'Color', col_sim, 'LineWidth', 2, ...
             'DisplayName', sprintf('6-state fit (e=%.4f)', e));
        xlabel(ax,'Time (s)'); ylabel(ax,'Force (N/m²)');
        title(ax, sprintf('%s — %s', cfg(r).title, panels{c,1}), 'FontWeight','bold');
        legend(ax,'Location','northeast','Box','off');
        grid(ax,'on'); ax.GridAlpha=0.2;
        set(ax,'Color','w','XColor','k','YColor','k');
    end
end

set(fig,'Color','w');
out = fullfile(OUTDIR,'slow_vs_canonical_6state.png');
exportgraphics(fig, out, 'Resolution', 150);
fprintf('Saved: %s\n', out);
close(fig);
end

function [t, tgt_raw, sim_aligned, e] = run_and_align(model, prot, tgtf, opts)
prow = readtable(prot, 'FileType','text','Delimiter','\t');
dt   = prow.(1)(1);
tgt_raw = dlmread(tgtf);
n_tgt   = numel(tgt_raw);
t = (0:n_tgt-1)' * dt;

tmin=min(tgt_raw); tmax=max(tgt_raw);
fa = find(tgt_raw > tmin + 0.05*(tmax-tmin), 1, 'first');
if isempty(fa) || fa < 2, fa = 2; end
pass = 1:(fa-1);
if numel(pass) > 5, lp = pass(round(0.5*end):end); else, lp = pass; end
base_tgt = mean(tgt_raw(lp));

s = simulation(model, prot, opts);
s.implement_protocol;
sim_all = s.sim_output.muscle_force;
sw = sim_all(end - n_tgt + 1 : end);
sim_aligned = sw - mean(sw(lp)) + base_tgt;

% error over active window (mirrors evaluate_time_fit normalization)
ai = fa:n_tgt;
e = sum(((sim_aligned(ai)-tgt_raw(ai))./(tmax-tmin)).^2) / numel(ai);
end
