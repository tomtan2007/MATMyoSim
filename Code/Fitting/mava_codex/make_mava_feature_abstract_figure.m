function outputs = make_mava_feature_abstract_figure(out_dir)
% Build the PI-review figure for the capped feature-fit prototype.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
if nargin < 1 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output', ...
        'feature_abstract_packet_20260916');
end
if ~isfolder(out_dir)
    mkdir(out_dir);
end

analysis_dir = fullfile(script_dir, 'output', 'feature_analysis');
run_root = fullfile(script_dir, 'output', 'feature_smoke_runs');
experimental = readtable(fullfile(analysis_dir, ...
    'mava_twitch_features.csv'), 'TextType', 'string');

run_ids = { ...
    'feature_proto_control_k1_k3_k50_calibrated_20260916', ...
    'feature_proto_control_5p_20260916', ...
    'feature_proto_hcm_k1_k3_k50_calibrated_20260916', ...
    'feature_proto_hcm_5p_20260916'};
scores = nan(1, numel(run_ids));
residual_tables = cell(1, numel(run_ids));
for i = 1:numel(run_ids)
    run_dir = fullfile(run_root, run_ids{i});
    summary = loadjson(fullfile(run_dir, 'smoke_summary.json'));
    scores(i) = summary.final_error;
    residual_tables{i} = readtable(fullfile(run_dir, ...
        'feature_residuals.csv'), 'TextType', 'string');
end

prepared_dir = fullfile(out_dir, 'prepared_data');
prepare_mava_data([], prepared_dir, 'peak', 'shared_by_genotype');
[ctrl_t, ctrl_target, ctrl_model] = load_feature_fit_waveform( ...
    fullfile(run_root, run_ids{2}), prepared_dir, 'ctrl');
[hcm_t, hcm_target, hcm_model] = load_feature_fit_waveform( ...
    fullfile(run_root, run_ids{4}), prepared_dir, 'hcm');

fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [30 30 1600 940]);
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile(layout, 1);
plot_amplitude_ratios(experimental);
title({'A  Mavacamten lowers peak force', ...
    'Averaged source traces; Before = 1'});

nexttile(layout, 2);
score_matrix = [scores(1) scores(2); scores(3) scores(4)];
b = bar(score_matrix, 'grouped');
b(1).FaceColor = [0.35 0.62 0.80];
b(2).FaceColor = [0.87 0.43 0.28];
set(gca, 'XTickLabel', {'Control', 'H251N'});
ylabel('Mean squared standardized feature error');
legend({'3 parameters', '5 parameters'}, 'Location', 'northwest');
title({'B  Capped single-start fits', ...
    'Lower is better; no feature AIC'});
grid on; box off;

nexttile(layout, 3);
plot_residual_heatmap(residual_tables{2}, residual_tables{4});
title({'C  Five-parameter residuals', ...
    '(model - target) / provisional tolerance'});

nexttile(layout, 4);
plot_waveform(ctrl_t, ctrl_target, ctrl_model, [0.15 0.45 0.75]);
title({'D  Control acute', ...
    'Onset mismatch remains'});

nexttile(layout, 5);
plot_waveform(hcm_t, hcm_target, hcm_model, [0.82 0.28 0.22]);
title({'E  H251N acute', ...
    'Five-parameter exploratory fit'});

nexttile(layout, 6);
axis off;
text(0, 0.96, 'Interpretation', 'FontWeight', 'bold', 'FontSize', 13);
text(0, 0.80, sprintf([ ...
    '\x2022 Feature objective runs end-to-end; the pointwise\n' ...
    '   pipeline is preserved.\n' ...
    '\x2022 Acute Mava peak: 30%% of Before in Control and\n' ...
    '   33%% in H251N averaged traces.\n' ...
    '\x2022 Added relaxation freedom improved H251N only\n' ...
    '   within these capped evaluation budgets.\n' ...
    '\x2022 Control onset requires stimulus-alignment metadata.\n' ...
    '\x2022 No unique kinetic-driver claim is supported.']), ...
    'VerticalAlignment', 'top', 'FontSize', 10.5, ...
    'Interpreter', 'none');
text(0, 0.16, sprintf([ ...
    'Next gate\nNormalized cells -> feature variability/covariance\n' ...
    '-> frozen alignment -> multistart fits']), ...
    'VerticalAlignment', 'top', 'FontSize', 10.5, ...
    'FontWeight', 'bold', 'Interpreter', 'none');

title(layout, 'Feature-based twitch fitting: PI-review prototype', ...
    'FontSize', 17, 'FontWeight', 'bold');
subtitle(layout, ['Exploratory averaged Mava traces; 6-state model; ' ...
    'single-start fits stopped at 30 or 50 evaluations']);

png_file = fullfile(out_dir, 'mava_feature_abstract_figure.png');
pdf_file = fullfile(out_dir, 'mava_feature_abstract_figure.pdf');
exportgraphics(fig, png_file, 'Resolution', 220);
exportgraphics(fig, pdf_file, 'ContentType', 'vector');
close(fig);

score_table = table(["Control"; "Control"; "H251N"; "H251N"], ...
    [3; 5; 3; 5], [30; 50; 30; 50], scores(:), ...
    'VariableNames', {'condition','free_parameter_count', ...
    'evaluation_budget','feature_error'});
score_file = fullfile(out_dir, 'prototype_feature_scores.csv');
writetable(score_table, score_file);
normalize_lf(score_file);
outputs = struct('png_file', png_file, 'pdf_file', pdf_file, ...
    'score_file', score_file);
