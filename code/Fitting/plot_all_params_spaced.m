function plot_all_params_spaced(model_tag)
% Replot _all sweep data in spaced-out format matching the original sweep style.
% Splits parameters across figures of 7 per page.
% Usage: plot_all_params_spaced('4state_control')
%        plot_all_params_spaced('4state_HCM')
%        plot_all_params_spaced('6state_control')
%        plot_all_params_spaced('6state_HCM')

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));
BASE = fileparts(mfilename('fullpath'));

% Map tag to paths
switch model_tag
    case '4state_control'
        demo_dir  = 'twitch_4state_control';
        json_file = 'sweep_all_4state_control_results.json';
        col       = [0.2 0.5 0.2];
        title_str = '4-state Control';
    case '4state_HCM'
        demo_dir  = 'twitch_4state_HCM';
        json_file = 'sweep_all_4state_results.json';
        col       = [0.2 0.5 0.2];
        title_str = '4-state HCM';
    case '6state_control'
        demo_dir  = 'twitch_6state_control';
        json_file = 'sweep_all_6state_control_results.json';
        col       = [0.15 0.55 0.55];
        title_str = '6-state Control';
    case '6state_HCM'
        demo_dir  = 'twitch_6state_HCM';
        json_file = 'sweep_all_6state_results.json';
        col       = [0.15 0.55 0.55];
        title_str = '6-state HCM';
    otherwise
        error('Unknown model_tag: %s', model_tag);
end

json_path  = fullfile(BASE, demo_dir, 'temp', 'sweeps_all', json_file);
model_path = fullfile(BASE, demo_dir, 'temp', 'best', 'model_best.json');

r = loadjson(json_path);
m = loadjson(model_path);
params_best = m.MyoSim_model.hs_props.parameters;

params   = r.params;
mults    = r.multipliers;
peak_f   = r.peak_forces;
srx_f    = r.srx_frac;
n_params = numel(params);
n_mult   = numel(mults);
best_idx = find(mults == 1.0);

% Compute actual parameter values
actual_vals = zeros(n_params, n_mult);
for pi = 1:n_params
    pname = params{pi};
    if isfield(params_best, pname)
        bv = params_best.(pname);
        if bv == 0, bv = 0.01; end
    else
        bv = 1;
    end
    actual_vals(pi, :) = bv * mults;
end

% Split into pages of 7 params
per_page = 7;
n_pages  = ceil(n_params / per_page);
out_dir  = fullfile(BASE, demo_dir, 'temp', 'sweeps_all');

for pg = 1:n_pages
    idx_start = (pg-1)*per_page + 1;
    idx_end   = min(pg*per_page, n_params);
    idx       = idx_start:idx_end;
    n_this    = numel(idx);

    fig = figure('Name', sprintf('%s — page %d/%d', title_str, pg, n_pages), ...
                 'Position', [40 40 300*n_this 620], 'Color', 'w', 'NumberTitle', 'off');

    for k = 1:n_this
        pi    = idx(k);
        pname = strrep(params{pi}, '_', '\_');
        xvals = actual_vals(pi, :);

        % Use log scale if range spans >1 order of magnitude
        use_log = (max(xvals) / max(min(xvals), 1e-12)) > 15;

        % Top: peak force
        subplot(2, n_this, k);
        plot(xvals, peak_f(pi,:), 'o-', 'LineWidth', 2, 'MarkerSize', 7, ...
             'Color', col, 'MarkerFaceColor', col);
        hold on;
        if ~isempty(best_idx)
            plot(xvals(best_idx), peak_f(pi, best_idx), 'r*', 'MarkerSize', 12, 'LineWidth', 2);
        end
        if use_log, set(gca, 'XScale', 'log'); end
        xlabel(pname, 'FontSize', 10);
        if k == 1, ylabel('Peak force (N/m^2)', 'FontSize', 9); end
        title(pname, 'FontSize', 11, 'Interpreter', 'tex');
        grid on; box off;

        % Bottom: SRX fraction
        subplot(2, n_this, n_this + k);
        plot(xvals, srx_f(pi,:), 's-', 'LineWidth', 2, 'MarkerSize', 7, ...
             'Color', [0.8 0.3 0.2], 'MarkerFaceColor', [0.8 0.3 0.2]);
        hold on;
        if ~isempty(best_idx)
            plot(xvals(best_idx), srx_f(pi, best_idx), 'r*', 'MarkerSize', 12, 'LineWidth', 2);
        end
        if use_log, set(gca, 'XScale', 'log'); end
        xlabel(pname, 'FontSize', 10);
        if k == 1, ylabel('SRX fraction (M1)', 'FontSize', 9); end
        grid on; box off;
    end

    sgtitle(sprintf('%s: all-param sweep — page %d/%d  (red * = best-fit)', ...
            title_str, pg, n_pages), 'FontSize', 11, 'FontWeight', 'bold');

    out_file = fullfile(out_dir, sprintf('sweep_spaced_%s_p%d.png', model_tag, pg));
    exportgraphics(fig, out_file, 'Resolution', 130);
    fprintf('Saved: %s\n', out_file);
end
fprintf('Done — %d figures for %s\n', n_pages, title_str);
end
