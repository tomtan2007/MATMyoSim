function parameter_sweep_6state_HCM(opt_file)
% Parameter sweep for 6-state HCM model.
% For each free parameter in opt_file, runs 5 twitch simulations at
% p = [0.1, 0.2, 0.3, 0.4, 0.5] (log-normalized), holding all others
% at best-fit values. Plots peak force and pre-activation SRX (M1+M6)
% vs parameter value (log scale).
%
% Usage:
%   parameter_sweep_6state_HCM              % uses optimization.json
%   parameter_sweep_6state_HCM('optimization_p2.json')

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
cd(fileparts(mfilename('fullpath')));
if nargin < 1, opt_file = 'sim_input/optimization.json'; end

opt = loadjson(opt_file);
opt_s = opt.MyoSim_optimization;
params = opt_s.parameter;

model_best      = loadjson('temp/best/model_best.json');
best_opt        = loadjson(opt_s.best_opt_file_string);
best_params     = best_opt.MyoSim_optimization.parameter;
protocol_file   = opt_s.job{1}.protocol_file_string;
options_file    = opt_s.job{1}.options_file_string;
temp_model_file = 'temp/sweep_model.json';

n_sweep  = 5;
ca_onset = 352;   % rows before Ca activation (protocol_1s.txt onset at row 353)

if ~isfolder('temp/sweeps'), mkdir('temp/sweeps'); end

n_params = length(params);
fig = figure('Name', '6-state sweep', ...
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
        % SRX = M1 (top-row SRX) + M6 (bottom-row SRX), pre-activation mean
        srx_baseline(si) = mean(sim_out.M1(1:ca_onset, 1) + sim_out.M6(1:ca_onset, 1));

        fprintf('  %s=%.4g  peak=%.1f  SRX=%.3f\n', ...
            param_name, actual_val, peak_forces(si), srx_baseline(si));
    end

    % Row 1: peak force
    subplot(2, n_params, pi);
    plot(actual_vals, peak_forces, 'o-', 'LineWidth', 2, ...
         'MarkerFaceColor', [0.5 0.1 0.7], 'MarkerSize', 7, 'Color', [0.5 0.1 0.7]);
    set(gca, 'XScale', 'log');
    xlabel(strrep(param_name, '_', '\_'), 'FontSize', 10);
    ylabel('Peak force (N m^{-2})', 'FontSize', 9);
    title(strrep(param_name, '_', '\_'), 'FontSize', 11);
    box off; grid on;

    % Row 2: SRX baseline occupancy (M1+M6)
    subplot(2, n_params, n_params + pi);
    plot(actual_vals, srx_baseline, 's-', 'LineWidth', 2, ...
         'MarkerFaceColor', [0.8 0.3 0.2], 'MarkerSize', 7, 'Color', [0.8 0.3 0.2]);
    set(gca, 'XScale', 'log');
    xlabel(strrep(param_name, '_', '\_'), 'FontSize', 10);
    ylabel('SRX occupancy (M1+M6)', 'FontSize', 9);
    box off; grid on;
end

sgtitle('6-State HCM', 'FontSize', 13);
saveas(fig, 'temp/sweeps/sweep_6state.png');
fprintf('Saved temp/sweeps/sweep_6state.png\n');
end
