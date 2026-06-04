function parameter_sweep_all_6state_control
% Sweeps ALL kinetic parameters of the best-fit 6-state control model.
% Each parameter is varied at x0.1, x0.316, x1.0, x3.16, x10 of best-fit.
% Zero-valued params (k_8, k_10) use a small baseline (0.01) for sweep.
% Produces a 2-row figure: top=peak force, bottom=pre-activation SRX (M1+M6).
% Saves to temp/sweeps_all/sweep_all_6state_control.png

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

PROTOCOL  = fullfile('..', '..', 'System', 'protocols', 'protocol_1s.txt');
OPTS_FILE = fullfile('sim_input', 'sim_options.json');
BEST_MODEL = fullfile('temp', 'best', 'model_best.json');
OUT_DIR   = fullfile(fileparts(mfilename('fullpath')), 'temp', 'sweeps_all');
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

model_best = loadjson(BEST_MODEL);
params_best = model_best.MyoSim_model.hs_props.parameters;

sweep_params = {'k_1', 'k_force', 'k_2', 'k_3', 'k_4_0', 'k_4_1', ...
                'k_5_0', 'k_5_1', 'k_6_0', 'k_6_1', 'k_7_0', 'k_7_1', ...
                'k_8', 'k_9', 'k_10', 'k_11', 'k_12', 'k_13', 'k_14', ...
                'k_cb', 'k_on', 'k_off', 'k_coop'};

ZERO_BASELINE = 0.01;
multipliers = [0.1, 0.3162, 1.0, 3.162, 10.0];
n_params = numel(sweep_params);
n_mult   = numel(multipliers);

ca_onset = 352;

peak_forces = zeros(n_params, n_mult);
srx_frac    = zeros(n_params, n_mult);
base_vals   = zeros(1, n_params);

for pi = 1:n_params
    pname = sweep_params{pi};
    raw_val = params_best.(pname);
    if raw_val == 0
        base_val = ZERO_BASELINE;
        fprintf('Sweeping %s (zero param, using baseline=%.3g) ...\n', pname, base_val);
    else
        base_val = raw_val;
        fprintf('Sweeping %s (best=%.4g) ...\n', pname, base_val);
    end
    base_vals(pi) = base_val;

    for mi = 1:n_mult
        mult = multipliers(mi);
        new_val = base_val * mult;

        model_sweep = model_best;
        model_sweep.MyoSim_model.hs_props.parameters.(pname) = new_val;

        tmp_model = fullfile(fileparts(mfilename('fullpath')), 'temp', sprintf('sweep_6sc_%s_m%d.json', pname, mi));
        savejson('', model_sweep, tmp_model);

        try
            s = simulation(tmp_model, PROTOCOL, OPTS_FILE);
            s.implement_protocol;
            peak_forces(pi, mi) = max(s.sim_output.muscle_force);
            % 6-state SRX = M1 (SRXD top row) + M6 (SRXT bottom row)
            srx_frac(pi, mi) = mean(s.sim_output.M1(1:ca_onset, 1) + ...
                                    s.sim_output.M6(1:ca_onset, 1));
        catch ME
            fprintf('  ERROR at mult=%.3f: %s\n', mult, ME.message);
            peak_forces(pi, mi) = NaN;
            srx_frac(pi, mi)    = NaN;
        end
        delete(tmp_model);
    end
end

fig = figure('Visible', 'off', 'Position', [50 50 min(2400, 110*n_params) 800]);
x_tick_labels = {'x0.1','x0.316','x1','x3.16','x10'};

for pi = 1:n_params
    subplot(2, n_params, pi);
    plot(1:n_mult, peak_forces(pi,:), 'bo-', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
    hold on;
    plot(3, peak_forces(pi, 3), 'r*', 'MarkerSize', 10);
    set(gca, 'XTick', 1:n_mult, 'XTickLabel', x_tick_labels, 'FontSize', 6);
    xtickangle(45);
    title(sweep_params{pi}, 'Interpreter', 'none', 'FontSize', 7);
    if pi == 1, ylabel('Peak force (N/m^2)', 'FontSize', 8); end
    xlim([0.5 n_mult+0.5]);
end

for pi = 1:n_params
    subplot(2, n_params, n_params + pi);
    plot(1:n_mult, srx_frac(pi,:), 'ms-', 'LineWidth', 1.5, 'MarkerFaceColor', 'm');
    hold on;
    plot(3, srx_frac(pi, 3), 'r*', 'MarkerSize', 10);
    set(gca, 'XTick', 1:n_mult, 'XTickLabel', x_tick_labels, 'FontSize', 6);
    xtickangle(45);
    title(sweep_params{pi}, 'Interpreter', 'none', 'FontSize', 7);
    if pi == 1, ylabel('Pre-act SRX (M1+M6 frac)', 'FontSize', 8); end
    xlim([0.5 n_mult+0.5]);
end

sgtitle('6-state Control: all-parameter sweep (red * = best-fit; x-axis = multiplier of best-fit)', 'FontSize', 11);

out_file = fullfile(OUT_DIR, 'sweep_all_6state_control.png');
exportgraphics(fig, out_file, 'Resolution', 120);
fprintf('Saved: %s\n', out_file);

results.params = sweep_params;
results.multipliers = multipliers;
results.base_vals = base_vals;
results.peak_forces = peak_forces;
results.srx_frac = srx_frac;
savejson('', results, fullfile(OUT_DIR, 'sweep_all_6state_control_results.json'));
fprintf('Done — 6-state control sweep complete.\n');
end
