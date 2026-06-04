% Opens all 6 parameter sweep figures as interactive MATLAB windows.
% Reads existing JSON results from the _all sweeps.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));
BASE = fileparts(mfilename('fullpath'));

models = {
    '3state_control', 'twitch_3state_control', 'sweep_all_3state_control_results.json', [0.20 0.45 0.80], '3-state Control';
    '3state_HCM',     'twitch_3state_HCM',     'sweep_all_3state_results.json',         [0.20 0.45 0.80], '3-state HCM';
    '4state_control', 'twitch_4state_control',  'sweep_all_4state_control_results.json', [0.85 0.33 0.10], '4-state Control';
    '4state_HCM',     'twitch_4state_HCM',      'sweep_all_4state_results.json',         [0.85 0.33 0.10], '4-state HCM';
    '6state_control', 'twitch_6state_control',  'sweep_all_6state_control_results.json', [0.15 0.65 0.30], '6-state Control';
    '6state_HCM',     'twitch_6state_HCM',      'sweep_all_6state_results.json',         [0.15 0.65 0.30], '6-state HCM';
};

for mi = 1:size(models, 1)
    label      = models{mi, 1};
    demo_dir   = models{mi, 2};
    json_file  = models{mi, 3};
    col        = models{mi, 4};
    title_str  = models{mi, 5};

    json_path  = fullfile(BASE, demo_dir, 'temp', 'sweeps_all', json_file);
    model_path = fullfile(BASE, demo_dir, 'temp', 'best', 'model_best.json');

    if ~isfile(json_path)
        fprintf('Skipping %s — results file not found\n', label);
        continue;
    end

    r = loadjson(json_path);
    m = loadjson(model_path);
    params_best = m.MyoSim_model.hs_props.parameters;

    params     = r.params;
    mults      = r.multipliers;
    peak_f     = r.peak_forces;
    srx_f      = r.srx_frac;
    n_params   = numel(params);
    n_mult     = numel(mults);

    % Build actual parameter values from best-fit × multipliers
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

    fig = figure('Name', title_str, ...
                 'Position', [50 50 min(1800, 160*n_params) 620], ...
                 'Color', 'w', 'NumberTitle', 'off');

    for pi = 1:n_params
        pname = strrep(params{pi}, '_', '\_');

        % Top row: peak force
        subplot(2, n_params, pi);
        plot(actual_vals(pi,:), peak_f(pi,:), 'o-', ...
             'LineWidth', 2, 'MarkerSize', 7, ...
             'Color', col, 'MarkerFaceColor', col);
        hold on;
        best_idx = find(mults == 1.0);
        if ~isempty(best_idx)
            plot(actual_vals(pi, best_idx), peak_f(pi, best_idx), ...
                 'r*', 'MarkerSize', 12, 'LineWidth', 2);
        end
        set(gca, 'XScale', 'log');
        xlabel(pname, 'FontSize', 9);
        if pi == 1, ylabel('Peak force (N/m^2)', 'FontSize', 9); end
        title(pname, 'FontSize', 10, 'Interpreter', 'tex');
        grid on; box off;

        % Bottom row: SRX fraction
        subplot(2, n_params, n_params + pi);
        plot(actual_vals(pi,:), srx_f(pi,:), 's-', ...
             'LineWidth', 2, 'MarkerSize', 7, ...
             'Color', [0.8 0.3 0.2], 'MarkerFaceColor', [0.8 0.3 0.2]);
        hold on;
        if ~isempty(best_idx)
            plot(actual_vals(pi, best_idx), srx_f(pi, best_idx), ...
                 'r*', 'MarkerSize', 12, 'LineWidth', 2);
        end
        set(gca, 'XScale', 'log');
        xlabel(pname, 'FontSize', 9);
        if pi == 1, ylabel('SRX fraction (M1)', 'FontSize', 9); end
        grid on; box off;
    end

    sgtitle(sprintf('%s: peak force and SRX vs parameter  (red * = best-fit)', title_str), ...
            'FontSize', 11, 'FontWeight', 'bold');
end

fprintf('All figures open.\n');
