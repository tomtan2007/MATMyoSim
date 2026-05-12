function plot_HCM_comparison
% Plot 3/4/6-state best fits vs P710R target
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));
cd(fileparts(mfilename('fullpath')));

models = {
    struct('name','3-state','dir','twitch_3state_HCM','color',[0.2 0.6 1.0])
    struct('name','4-state','dir','twitch_4state_HCM','color',[1.0 0.6 0.2])
    struct('name','6-state','dir','twitch_6state_HCM','color',[0.2 0.8 0.3])
};

% Load target
target = load(fullfile(models{1}.dir, 'target', 'P710R_target.txt'));
n = numel(target);
t = (0:n-1) * 0.000486;

figure('Position',[100 100 1200 700],'Color','w');

% Run each model with its best params
sims = cell(1,3);
errs = zeros(1,3);
for i = 1:numel(models)
    m = models{i};
    best_model = fullfile(m.dir, 'temp', 'best', 'model_best.json');
    if ~isfile(best_model)
        fprintf('Skipping %s — no best file yet.\n', m.name);
        continue;
    end
    % Copy to a stable temp file in case the optimizer writes to it
    safe_copy = ['/tmp/' m.name '_safe.json'];
    copyfile(best_model, safe_copy);
    proto = fullfile(m.dir, 'sim_input', 'ca_protocol.txt');
    opts  = fullfile(m.dir, 'sim_input', 'sim_options.json');
    sim   = simulation(safe_copy, proto, opts);
    sim.implement_protocol();
    sims{i} = sim.sim_output.muscle_force;
    errs(i) = sqrt(mean((sims{i}(:) - target).^2)) / mean(abs(target));
    fprintf('%s: e=%.5f\n', m.name, errs(i));
end

% Combined overlay
subplot(2,1,1); hold on; box on;
plot(t, target, 'k-', 'LineWidth', 2, 'DisplayName', 'P710R target');
for i = 1:numel(models)
    if isempty(sims{i}), continue; end
    plot(t, sims{i}, '-', 'Color', models{i}.color, 'LineWidth', 1.4, ...
         'DisplayName', sprintf('%s (e=%.4f)', models{i}.name, errs(i)));
end
xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('P710R HCM fits — 3-state vs 4-state vs 6-state');
legend('Location','northeast'); grid on;

% Zoom on Ca transient
subplot(2,1,2); hold on; box on;
plot(t, target, 'k-', 'LineWidth', 2, 'DisplayName', 'P710R target');
for i = 1:numel(models)
    if isempty(sims{i}), continue; end
    plot(t, sims{i}, '-', 'Color', models{i}.color, 'LineWidth', 1.4, ...
         'DisplayName', sprintf('%s (e=%.4f)', models{i}.name, errs(i)));
end
xlim([0.45 1.5]); xlabel('Time (s)'); ylabel('Force (N/m^2)');
title('Zoomed: Ca transient region');
legend('Location','northeast'); grid on;

out = '/Users/tomtan/Research/MATMyoSim/code/demos/fitting/twitch_HCM_comparison.png';
exportgraphics(gcf, out, 'Resolution', 150);
fprintf('Saved: %s\n', out);
end
