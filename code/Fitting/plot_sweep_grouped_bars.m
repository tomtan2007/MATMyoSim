function plot_sweep_grouped_bars
% For each model (3/4/6-state), one figure with grouped horizontal bars:
% control (grey) vs HCM (red) side by side for each parameter.
% Bar length = log10(F_max / F_min) across sweep — total sensitivity range.
% Parameters ranked by max sensitivity across both conditions.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));

BASE   = fileparts(mfilename('fullpath'));
OUTDIR = fullfile(BASE, 'sweep_bar_figures');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end

state_list = {'3state', '4state', '6state'};
titles_map = containers.Map({'3state','4state','6state'}, ...
                             {'3-state model','4-state model','6-state model'});

for si = 1:numel(state_list)
    state = state_list{si};

    jp_ctrl = fullfile(BASE, sprintf('twitch_%s_control', state), ...
                       'temp','sweeps_all', sprintf('sweep_all_%s_control_results.json', state));
    jp_hcm  = fullfile(BASE, sprintf('twitch_%s_HCM', state), ...
                       'temp','sweeps_all', sprintf('sweep_all_%s_results.json', state));

    if ~isfile(jp_ctrl) || ~isfile(jp_hcm)
        fprintf('Missing files for %s — skipping\n', state); continue;
    end

    dc = loadjson(jp_ctrl);
    dh = loadjson(jp_hcm);

    % Build a unified param list (union of both)
    all_params = dc.params;
    for pi = 1:numel(dh.params)
        if ~any(strcmp(all_params, dh.params{pi}))
            all_params{end+1} = dh.params{pi}; %#ok<AGROW>
        end
    end
    n_params = numel(all_params);

    sens_ctrl = zeros(n_params, 1);
    sens_hcm  = zeros(n_params, 1);

    for pi = 1:n_params
        pname = all_params{pi};

        idx_c = find(strcmp(dc.params, pname), 1);
        if ~isempty(idx_c)
            row = dc.peak_forces(idx_c, :);
            row = row(row > 0 & ~isnan(row));
            if numel(row) >= 2
                sens_ctrl(pi) = log10(max(row) / min(row));
            end
        end

        idx_h = find(strcmp(dh.params, pname), 1);
        if ~isempty(idx_h)
            row = dh.peak_forces(idx_h, :);
            row = row(row > 0 & ~isnan(row));
            if numel(row) >= 2
                sens_hcm(pi) = log10(max(row) / min(row));
            end
        end
    end

    % Rank by max sensitivity across both conditions
    [~, order] = sort(max(sens_ctrl, sens_hcm), 'ascend');
    sens_ctrl  = sens_ctrl(order);
    sens_hcm   = sens_hcm(order);
    labels     = all_params(order);

    fig = figure('Visible','off','Position',[50 50 700 max(350, n_params*42+140)]);
    ax  = axes('Parent', fig);
    hold(ax, 'on');

    y = 1:n_params;
    bar_w = 0.35;

    % Control bars (grey, offset up)
    barh(ax, y + bar_w/2, sens_ctrl, bar_w, ...
         'FaceColor', [0.55 0.55 0.55], 'EdgeColor','none');

    % HCM bars (red, offset down)
    barh(ax, y - bar_w/2, sens_hcm, bar_w, ...
         'FaceColor', [0.85 0.20 0.20], 'EdgeColor','none');

    clean = cellfun(@(s) strrep(s,'_','\_'), labels, 'UniformOutput',false);
    set(ax, 'YTick', y, 'YTickLabel', clean, 'FontSize', 10, ...
            'TickLength',[0 0]);
    xlabel(ax, 'Sensitivity   log_{10}(F_{max} / F_{min})', 'FontSize', 11);
    title(ax, titles_map(state), 'FontSize', 13, 'FontWeight','bold');
    legend(ax, {'Control','HCM'}, 'Location','southeast', ...
           'FontSize', 10, 'Box','off');

    xlim_val = max([sens_ctrl; sens_hcm]) * 1.15;
    xlim(ax, [0 max(xlim_val, 0.5)]);
    grid(ax, 'on'); ax.GridAlpha = 0.2;
    ax.YGrid = 'off'; ax.XGrid = 'on';
    ylim(ax, [0.5 n_params+0.5]);

    out = fullfile(OUTDIR, sprintf('sweep_grouped_%s.png', state));
    exportgraphics(fig, out, 'Resolution', 150);
    fprintf('Saved: %s\n', out);
    close(fig);
end
fprintf('Done.\n');
end
