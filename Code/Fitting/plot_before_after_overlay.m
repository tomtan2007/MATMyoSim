function plot_before_after_overlay
% Overlay data + BEFORE (canonical fast onset) fit + AFTER (slow onset + rezero)
% best fit, on one axes per condition. Time is expressed RELATIVE TO Ca onset so
% the two protocols (different onset timing / length) compare fairly.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
BASE   = fileparts(mfilename('fullpath'));
OUTDIR = fullfile(BASE, 'fit_comparison_figures');
if ~exist(OUTDIR,'dir'), mkdir(OUTDIR); end
P = @(f) fullfile(BASE,'..','System','protocols',f);
T = @(f) fullfile(BASE,'..','System','target_data',f);

cfg = {
  'Control', 'twitch_6state_control', ...
     P('protocol_1s.txt'),           T('Con_target.txt'), 'best', ...
     P('protocol_1s_slowonset.txt'), T('Con_target_ext.txt'), 'best_slow';
  'HCM (H251N)', 'twitch_6state_HCM', ...
     P('protocol_1s.txt'),           T('H251N_target.txt'), 'best', ...
     P('protocol_1s_slowonset.txt'), T('H251N_target_ext.txt'), 'best_slow';
};

c_before = [0.60 0.60 0.60];   % grey  = before (canonical)
c_after  = [0.17 0.63 0.17];   % green = after (slow onset best)

fig = figure('Visible','off','Position',[60 60 1250 480]);
for r = 1:2
    md   = fullfile(BASE, cfg{r,2});
    opts = fullfile(md,'sim_input','sim_options.json');

    [tb,tgtb,simb,eb] = run_and_align(fullfile(md,'temp',cfg{r,5},'model_best.json'), cfg{r,3}, cfg{r,4}, opts);
    [ta,tgta,sima,ea] = run_and_align(fullfile(md,'temp',cfg{r,8},'model_best.json'), cfg{r,6}, cfg{r,7}, opts);

    ax = subplot(1,2,r); hold(ax,'on');
    % data from the AFTER set (same experimental force, cleaner baseline)
    plot(ax,ta,tgta,'k-','LineWidth',2.2,'DisplayName','Data');
    plot(ax,tb,simb,'--','Color',c_before,'LineWidth',2.0, ...
         'DisplayName',sprintf('Before — canonical 41 ms (e=%.4f)',eb));
    plot(ax,ta,sima,'-','Color',c_after,'LineWidth',2.2, ...
         'DisplayName',sprintf('After — slow 83 ms + rezero (e=%.4f)',ea));

    xlabel(ax,'Time from Ca onset (s)','FontSize',12); ylabel(ax,'Force (N/m²)','FontSize',12);
    title(ax,cfg{r,1},'FontSize',13,'FontWeight','bold');
    legend(ax,'Location','northeast','Box','off','FontSize',10);
    grid(ax,'on'); ax.GridAlpha=0.2; xlim(ax,[-0.15 0.9]);
    set(ax,'Color','w','XColor','k','YColor','k','FontSize',10);
end
sgtitle('6-state twitch fit — before vs after protocol change','FontSize',14,'FontWeight','bold');
set(fig,'Color','w');
out = fullfile(OUTDIR,'before_after_overlay_6state.png');
exportgraphics(fig,out,'Resolution',150);
fprintf('Saved: %s\n', out);
close(fig);
end

function [t,tgt_raw,sim_aligned,e] = run_and_align(model,prot,tgtf,opts)
prow = readtable(prot,'FileType','text','Delimiter','\t'); dt = prow.(1)(1);
tgt_raw = dlmread(tgtf); n=numel(tgt_raw);
tmin=min(tgt_raw); tmax=max(tgt_raw);
fa=find(tgt_raw>tmin+0.05*(tmax-tmin),1,'first'); if isempty(fa)||fa<2, fa=2; end
t=((0:n-1)'-(fa-1))*dt;                     % time relative to onset
pass=1:(fa-1); if numel(pass)>5, lp=pass(round(0.5*end):end); else, lp=pass; end
s=simulation(model,prot,opts); s.implement_protocol; sa=s.sim_output.muscle_force;
sw=sa(end-n+1:end); sim_aligned=sw-mean(sw(lp))+mean(tgt_raw(lp));
ai=fa:n; e=sum(((sim_aligned(ai)-tgt_raw(ai))./(tmax-tmin)).^2)/numel(ai);
end
