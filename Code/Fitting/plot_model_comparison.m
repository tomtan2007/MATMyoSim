function plot_model_comparison
% Overlays 3/4/6-state fits on a single axes for Control and HCM.
% Two figures saved to fit_comparison_figures/.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

BASE     = fileparts(mfilename('fullpath'));
OUTDIR   = fullfile(BASE, 'fit_comparison_figures');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end

PROTOCOL = fullfile(BASE, '..', 'System', 'protocols', 'protocol_1s.txt');
prot     = readtable(PROTOCOL, 'FileType', 'text', 'Delimiter', '\t');
dt       = prot.(1)(1);

% colors: 3-state=blue, 4-state=orange, 6-state=green
colors = {[0.12 0.47 0.71], [1.00 0.50 0.05], [0.17 0.63 0.17]};
labels = {'3-state', '4-state', '6-state'};
states = {'3state', '4state', '6state'};

conditions = {
    'control', 'Con_target.txt',  'Control twitch — all models', 'fits_overlay_control.png';
    'HCM',     'H251N_target.txt','HCM (H251N) twitch — all models', 'fits_overlay_HCM.png';
};

for ci = 1:size(conditions, 1)
    cond       = conditions{ci, 1};
    tgt_file   = conditions{ci, 2};
    fig_title  = conditions{ci, 3};
    out_name   = conditions{ci, 4};

    target_path = fullfile(BASE, '..', 'System', 'target_data', tgt_file);
    tgt_raw     = dlmread(target_path);
    n_tgt       = numel(tgt_raw);
    t_window    = (0:n_tgt-1)' * dt;

    % Pre-activation passive region (mirrors evaluate_time_fit.m)
    tgt_min = min(tgt_raw); tgt_max = max(tgt_raw);
    first_active = find(tgt_raw > tgt_min + 0.05*(tgt_max - tgt_min), 1, 'first');
    if isempty(first_active) || first_active < 2, first_active = 2; end
    passive_idx = 1:(first_active - 1);
    if numel(passive_idx) > 5
        late_passive = passive_idx(round(0.5*end):end);
    else
        late_passive = passive_idx;
    end
    baseline_tgt = mean(tgt_raw(late_passive));

    fig = figure('Visible', 'off', 'Position', [50 50 700 500]);
    ax  = axes('Parent', fig);
    hold(ax, 'on');

    % Plot target data first
    plot(ax, t_window, tgt_raw, 'k-', 'LineWidth', 2, 'DisplayName', 'Data');

    % Plot each model
    for si = 1:3
        state      = states{si};
        model_dir  = fullfile(BASE, sprintf('twitch_%s_%s', state, cond));
        best_model = fullfile(model_dir, 'temp', 'best', 'model_best.json');
        opts_file  = fullfile(model_dir, 'sim_input', 'sim_options.json');
        res_file   = fullfile(model_dir, 'temp', 'best', 'fit_results.json');

        % Read error for legend
        aic_str = '';
        if exist(res_file, 'file')
            r = jsondecode(fileread(res_file));
            aic_str = sprintf(' (e=%.4f)', r.best_error);
        end

        fprintf('Running %s %s ...\n', state, cond);
        try
            s = simulation(best_model, PROTOCOL, opts_file);
            s.implement_protocol;
            sim_all = s.sim_output.muscle_force;
        catch ME
            fprintf('  ERROR: %s\n', ME.message);
            sim_all = nan(n_tgt, 1);
        end

        sim_window  = sim_all(end - n_tgt + 1 : end);
        baseline_sim = mean(sim_window(late_passive));
        sim_aligned  = sim_window - baseline_sim + baseline_tgt;

        plot(ax, t_window, sim_aligned, '-', ...
             'Color', colors{si}, 'LineWidth', 2, ...
             'DisplayName', [labels{si} aic_str]);
    end

    xlabel(ax, 'Time (s)', 'FontSize', 12);
    ylabel(ax, 'Force (N/m²)', 'FontSize', 12);
    title(ax, fig_title, 'FontSize', 13, 'FontWeight', 'bold');
    legend(ax, 'Location', 'northeast', 'FontSize', 10, 'Box', 'off');
    grid(ax, 'on'); ax.GridAlpha = 0.2;
    set(ax, 'FontSize', 10, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    set(fig, 'Color', 'w');

    out_file = fullfile(OUTDIR, out_name);
    exportgraphics(fig, out_file, 'Resolution', 150);
    fprintf('Saved: %s\n', out_file);
    close(fig);
end
fprintf('Done.\n');
end