end

function normalize_lf(file)
fid = fopen(file, 'rb');
if fid < 0
    error('make_mava_feature_abstract_figure:readFailed', ...
        'Could not read %s.', file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8');
clear cleanup;
cr_indices = find(bytes(1:end-1) == 13 & bytes(2:end) == 10);
bytes(cr_indices) = [];
fid = fopen(file, 'wb');
if fid < 0
    error('make_mava_feature_abstract_figure:writeFailed', ...
        'Could not write %s.', file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, bytes, 'uint8');
end

function plot_amplitude_ratios(experimental)
genotypes = ["Control", "H251N"];
exposures = ["Before", "Acute", "24 h"];
ratios = nan(numel(genotypes), numel(exposures));
for g = 1:numel(genotypes)
    baseline = experimental.peak_amplitude( ...
        experimental.genotype == genotypes(g) & ...
        experimental.exposure == "Before");
    for e = 1:numel(exposures)
        value = experimental.peak_amplitude( ...
            experimental.genotype == genotypes(g) & ...
            experimental.exposure == exposures(e));
        ratios(g, e) = value(1) / baseline(1);
    end
end
b = bar(ratios, 'grouped');
b(1).FaceColor = [0.25 0.25 0.25];
b(2).FaceColor = [0.35 0.62 0.80];
b(3).FaceColor = [0.42 0.70 0.47];
set(gca, 'XTickLabel', cellstr(genotypes));
ylabel('Peak force / paired Before peak');
ylim([0 1.15]);
legend(cellstr(exposures), 'Location', 'southoutside', ...
    'Orientation', 'horizontal');
grid on; box off;
end

function plot_residual_heatmap(control, hcm)
selected = control.included == 1 | hcm.included == 1;
names = control.feature(selected);
values = [control.standardized_residual(selected), ...
    hcm.standardized_residual(selected)];
imagesc(values, [-6 6]);
colormap(gca, red_blue_map(257));
colorbar;
set(gca, 'XTick', 1:2, 'XTickLabel', {'Control', 'H251N'}, ...
    'YTick', 1:numel(names), 'YTickLabel', prettify_features(names), ...
    'TickLabelInterpreter', 'none');
for row = 1:size(values, 1)
    for col = 1:size(values, 2)
        if isfinite(values(row, col))
            text(col, row, sprintf('%.1f', values(row, col)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
                'Color', text_color(values(row, col)));
        else
            text(col, row, 'n/a', 'HorizontalAlignment', 'center', ...
                'Color', [0.35 0.35 0.35]);
        end
    end
end
box off;
end

function labels = prettify_features(names)
labels = replace(names, '_', ' ');
labels = replace(labels, 'auc to relax50 normalized', 'normalized AUC to 50% relax');
labels = replace(labels, 'duration above 50', 'width at 50%');
labels = replace(labels, 'peak plateau duration', '95% plateau width');
labels = replace(labels, 'relaxation 50 time', 'peak to 50% relax');
labels = replace(labels, 'relaxation 90 time', 'peak to 90% relax');
labels = replace(labels, 'rise 20 to 50', '20%-50% rise');
end

function color = text_color(value)
if abs(value) > 3
    color = [1 1 1];
else
    color = [0.05 0.05 0.05];
end
end

function map = red_blue_map(n)
half = ceil(n/2);
blue = [linspace(0.16, 1, half)' linspace(0.42, 1, half)' ones(half, 1)];
red = [ones(n-half, 1) linspace(1, 0.28, n-half)' ...
    linspace(1, 0.22, n-half)'];
map = [blue; red];
end

function plot_waveform(t, target, model, model_color)
target_peak = max(target);
plot(t, target/target_peak, 'k-', 'LineWidth', 2.1); hold on;
plot(t, model/target_peak, '-', 'Color', model_color, 'LineWidth', 1.8);
xline(0, ':', 'Reference onset', 'LabelVerticalAlignment', 'bottom');
xlabel('Time from reference onset (s)');
ylabel('Force / target peak');
legend({'Target', 'Feature-fit model'}, 'Location', 'best');
xlim([0 max(t)]);
grid on; box off;
end

function [t, target, model] = load_feature_fit_waveform(run_dir, data_dir, prefix)
config = loadjson(fullfile(run_dir, 'feature_optimization.json'));
opt = config.MyoSim_optimization;
model_file = find_single_file(run_dir, 'model_best.json');
protocol_file = fullfile(data_dir, [prefix '_acute_protocol.txt']);
target_file = fullfile(data_dir, [prefix '_acute_target.txt']);
sim = simulation_driver('model_json_file_string', model_file, ...
    'simulation_protocol_file_string', protocol_file, ...
    'options_json_file_string', opt.job{1}.options_file_string);
target = load(target_file);
n = numel(target);
t = sim.time_s(end-n+1:end);
model = sim.muscle_force(end-n+1:end);
fit_start = opt.job{1}.fit_start_index;
model = align_time_fit_baseline(model, target, fit_start);
t = t - t(fit_start);
end

function file = find_single_file(root, name)
listing = dir(fullfile(root, '**', name));
if numel(listing) ~= 1
    error('make_mava_feature_abstract_figure:fileCount', ...
        'Expected one %s under %s; found %d.', name, root, numel(listing));
end
file = fullfile(listing(1).folder, listing(1).name);
end
