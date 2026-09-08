function plot_mava_sequential_results(run_dir, summary)
% Create the five deterministic analysis figures for one run capsule.

figures_dir = fullfile(run_dir, 'figures');
if ~isfolder(figures_dir), mkdir(figures_dir); end
details = summary.plot_data;
if iscell(details), details = [details{:}]; end
colors = lines(max(3,numel(unique(string({details.group_id})))));

fig = new_figure();
layout = tiledlayout(fig,2,1,'TileSpacing','compact');
ax = nexttile(layout); hold(ax,'on');
groups = unique(string({details.group_id}), 'stable');
for g = 1:numel(groups)
    index = find(string({details.group_id}) == groups(g),1);
    plot(ax, details(index).time, details(index).target, 'LineWidth', 1.8, ...
        'Color', colors(g,:), 'DisplayName', readable_group(groups(g)));
end
xlabel(ax,'time (s)'); ylabel(ax,'force (N m^{-2})');
title(ax,'Acute experimental targets by explicit alignment policy');
legend(ax,'Location','best'); grid(ax,'on'); box(ax,'off');
ax = nexttile(layout);
acute = contains(lower(string(summary.experimental.id)), 'acute');
bar(ax,summary.experimental.peak_ratio_to_before(acute), ...
    'FaceColor',[0.35 0.55 0.75]);
yline(ax,1,'k:'); ylim(ax,[0 1.1]); ylabel(ax,'acute / Before peak');
labels = summary.experimental.group_id(acute);
xticks(ax,1:numel(labels)); xticklabels(ax,labels); xtickangle(ax,25);
title(ax,'Measured acute mavacamten peak-force effect');
grid(ax,'on'); box(ax,'off');
save_png(fig, fullfile(figures_dir, ...
    'experimental_traces_and_alignment.png'));

fig = new_figure();
layout = tiledlayout(fig, numel(groups), 1, 'TileSpacing','compact');
for g = 1:numel(groups)
    ax = nexttile(layout); hold(ax,'on');
    index = best_detail(summary, groups(g), "k123");
    plot(ax,details(index).time,details(index).target,'k-','LineWidth',2, ...
        'DisplayName','acute target');
    plot(ax,details(index).time,details(index).model,'-','LineWidth',1.6, ...
        'Color',colors(g,:),'DisplayName','best k_1/k_2/k_3 fit');
    title(ax,readable_group(groups(g))); grid(ax,'on'); box(ax,'off');
    ylabel(ax,'force'); legend(ax,'Location','best');
end
xlabel(layout,'time (s)'); title(layout,'Boundary-limited k123 fits');
save_png(fig, fullfile(figures_dir, 'k123_failed_fits.png'));

fig = new_figure();
layout = tiledlayout(fig,2,1,'TileSpacing','compact');
ax1 = nexttile(layout); hold(ax1,'on');
ax2 = nexttile(layout); hold(ax2,'on');
for g = 1:numel(groups)
    rows = summary.stage.group_id == groups(g);
    x = 1:sum(rows);
    plot(ax1,x,summary.stage.best_error(rows),'-o','LineWidth',1.5, ...
        'Color',colors(g,:),'DisplayName',readable_group(groups(g)));
    plot(ax2,x,summary.stage.delta_AIC(rows),'-o','LineWidth',1.5, ...
        'Color',colors(g,:),'DisplayName',readable_group(groups(g)));
end
ylabel(ax1,'best normalized error'); grid(ax1,'on'); box(ax1,'off');
ylabel(ax2,'within-group \DeltaAIC'); grid(ax2,'on'); box(ax2,'off');
xlabel(ax2,'nested stage'); xticks(ax2,1:4);
xticklabels(ax2,{'k123','+k5,0','+k4,0','+k7,3'});
legend(ax1,'Location','best');
title(layout,'Sequential fits (AIC is never compared across policies)');
save_png(fig, fullfile(figures_dir, 'sequential_error_aic.png'));

fig = new_figure();
layout = tiledlayout(fig,numel(groups),1,'TileSpacing','compact');
for g = 1:numel(groups)
    ax = nexttile(layout); hold(ax,'on');
    index = best_detail(summary, groups(g), "plus_k73");
    plot(ax,details(index).time,details(index).target,'k-','LineWidth',2, ...
        'DisplayName','acute target');
    plot(ax,details(index).time,details(index).model,'-','LineWidth',1.6, ...
        'Color',colors(g,:),'DisplayName','best plus-k7,3 fit');
    title(ax,readable_group(groups(g))); grid(ax,'on'); box(ax,'off');
    ylabel(ax,'force'); legend(ax,'Location','best');
end
xlabel(layout,'time (s)'); title(layout,'Best defensible final-stage waveforms');
save_png(fig, fullfile(figures_dir, 'best_fit_waveforms.png'));

fig = new_figure();
ax = axes(fig);
final = summary.identifiability.stage == "plus_k73";
values = summary.identifiability.boundary_frequency(final);
labels = summary.identifiability.group_id(final) + ":" + ...
    summary.identifiability.parameter(final);
bar(ax,values,'FaceColor',[0.35 0.55 0.75]);
ylim(ax,[0 1]); ylabel(ax,'boundary frequency');
xticks(ax,1:numel(values)); xticklabels(ax,labels); xtickangle(ax,45);
title(ax,'Final-stage boundary and practical-identifiability diagnostic');
grid(ax,'on'); box(ax,'off');
save_png(fig, fullfile(figures_dir, 'boundary_identifiability.png'));
end

function fig = new_figure
fig = figure('Visible','off','Color','w','Position',[40 40 1100 760]);
end

function index = best_detail(summary, group, stage)
rows = summary.restart.group_id == group & summary.restart.stage == stage;
indices = find(rows);
[~, local] = min(summary.restart.AIC(rows));
id = summary.restart.id(indices(local));
details = summary.plot_data;
index = find(strcmp({details.id},id),1);
end

function label = readable_group(group)
label = strrep(char(group),'__',' — ');
label = strrep(label,'shared_by_genotype','shared by genotype');
label = strrep(label,'independent_trace','independent trace');
end

function save_png(fig, file)
exportgraphics(fig, file, 'Resolution', 150);
close(fig);
end
