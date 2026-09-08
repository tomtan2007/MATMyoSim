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
    index = representative_detail(summary, groups(g), "k123");
    plot(ax,details(index).time,details(index).target,'k-','LineWidth',2, ...
        'DisplayName','acute target');
    plot(ax,details(index).time,details(index).model,'-','LineWidth',1.6, ...
        'Color',colors(g,:),'DisplayName','best k_1/k_2/k_3 fit');
    label_row = summary.figure_labels.group_id == groups(g);
    title(ax,sprintf('%s | %s', readable_group(groups(g)), ...
        summary.figure_labels.k123_label(label_row))); ...
        grid(ax,'on'); box(ax,'off');
    ylabel(ax,'force'); legend(ax,'Location','best');
end
xlabel(layout,'time (s)'); title(layout,'Observed k123 fit evidence');
save_png(fig, fullfile(figures_dir, 'k123_failed_fits.png'));

fig = new_figure();
layout = tiledlayout(fig,3,1,'TileSpacing','compact');
ax1 = nexttile(layout); hold(ax1,'on');
ax2 = nexttile(layout); hold(ax2,'on');
ax3 = nexttile(layout); hold(ax3,'on');
for g = 1:numel(groups)
    rows = summary.stage.group_id == groups(g);
    x = 1:sum(rows);
    plot(ax1,x,summary.stage.best_error(rows),'-o','LineWidth',1.5, ...
        'Color',colors(g,:),'DisplayName',readable_group(groups(g)));
    plot(ax2,x,summary.stage.delta_AIC(rows),'-o','LineWidth',1.5, ...
        'Color',colors(g,:),'DisplayName',readable_group(groups(g)));
    plot(ax3,x,summary.stage.akaike_weight(rows),'-o','LineWidth',1.5, ...
        'Color',colors(g,:),'DisplayName',readable_group(groups(g)));
end
ylabel(ax1,'best normalized error'); grid(ax1,'on'); box(ax1,'off');
ylabel(ax2,'within-group \DeltaAIC'); grid(ax2,'on'); box(ax2,'off');
ylabel(ax3,'stage Akaike weight'); grid(ax3,'on'); box(ax3,'off');
xlabel(ax3,'nested stage'); xticks(ax3,1:4);
xticklabels(ax3,{'k123','+k5,0','+k4,0','+k7,3'});
legend(ax1,'Location','best');
title(layout,'Sequential fits (AIC is never compared across policies)');
save_png(fig, fullfile(figures_dir, 'sequential_error_aic.png'));

fig = new_figure();
layout = tiledlayout(fig,numel(groups),1,'TileSpacing','compact');
for g = 1:numel(groups)
    ax = nexttile(layout); hold(ax,'on');
    label_row = summary.figure_labels.group_id == groups(g);
    selected_stage = summary.figure_labels.best_stage(label_row);
    if strlength(selected_stage) == 0
        text(ax,0.5,0.5,'No defensible stage: no converged restart', ...
            'HorizontalAlignment','center','Units','normalized');
        title(ax,readable_group(groups(g))); axis(ax,'off');
        continue;
    end
    index = representative_detail(summary, groups(g), selected_stage);
    plot(ax,details(index).time,details(index).target,'k-','LineWidth',2, ...
        'DisplayName','acute target');
    plot(ax,details(index).time,details(index).model,'-','LineWidth',1.6, ...
        'Color',colors(g,:),'DisplayName',char(selected_stage));
    title(ax,sprintf('%s | %s', readable_group(groups(g)), ...
        summary.figure_labels.best_stage_label(label_row))); ...
        grid(ax,'on'); box(ax,'off');
    ylabel(ax,'force'); legend(ax,'Location','best');
end
xlabel(layout,'time (s)'); title(layout,'Evidence-selected defensible waveforms');
save_png(fig, fullfile(figures_dir, 'best_fit_waveforms.png'));

fig = new_figure();
layout = tiledlayout(fig,numel(groups),1,'TileSpacing','compact');
for g = 1:numel(groups)
    ax = nexttile(layout);
    label_row = summary.figure_labels.group_id == groups(g);
    selected_stage = summary.figure_labels.best_stage(label_row);
    if strlength(selected_stage) == 0
        text(ax,0.5,0.5,char(summary.figure_labels. ...
            identifiability_label(label_row)), 'HorizontalAlignment','center', ...
            'Units','normalized');
        axis(ax,'off');
        continue;
    end
    rows = summary.identifiability.group_id == groups(g) & ...
        summary.identifiability.stage == selected_stage;
    values = summary.identifiability.boundary_frequency(rows);
    labels = summary.identifiability.parameter(rows) + newline + ...
        summary.identifiability.classification(rows) + newline + ...
        "spread=" + compose('%.2g', summary.identifiability. ...
        log10_spread_near_optimal(rows));
    bar(ax,values,'FaceColor',colors(g,:));
    ylim(ax,[0 1]); ylabel(ax,'boundary frequency');
    xticks(ax,1:numel(values)); xticklabels(ax,labels); xtickangle(ax,35);
    title(ax,sprintf('%s | %s',readable_group(groups(g)), ...
        summary.figure_labels.identifiability_label(label_row)));
    grid(ax,'on'); box(ax,'off');
end
title(layout,['Boundary plus practical identifiability ' ...
    '(multistart evidence; not structural identifiability)']);
save_png(fig, fullfile(figures_dir, 'boundary_identifiability.png'));
end

function fig = new_figure
fig = figure('Visible','off','Color','w','Position',[40 40 1100 760]);
end

function index = representative_detail(summary, group, stage)
row = summary.stage.group_id == group & summary.stage.stage == stage;
id = summary.stage.representative_id(row);
details = summary.plot_data;
index = find(strcmp({details.id},id),1);
end

function label = readable_group(group)
label = strrep(char(group),'__',' — ');
label = strrep(label,'shared_by_genotype','shared by genotype');
label = strrep(label,'independent_trace','independent trace');
end

function save_png(fig, file)
parent = fileparts(file);
temporary = [tempname(parent) '.png'];
cleanup = onCleanup(@() delete_if_present(temporary));
exportgraphics(fig, temporary, 'Resolution', 150);
close(fig);
[ok,message] = movefile(temporary,file,'f');
if ~ok
    error('plot_mava_sequential_results:writeFailed', ...
        'Could not publish %s: %s',file,message);
end
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
