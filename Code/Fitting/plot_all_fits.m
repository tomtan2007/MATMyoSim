function plot_all_fits
% Re-runs each best-fit model and plots simulated force vs target.
% Mirrors evaluate_time_fit.m exactly:
%   - takes the LAST n rows of the sim (where n = length of target)
%   - aligns sim passive level to target passive level using late pre-activation rows
% Produces 2 figures: control (3 panels) and HCM (3 panels).

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));

BASE   = fileparts(mfilename('fullpath'));
OUTDIR = fullfile(BASE, 'fit_comparison_figures');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end

PROTOCOL = fullfile(BASE, '..', 'System', 'protocols', 'protocol_1s.txt');

models = {
    '3state', 'control', 'Con_target.txt',   '3-state', [0.20 0.45 0.80];
    '4state', 'control', 'Con_target.txt',   '4-state', [0.85 0.33 0.10];
    '6state', 'control', 'Con_target.txt',   '6-state', [0.15 0.65 0.30];
    '3state', 'HCM',    'H251N_target.txt',  '3-state', [0.20 0.45 0.80];
    '4state', 'HCM',    'H251N_target.txt',  '4-state', [0.85 0.33 0.10];
    '6state', 'HCM',    'H251N_target.txt',  '6-state', [0.15 0.65 0.30];
};

% Time axis from protocol
prot = readtable(PROTOCOL, 'FileType', 'text', 'Delimiter', '\t');
dt   = prot.(1)(1);

for cond_idx = 1:2
    if cond_idx == 1
        rows      = 1:3;
        fig_title = 'Control twitch fits';
        out_name  = 'fits_control.png';
    else
        rows      = 4:6;
        fig_title = 'HCM (H251N) twitch fits';
        out_name  = 'fits_HCM.png';
    end

    fig = figure('Visible', 'off', 'Position', [50 50 1100 400]);
    sgtitle(fig_title, 'FontSize', 13, 'FontWeight', 'bold');

    for pi = 1:3
        mi        = rows(pi);
        state     = models{mi, 1};
        cond      = models{mi, 2};
        tgt_file  = models{mi, 3};
        lbl       = models{mi, 4};
        col       = models{mi, 5};

        model_dir   = fullfile(BASE, sprintf('twitch_%s_%s', state, cond));
        best_model  = fullfile(model_dir, 'temp', 'best', 'model_best.json');
        opts_file   = fullfile(model_dir, 'sim_input', 'sim_options.json');
        target_path = fullfile(BASE, '..', 'System', 'target_data', tgt_file);

        tgt_raw = dlmread(target_path);
        n_tgt   = numel(tgt_raw);

        fprintf('Running %s %s...\n', state, cond);
        try
            s = simulation(best_model, PROTOCOL, opts_file);
            s.implement_protocol;
            sim_all = s.sim_output.muscle_force;
        catch ME
            fprintf('  ERROR: %s\n', ME.message);
            sim_all = nan(n_tgt, 1);
        end

        % Mirror evaluate_time_fit: take LAST n_tgt rows of simulation
        sim_window = sim_all(end - n_tgt + 1 : end);

        % Find pre-activation passive region in target
        tgt_min = min(tgt_raw); tgt_max = max(tgt_raw);
        first_active = find(tgt_raw > tgt_min + 0.05*(tgt_max - tgt_min), 1, 'first');
        if isempty(first_active) || first_active < 2
            first_active = 2;
        end
        passive_idx = 1:(first_active - 1);
        if numel(passive_idx) > 5
            late_passive = passive_idx(round(0.5*end):end);
        else
            late_passive = passive_idx;
        end

        % Align sim passive to target passive
        baseline_sim = mean(sim_window(late_passive));
        baseline_tgt = mean(tgt_raw(late_passive));
        sim_aligned  = sim_window - baseline_sim + baseline_tgt;

        % Time axis for the target window
        t_window = (0:n_tgt-1)' * dt;

        ax = subplot(1, 3, pi, 'Parent', fig);
        hold(ax, 'on');

        plot(ax, t_window, tgt_raw,    'k-',  'LineWidth', 1.5, 'DisplayName', 'Data');
        plot(ax, t_window, sim_aligned, '-', 'Color', col, ...
             'LineWidth', 2, 'DisplayName', sprintf('%s fit', lbl));

        xlabel(ax, 'Time (s)', 'FontSize', 10);
        if pi == 1
            ylabel(ax, 'Force (N/m²)', 'FontSize', 10);
        end
        title(ax, lbl, 'FontSize', 11, 'FontWeight', 'bold');
        legend(ax, 'Location', 'northeast', 'FontSize', 8, 'Box', 'off');
        grid(ax, 'on'); ax.GridAlpha = 0.2;
        set(ax, 'FontSize', 9);
    end

    out_file = fullfile(OUTDIR, out_name);
    exportgraphics(fig, out_file, 'Resolution', 150);
    fprintf('Saved: %s\n', out_file);
    close(fig);
end
fprintf('Done.\n');
end
