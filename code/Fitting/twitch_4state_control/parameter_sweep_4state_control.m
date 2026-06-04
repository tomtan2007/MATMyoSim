function parameter_sweep_4state_control(opt_file)
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));
if nargin < 1, opt_file = 'optimization.json'; end

opt   = loadjson(opt_file);
opt_s = opt.MyoSim_optimization;
params = opt_s.parameter;

model_best      = loadjson('temp/best/model_best.json');
protocol_file   = opt_s.job{1}.protocol_file_string;
options_file    = opt_s.job{1}.options_file_string;
temp_model_file = 'temp/sweep_model.json';

p_sweep  = [0.1, 0.2, 0.3, 0.4, 0.5];
n_sweep  = length(p_sweep);
ca_onset = 352;

if ~isfolder('temp/sweeps'), mkdir('temp/sweeps'); end

n_params = length(params);
fig = figure('Name', '4-state control sweep', ...
             'Position', [40 40 300*n_params 600], 'Color', 'w');

for pi = 1:n_params
    par        = params{pi};
    param_name = par.name;
    fprintf('Sweeping %s ...\n', param_name);

    peak_forces  = zeros(1, n_sweep);
    srx_baseline = zeros(1, n_sweep);
    actual_vals  = zeros(1, n_sweep);

    for si = 1:n_sweep
        actual_val      = return_parameter_value(par, p_sweep(si));
        actual_vals(si) = actual_val;

        model = model_best;
        model.MyoSim_model.hs_props.parameters.(param_name) = actual_val;
        savejson('', model, temp_model_file);

        sim_out = simulation_driver( ...
            'model_json_file_string',          temp_model_file, ...
            'simulation_protocol_file_string', protocol_file, ...
            'options_json_file_string',        options_file);

        peak_forces(si)  = max(sim_out.muscle_force);
        srx_baseline(si) = mean(sim_out.M1(1:ca_onset, 1));

        fprintf('  p=%.1f  %s=%.4g  peak=%.1f  SRX=%.3f\n', ...
            p_sweep(si), param_name, actual_val, peak_forces(si), srx_baseline(si));
    end

    subplot(2, n_params, pi);
    plot(actual_vals, peak_forces, 'o-', 'LineWidth', 2, ...
         'MarkerFaceColor', [0.2 0.5 0.2], 'MarkerSize', 7, 'Color', [0.2 0.5 0.2]);
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

sgtitle('4-state Control: peak force and SRX vs parameter', 'FontSize', 13);
saveas(fig, 'temp/sweeps/sweep_4state_control.png');
fprintf('Saved temp/sweeps/sweep_4state_control.png\n');
end
