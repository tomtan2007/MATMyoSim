function plot_best_overlay
% Clean overlay of the best-fitting setup (slow-onset + rezero) vs data,
% Control and HCM side by side. Uses the same align logic as evaluate_time_fit.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
BASE   = fileparts(mfilename('fullpath'));
OUTDIR = fullfile(BASE, 'fit_comparison_figures');
if ~exist(OUTDIR,'dir'), mkdir(OUTDIR); end
P = @(f) fullfile(BASE,'..','System','protocols',f);
T = @(f) fullfile(BASE,'..','System','target_data',f);

panels = {
  'Control (H251N ctrl)', 'twitch_6state_control', P('protocol_1s_slowonset.txt'), T('Con_target_ext.txt'),   [0.17 0.63 0.17];
  'HCM (H251N)',          'twitch_6state_HCM',     P('protocol_1s_slowonset.txt'), T('H251N_target_ext.txt'), [0.84 0.15 0.16];
};

fig = figure('Visible','off','Position',[60 60 1200 460]);
for c = 1:2
    md   = fullfile(BASE, panels{c,2});
    opts = fullfile(md,'sim_input','sim_options.json');
    model= fullfile(md,'temp','best_slow','model_best.json');
    [t,tgt,sim,e] = run_and_align(model, panels{c,3}, panels{c,4}, opts);

    ax = subplot(1,2,c); hold(ax,'on');
    plot(ax,t,tgt,'k-','LineWidth',2.2,'DisplayName','Data');
    plot(ax,t,sim,'-','Color',panels{c,5},'LineWidth',2.2, ...
         'DisplayName',sprintf('6-state best fit (e=%.4f)',e));
    xlabel(ax,'Time (s)','FontSize',12); ylabel(ax,'Force (N/m²)','FontSize',12);
    title(ax,panels{c,1},'FontSize',13,'FontWeight','bold');
    legend(ax,'Location','northeast','Box','off','FontSize',11);
    grid(ax,'on'); ax.GridAlpha=0.2;
    set(ax,'Color','w','XColor','k','YColor','k','FontSize',10);
    xlim(ax,[t(1) t(end)]);
end
sgtitle('6-state best fit — slow onset (83 ms) + rezero','FontSize',14,'FontWeight','bold');
set(fig,'Color','w');
out = fullfile(OUTDIR,'best_fit_overlay_6state.png');
exportgraphics(fig,out,'Resolution',150);
fprintf('Saved: %s\n', out);
close(fig);
end

function [t,tgt_raw,sim_aligned,e] = run_and_align(model,prot,tgtf,opts)
prow = readtable(prot,'FileType','text','Delimiter','\t'); dt = prow.(1)(1);
tgt_raw = dlmread(tgtf); n=numel(tgt_raw); t=(0:n-1)'*dt;
tmin=min(tgt_raw); tmax=max(tgt_raw);
fa=find(tgt_raw>tmin+0.05*(tmax-tmin),1,'first'); if isempty(fa)||fa<2, fa=2; end
pass=1:(fa-1); if numel(pass)>5, lp=pass(round(0.5*end):end); else, lp=pass; end
s=simulation(model,prot,opts); s.implement_protocol; sa=s.sim_output.muscle_force;
sw=sa(end-n+1:end); sim_aligned=sw-mean(sw(lp))+mean(tgt_raw(lp));
ai=fa:n; e=sum(((sim_aligned(ai)-tgt_raw(ai))./(tmax-tmin)).^2)/numel(ai);
end
