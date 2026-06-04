% test_4state_HCM_k100.m — Test 4-state with series_k=100 against HCM target
% Uses best model from HCM fit (series_k=0) but with k=100
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_4state_HCM/sim_input/sim_options.json';
target_file   = 'code/demos/fitting/twitch_4state_HCM/target/H251N_target.txt';

target = dlmread(target_file);
n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
t_axis = (0:n-1)' * 0.001;

% Test with different series_k values
k_vals = [0, 50, 100];
labels = {'k=0', 'k=50', 'k=100'};
colors = {[0 0.7 0], [0.1 0.5 0.9], [0.8 0.2 0.2]};

model_struct = loadjson('code/demos/fitting/twitch_4state_HCM/sim_input/model_template.json');
% Use HCM template parameters
fprintf('Testing 4-state HCM with different series_k values...\n');

fig = figure('Position', [100 100 900 500], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 2, 'DisplayName', 'H251N target');

for ik = 1:numel(k_vals)
    model_struct.MyoSim_model.muscle_props.series_k_linear = k_vals(ik);
    tmp = sprintf('temp_hcm_k%d.json', k_vals(ik));
    of = fopen(tmp, 'w');
    fprintf(of, '%s', savejson('MyoSim_model', model_struct.MyoSim_model));
    fclose(of);

    try
        sim = simulation_driver( ...
            'model_json_file_string', tmp, ...
            'simulation_protocol_file_string', protocol_file, ...
            'options_json_file_string', options_file);
        f = sim.muscle_force(end-n+1:end);
        late = round(0.5*first_active):first_active-1;
        if numel(late)<2, late=1:max(1,first_active-1); end
        f_shifted = f - mean(f(late)) + mean(target(late));
        [pk, pki] = max(f_shifted);
        last_val = f_shifted(end);
        fprintf('%s: peak=%.0f t2pk=%.3f last=%.0f\n', labels{ik}, pk, t_axis(pki), last_val);
        plot(t_axis, f_shifted, '-', 'LineWidth', 1.5, 'Color', colors{ik}, ...
            'DisplayName', sprintf('%s (peak=%.0f)', labels{ik}, pk));
    catch ME
        fprintf('%s: ERROR %s\n', labels{ik}, ME.message);
    end
    if isfile(tmp), delete(tmp); end
end

xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('4-state HCM template: series\_k comparison');
legend; grid on;
exportgraphics(fig, 'test_4state_HCM_k100.png', 'Resolution', 150);
fprintf('Saved\n');
