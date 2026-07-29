function parameter_sweep_6state_control(opt_file)
repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
cd(fileparts(mfilename('fullpath')));
if nargin < 1, opt_file = 'sim_input/optimization.json'; end

opt   = loadjson(opt_file);
opt_s = opt.MyoSim_optimization;
params = opt_s.parameter;

model_best      = loadjson('temp/best/model_best.json');
best_opt        = loadjson(opt_s.best_opt_file_string);
best_params     = best_opt.MyoSim_optimization.parameter;
protocol_file   = opt_s.job{1}.protocol_file_string;
options_file    = opt_s.job{1}.options_file_string;
temp_model_file = 'temp/sweep_model.json';

n_sweep  = 5;
ca_onset = 352;

if ~isfolder('temp/sweeps'), mkdir('temp/sweeps'); end

n_params = length(params);
fig = figure('Name', '6-state control sweep', ...
             'Position', [40 40 300*n_params 600], 'Color', 'w');

for pi = 1:n_params
    par        = params{pi};
    param_name = par.name;
    fprintf('Sweeping %s ...\n', param_name);

    % Find optimal p_value for this parameter from best_*.json
    p_opt = 0.5;  % default fallback
    for bi = 1:length(best_params)
        if strcmp(best_params{bi}.name, param_name)
            p_opt = best_params{bi}.p_value;
            break;
        end
    end
    actual_best = return_parameter_value(par, p_opt);
    actual_vals = actual_best * 10.^linspace(-1, 1, n_sweep);

    peak_forces  = zeros(1, n_sweep);
    srx_baseline = zeros(1, n_sweep);

    for si = 1:n_sweep
        actual_val = actual_vals(si);

        model = model_best;
        model.MyoSim_model.hs_props.parameters.(param_name) = actual_val;
        savejson('', model, temp_model_file);

        sim_out = simulation_driver( ...
            'model_json_file_string',          temp_model_file, ...
            'simulation_protocol_file_string', protocol_file, ...
            'options_json_file_string',        options_file);

        peak_forces(si)  = max(sim_out.muscle_force);
        srx_baseline(si) = mean(sim_out.M1(1:ca_onset, 1));

        fprintf('  %s=%.4g  peak=%.1f  SRX=%.3f\n', ...
            param_name, actual_val, peak_forces(si), srx_baseline(si));
    end

    subplot(2, n_params, pi);
    plot(actual_vals, peak_forces, 'o-', 'LineWidth', 2, ...
         'MarkerFaceColor', [0.15 0.55 0.55], 'MarkerSize', 7, 'Color', [0.15 0.55 0.55]);
    set(gca, 'XScale', 'log');
    xlabel(strrep(param_name, '_', '\_'), 'FontSize', 10);
    ylabel('Peak force (N m^{-2})', 'FontSize', 9);
    title(strrep(param_name, '_', '\_'), 'FontSize', 11);
    box off; grid on;

    subplot(2, n_params, n_params + pi);
    plot(actual_vals, srx_baseline, 's-', 'LineWidth', 2, ...
         'MarkerFaceColor', [0.8 0.3 0.2], 'MarkerSize', 7, 'Color', [0.8 0.3 0.2]);
    set(gca, 'XScale', 'log');
    xlabel(strrep(param_name, '_', '\_'), 'FontSize', 10);
    ylabel('SRX occupancy (M1)', 'FontSize', 9);
    box off; grid on;
end

sgtitle('6-State Control', 'FontSize', 13);
saveas(fig, 'temp/sweeps/sweep_6state_control.png');
fprintf('Saved temp/sweeps/sweep_6state_control.png\n');
end
