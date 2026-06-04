% Replot best fits for 3-state and 6-state HCM models vs H251N target.
% Produces a 2-panel figure: (1) force vs time, (2) half-sarcomere length vs time.

cd(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(cd, 'code')));

protocol_file = 'code/demos/twitches/twitch_1/protocols/protocol_1s.txt';
options_file  = 'code/demos/fitting/twitch_6state_HCM/sim_input/sim_options.json';

models = struct( ...
    'label',      {'3-state', '6-state'}, ...
    'model_file', { ...
        'code/demos/fitting/twitch_3state_HCM/temp/best/model_best.json', ...
        'code/demos/fitting/twitch_6state_HCM/temp/best/model_best.json'}, ...
    'target_file',{ ...
        'code/demos/fitting/twitch_3state_HCM/target/H251N_target.txt', ...
        'code/demos/fitting/twitch_6state_HCM/target/H251N_target.txt'}, ...
    'error',      {0.03796, 0.00760}, ...
    'color',      {[0.8 0.2 0.2], [0.1 0.4 0.9]}, ...
    'out_file',   { ...
        'code/demos/fitting/twitch_3state_HCM/best_3state_HCM_fit.png', ...
        'code/demos/fitting/twitch_6state_HCM/best_6state_HCM_fit_final.png'});

for i = 1:numel(models)
    m = models(i);
    fprintf('Running %s simulation...\n', m.label);

    sim_output = simulation_driver( ...
        'model_json_file_string',          m.model_file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string',        options_file);

    target = dlmread(m.target_file);
    n = numel(target);
    t_sim   = sim_output.time_s(end-n+1:end);
    f_sim   = sim_output.muscle_force(end-n+1:end);
    hsl_sim = sim_output.hs_length(end-n+1:end, 1);  % first half-sarcomere

    % Baseline shift: match passive level before activation
    t_min = min(target); t_max = max(target);
    first_active = find(target > t_min + 0.05*(t_max - t_min), 1, 'first');
    if isempty(first_active) || first_active < 2
        bl_y = f_sim(1); bl_t = target(1);
    else
        passive_idx = 1:(first_active-1);
        late = passive_idx(max(1,round(0.5*end)):end);
        bl_y = mean(f_sim(late)); bl_t = mean(target(late));
    end
    f_sim_shifted = f_sim - bl_y + bl_t;

    % --- 2-panel figure ---
    fig = figure('Position', [100 100 900 800], 'Color', 'w', 'Visible', 'off');

    % Panel 1: force
    subplot(2, 1, 1);
    hold on;
    plot(t_sim, target,        'k-', 'LineWidth', 2,   'DisplayName', 'H251N target');
    plot(t_sim, f_sim_shifted, '-',  'LineWidth', 1.5, 'Color', m.color, ...
         'DisplayName', sprintf('%s fit (e=%.4f)', m.label, m.error));
    xline(t_sim(first_active), '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'Ca onset');
    xlabel('Time (s)');
    ylabel('Force (N/m^2)');
    title(sprintf('%s HCM fit vs H251N target', m.label));
    legend('Location', 'best');
    grid on;
    ylim([-2000 11000]);

    % Panel 2: half-sarcomere length
    subplot(2, 1, 2);
    hold on;
    plot(t_sim, hsl_sim, '-', 'LineWidth', 1.5, 'Color', m.color, ...
         'DisplayName', sprintf('%s hs\\_length', m.label));
    xline(t_sim(first_active), '--', 'Color', [0.5 0.5 0.5], 'DisplayName', 'Ca onset');
    xlabel('Time (s)');
    ylabel('Half-sarcomere length (nm)');
    title('Half-sarcomere length vs time');
    legend('Location', 'best');
    grid on;

    exportgraphics(fig, m.out_file, 'Resolution', 150);
    fprintf('Saved: %s\n', m.out_file);
    close(fig);
end

fprintf('Done.\n');
