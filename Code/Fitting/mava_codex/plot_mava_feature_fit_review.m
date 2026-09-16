function plot_mava_feature_fit_review(sim_output, target, fit_start_index, ...
        details, output_file)
% Plot waveform context and standardized feature residuals for review.

target = target(:);
n = numel(target);
t = sim_output.time_s(end-n+1:end);
model = sim_output.muscle_force(end-n+1:end);
model = align_time_fit_baseline(model, target, fit_start_index);

fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [40 40 1150 760]);
subplot(2, 1, 1);
plot(t, target, 'k-', 'LineWidth', 2); hold on;
plot(t, model, 'Color', [0.10 0.42 0.75], 'LineWidth', 1.8);
xline(t(fit_start_index), ':', 'Reference onset', ...
    'LabelVerticalAlignment', 'bottom');
xlabel('Time (s)'); ylabel('Force (N m^{-2})');
legend('Target', 'Feature-fit model', 'Location', 'best');
title('Waveform context (not the optimized pointwise objective)');
grid on; box off;

subplot(2, 1, 2);
selected = details.included;
labels = categorical(details.feature(selected), ...
    details.feature(selected), 'Ordinal', true);
values = details.standardized_residual(selected);
bar(labels, values, 'FaceColor', [0.23 0.58 0.43]); hold on;
yline(1, '--r', '+1 tolerance');
yline(-1, '--r', '-1 tolerance');
ylabel('(model - target) / tolerance');
title('Feature residuals used by the optimizer');
grid on; box off;
ax = gca;
ax.TickLabelInterpreter = 'none';
ax.XTickLabelRotation = 25;

sgtitle('Feature-based twitch-fit review');
saveas(fig, output_file);
close(fig);
end
