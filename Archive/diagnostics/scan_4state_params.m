% scan_4state_params.m — Quick scan of k_5_0 and k_7_0 to find parameter
% combinations that produce a proper twitch shape with series_k_linear=100
% Run from MATMyoSim root directory.

cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_4state_control/sim_input/sim_options.json';
target_file   = 'code/demos/fitting/twitch_4state_control/target/Con_target.txt';
template_file = 'code/demos/fitting/twitch_4state_control/sim_input/model_template.json';

target = dlmread(target_file);
n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
t_axis = (0:n-1)' * 0.001;

% Load template
model_struct = loadjson(template_file);

% Use parameters from the 3-state control best fit (which worked)
% and adapt them for 4-state
base_k1   = 3.67;
base_k3   = 70;
base_k_on = 1e6;
base_k_off = 10;
base_coop = 1.35;

% Scan k_5_0 and k_7_0
k5_vals = [1, 5, 10, 50, 100];
k7_vals = [20, 50, 100, 200, 500];

fig = figure('Position', [100 100 1400 900], 'Color', 'w', 'Visible', 'off');
colors = jet(numel(k5_vals));
sp = 0;

fprintf('k_5_0\t k_7_0\t peak_force\t shape\n');

results = {};
for ik5 = 1:numel(k5_vals)
    k5 = k5_vals(ik5);
    for ik7 = 1:numel(k7_vals)
        k7 = k7_vals(ik7);

        % Update model
        model_struct.MyoSim_model.hs_props.parameters.k_1 = base_k1;
        model_struct.MyoSim_model.hs_props.parameters.k_2 = 10*base_k1;
        model_struct.MyoSim_model.hs_props.parameters.k_3 = base_k3;
        model_struct.MyoSim_model.hs_props.parameters.k_5_0 = k5;
        model_struct.MyoSim_model.hs_props.parameters.k_7_0 = k7;
        model_struct.MyoSim_model.hs_props.parameters.k_on = base_k_on;
        model_struct.MyoSim_model.hs_props.parameters.k_off = base_k_off;
        model_struct.MyoSim_model.hs_props.parameters.k_coop = base_coop;

        % Save temp model
        tmp_file = 'temp_scan_model.json';
        of = fopen(tmp_file, 'w');
        fprintf(of, '%s', savejson('MyoSim_model', model_struct.MyoSim_model));
        fclose(of);

        try
            sim = simulation_driver( ...
                'model_json_file_string',          tmp_file, ...
                'simulation_protocol_file_string', protocol_file, ...
                'options_json_file_string',        options_file);

            f = sim.muscle_force(end-n+1:end);
            % Baseline shift
            late = round(0.5*first_active):first_active-1;
            if numel(late) < 2, late = 1:max(1,first_active-1); end
            f_shifted = f - mean(f(late)) + mean(target(late));

            peak = max(f_shifted);
            post_peak = f_shifted(round(end*0.9):end);
            pre_peak = f_shifted(1:first_active-1);

            % Is there a clear fall? (last 10% < 50% of peak)
            has_fall = mean(post_peak) < 0.5 * peak;
            % Does it peak above 2000?
            peaks_well = peak > 2000;
            shape_ok = has_fall && peaks_well;

            fprintf('k_5_0=%4.0f k_7_0=%4.0f: peak=%5.0f  shape_ok=%d\n', ...
                k5, k7, peak, shape_ok);
            results{end+1} = struct('k5', k5, 'k7', k7, 'peak', peak, ...
                'shape_ok', shape_ok, 'f', f_shifted);
        catch ME
            fprintf('k_5_0=%4.0f k_7_0=%4.0f: ERROR %s\n', k5, k7, ME.message);
        end
    end
end

% Plot good shapes
fig = figure('Position', [100 100 1200 800], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 3, 'DisplayName', 'Control target');
clrs = hsv(numel(results));
for i = 1:numel(results)
    r = results{i};
    if r.shape_ok
        lbl = sprintf('k5=%.0f k7=%.0f (peak=%.0f)', r.k5, r.k7, r.peak);
        plot(t_axis, r.f, '-', 'LineWidth', 1.5, 'Color', clrs(i,:), 'DisplayName', lbl);
    end
end
xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state parameter scan: k\_5\_0 vs k\_7\_0 (shape\_ok only)');
legend('Location', 'best', 'FontSize', 7); grid on;
exportgraphics(fig, 'scan_4state_params.png', 'Resolution', 150);
fprintf('\nSaved scan_4state_params.png\n');

if isfile('temp_scan_model.json'), delete('temp_scan_model.json'); end
