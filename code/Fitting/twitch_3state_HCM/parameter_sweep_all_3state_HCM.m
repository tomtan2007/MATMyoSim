function parameter_sweep_all_3state_HCM
% Sweeps ALL kinetic parameters of the best-fit 3-state HCM model.
% Each parameter is varied at x0.1, x0.316, x1.0, x3.16, x10 of best-fit.
% Produces a 2-row figure: top=peak force, bottom=pre-activation SRX (M1).
% Saves to temp/sweeps_all/sweep_all_3state.png

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

PROTOCOL  = fullfile('..', '..', 'System', 'protocols', 'protocol_1s.txt');
OPTS_FILE = fullfile('sim_input', 'sim_options.json');
BEST_MODEL = fullfile('temp', 'best', 'model_best.json');
OUT_DIR   = fullfile(fileparts(mfilename('fullpath')), 'temp', 'sweeps_all');
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

model_best = loadjson(BEST_MODEL);
params_best = model_best.MyoSim_model.hs_props.parameters;

% Parameters to sweep (non-structural, non-physical-constant)
% 3-state model only has these kinetic params; none are zero in best-fit
sweep_params = {'k_1', 'k_force', 'k_2', 'k_3', 'k_4_0', 'k_4_1', ...
                'k_cb', 'k_on', 'k_off', 'k_coop'};

ZERO_BASELINE = 0.01;

multipliers = [0.1, 0.3162, 1.0, 3.162, 10.0];
n_params = numel(sweep_params);
n_mult   = numel(multipliers);

% Ca activation onset: protocol_1s.txt has Ca onset at row 353 (0-indexed=352)
ca_onset = 352;

peak_forces = zeros(n_params, n_mult);
srx_frac    = zeros(n_params, n_mult);

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

    for mi = 1:n_mult
        mult = multipliers(mi);
        new_val = base_val * mult;

        model_sweep = model_best;
        model_sweep.MyoSim_model.hs_props.parameters.(pname) = new_val;

        tmp_model = fullfile(fileparts(mfilename('fullpath')), 'temp', sprintf('sweep_3s_%s_m%d.json', pname, mi));
        savejson('', model_sweep, tmp_model);

        try
            s = simulation(tmp_model, PROTOCOL, OPTS_FILE);
            s.implement_protocol;

            peak_forces(pi, mi) = max(s.sim_output.muscle_force);
            srx_frac(pi, mi)    = mean(s.sim_output.M1(1:ca_onset, 1));
        catch ME
            fprintf('  ERROR at mult=%.3f: %s\n', mult, ME.message);
            peak_forces(pi, mi) = NaN;
            srx_frac(pi, mi)    = NaN;
        end
        delete(tmp_model);
    end
end

% Normalize SRX to fraction (M1 is a population fraction 0-1)
% peak force in N/m^2, already correct units

fig = figure('Visible', 'off', 'Position', [50 50 1600 800]);

x_tick_labels = {'x0.1','x0.316','x1','x3.16','x10'};

% Row 1: peak force
for pi = 1:n_params
    subplot(2, n_params, pi);
    plot(1:n_mult, peak_forces(pi,:), 'bo-', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
    hold on;
    plot(3, peak_forces(pi, 3), 'r*', 'MarkerSize', 10); % best-fit mark
    set(gca, 'XTick', 1:n_mult, 'XTickLabel', x_tick_labels, 'FontSize', 7);
    xtickangle(45);
    title(sweep_params{pi}, 'Interpreter', 'none', 'FontSize', 8);
    if pi == 1, ylabel('Peak force (N/m^2)', 'FontSize', 8); end
    xlim([0.5 n_mult+0.5]);
end

% Row 2: SRX (M1)
for pi = 1:n_params
    subplot(2, n_params, n_params + pi);
    plot(1:n_mult, srx_frac(pi,:), 'ms-', 'LineWidth', 1.5, 'MarkerFaceColor', 'm');
    hold on;
    plot(3, srx_frac(pi, 3), 'r*', 'MarkerSize', 10);
    set(gca, 'XTick', 1:n_mult, 'XTickLabel', x_tick_labels, 'FontSize', 7);
    xtickangle(45);
    title(sweep_params{pi}, 'Interpreter', 'none', 'FontSize', 8);
    if pi == 1, ylabel('Pre-act SRX (M1 fraction)', 'FontSize', 8); end
    xlim([0.5 n_mult+0.5]);
end

sgtitle('3-state HCM: all-parameter sweep (red * = best-fit)', 'FontSize', 11);

out_file = fullfile(OUT_DIR, 'sweep_all_3state.png');
exportgraphics(fig, out_file, 'Resolution', 120);
fprintf('Saved: %s\n', out_file);

% Save numeric results
results.params = sweep_params;
results.multipliers = multipliers;
results.peak_forces = peak_forces;
results.srx_frac = srx_frac;
savejson('', results, fullfile(OUT_DIR, 'sweep_all_3state_results.json'));
fprintf('Done — 3-state sweep complete.\n');
end
