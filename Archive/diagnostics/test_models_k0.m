% test_models_k0.m — Quick test of all 3 models with series_k_linear=0
% using template parameters (no fitting yet) to verify they produce
% a proper twitch shape (peak then fall) with protocol_1s.txt
cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
target_file   = 'code/demos/fitting/twitch_3state_control/target/Con_target.txt';
target = dlmread(target_file);
n = numel(target);
t_min = min(target); t_max = max(target);
first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
t_axis = (0:n-1)' * 0.001;

models = struct( ...
    'label',   {'3-state', '4-state', '6-state'}, ...
    'template',{ ...
        'code/demos/fitting/twitch_3state_control/sim_input/model_template.json', ...
        'code/demos/fitting/twitch_4state_control/sim_input/model_template.json', ...
        'code/demos/fitting/twitch_6state_control/sim_input/model_template.json'}, ...
    'options', { ...
        'code/demos/fitting/twitch_3state_control/sim_input/sim_options.json', ...
        'code/demos/fitting/twitch_4state_control/sim_input/sim_options.json', ...
        'code/demos/fitting/twitch_6state_control/sim_input/sim_options.json'}, ...
    'color',   {[0.9 0.2 0.2], [0.1 0.5 0.9], [0.1 0.7 0.3]});

fig = figure('Position', [100 100 1000 600], 'Color', 'w', 'Visible', 'off');
hold on;
plot(t_axis, target, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Control target');

for i = 1:numel(models)
    m = models(i);
    ms = loadjson(m.template);
    ms.MyoSim_model.muscle_props.series_k_linear = 0;  % Force isometric

    tmp = sprintf('temp_test_k0_%d.json', i);
    of = fopen(tmp, 'w');
    fprintf(of, '%s', savejson('MyoSim_model', ms.MyoSim_model));
    fclose(of);

    try
        sim = simulation_driver( ...
            'model_json_file_string', tmp, ...
            'simulation_protocol_file_string', protocol_file, ...
            'options_json_file_string', m.options);
        f = sim.muscle_force(end-n+1:end);
        late = round(0.5*first_active):first_active-1;
        if numel(late) < 2, late = 1:max(1,first_active-1); end
        f_shifted = f - mean(f(late)) + mean(target(late));
        [pk, pki] = max(f_shifted);
        last10 = f_shifted(round(end*0.85):end);
        fall = mean(last10) < 0.5 * pk;
        fprintf('%s (k=0): peak=%.0f t2pk=%.3f fall=%d\n', m.label, pk, t_axis(pki), fall);
        plot(t_axis, f_shifted, '-', 'LineWidth', 1.5, 'Color', m.color, ...
            'DisplayName', sprintf('%s (k=0, peak=%.0f)', m.label, pk));
    catch ME
        fprintf('%s: ERROR %s\n', m.label, ME.message);
    end
    if isfile(tmp), delete(tmp); end
end

xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('All 3 models with series\_k\_linear=0 (template params)');
legend; grid on;
exportgraphics(fig, 'test_models_k0.png', 'Resolution', 150);
fprintf('Saved test_models_k0.png\n');
