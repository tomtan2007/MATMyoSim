function features = mava_feature_analysis(workbook_file, out_dir)
% Extract a reviewable feature table from every trace in a Mava workbook.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fullfile(script_dir, '..', '..', '..');
if nargin < 1 || isempty(workbook_file)
    workbook_file = fullfile(repo_root, 'Code', 'System', ...
        'experimental_data', 'Mava data.xlsx');
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output', 'feature_analysis');
end
if ~isfile(workbook_file)
    error('mava_feature_analysis:missingWorkbook', ...
        'Workbook not found: %s', workbook_file);
end
if ~isfolder(out_dir)
    mkdir(out_dir);
end

sheets = sheetnames(workbook_file);
features = table;
for sheet_idx = 1:numel(sheets)
    sheet = sheets(sheet_idx);
    raw = readcell(workbook_file, 'Sheet', sheet);
    if size(raw, 1) < 6 || size(raw, 2) < 2
        continue;
    end
    headers = string(raw(1, :));
    time_all = numeric_column(raw(2:end, 1));
    for column_idx = 2:size(raw, 2)
        force_all = numeric_column(raw(2:end, column_idx));
        valid = isfinite(time_all) & isfinite(force_all);
        if nnz(valid) < 5
            continue;
        end
        t = time_all(valid);
        y = force_all(valid);
        [t, unique_idx] = unique(t, 'stable');
        y = y(unique_idx);
        if numel(t) < 5 || any(diff(t) <= 0)
            continue;
        end

        landmarks = detect_mava_trace_landmarks(t, y);
        baseline_indices = landmarks.trough_index: ...
            max(landmarks.trough_index, landmarks.rise_index-1);
        metric = mava_feature_metrics(t, y, ...
            'ReferenceOnsetTime', landmarks.trough_time, ...
            'BaselineIndices', baseline_indices);

        trace_name = headers(column_idx);
        if ismissing(trace_name) || strlength(trace_name) == 0
            trace_name = "Column " + column_idx;
        end
        genotype = classify_genotype(trace_name);
        exposure = classify_exposure(trace_name);
        row = metrics_row(metric, sheet, trace_name, genotype, exposure, ...
            numel(t), max(y));
        features = [features; row]; %#ok<AGROW>
    end
end
if isempty(features)
    error('mava_feature_analysis:noTraces', ...
        'No analyzable time-series columns were found in the workbook.');
end

writetable(features, fullfile(out_dir, 'mava_twitch_features.csv'));
group_summary = summarize_feature_groups(features);
writetable(group_summary, fullfile(out_dir, ...
    'mava_twitch_feature_group_summary.csv'));
write_feature_dictionary(fullfile(out_dir, 'feature_dictionary.txt'));
plot_feature_overview(features, out_dir);
end

function values = numeric_column(cells)
values = nan(size(cells));
for i = 1:numel(cells)
    value = cells{i};
    if isnumeric(value) && isscalar(value)
        values(i) = value;
    elseif islogical(value) && isscalar(value)
        values(i) = double(value);
    elseif ischar(value) || (isstring(value) && isscalar(value))
        parsed = str2double(string(value));
        if isfinite(parsed)
            values(i) = parsed;
        end
    end
end
end

function genotype = classify_genotype(name)
lower_name = lower(name);
if contains(lower_name, "h251n") || contains(lower_name, "hcm")
    genotype = "H251N";
elseif contains(lower_name, "control") || contains(lower_name, "ctrl")
    genotype = "Control";
else
    genotype = "Unknown";
end
end

function exposure = classify_exposure(name)
lower_name = lower(name);
if contains(lower_name, "24")
    exposure = "24 h";
elseif contains(lower_name, "acute")
    exposure = "Acute";
elseif contains(lower_name, "before") || contains(lower_name, "baseline")
    exposure = "Before";
else
    exposure = "Unknown";
end
end

function row = metrics_row(m, sheet, trace_name, genotype, exposure, ...
        n_points, raw_max)
row = table(string(sheet), trace_name, genotype, exposure, n_points, raw_max, ...
    m.baseline, m.baseline_noise_mad, m.peak_amplitude, ...
    m.peak_plateau_level, m.peak_time_centroid, ...
    m.peak_plateau_duration, m.force_onset_time, m.force_onset_delay, ...
    m.time_to_peak, m.rise_20_time, m.rise_30_time, m.rise_50_time, ...
    m.rise_90_time, m.rise_20_to_50, m.rise_50_to_90, ...
    m.relaxation_50_time, m.relaxation_90_time, ...
    m.decay_50_from_plateau_end, m.decay_90_from_plateau_end, ...
    m.duration_above_20, m.duration_above_50, m.duration_above_90, ...
    m.auc_positive, m.auc_normalized, m.auc_rise, m.auc_relaxation, ...
    m.relaxation_to_rise_auc_ratio, m.auc_to_relax50, ...
    m.auc_to_relax50_normalized, m.auc_to_relax90, ...
    m.auc_to_relax90_normalized, m.integration_duration, ...
    m.max_force_rate, m.min_force_rate, m.signal_to_noise, ...
    m.missing_relaxation_50, m.missing_relaxation_90, m.low_signal_to_noise, ...
    'VariableNames', {'sheet','trace','genotype','exposure','n_points', ...
    'raw_max','baseline','baseline_noise_mad','peak_amplitude', ...
    'peak_plateau_level','peak_time','plateau_duration','force_onset_time', ...
    'force_onset_delay','time_to_peak','rise_20_time','rise_30_time', ...
    'rise_50_time','rise_90_time','rise_20_to_50','rise_50_to_90', ...
    'relaxation_50_time','relaxation_90_time', ...
    'decay_50_from_plateau_end','decay_90_from_plateau_end', ...
    'duration_above_20','duration_above_50','duration_above_90', ...
    'auc_positive','auc_normalized','auc_rise','auc_relaxation', ...
    'relaxation_to_rise_auc_ratio','auc_to_relax50', ...
    'auc_to_relax50_normalized','auc_to_relax90', ...
    'auc_to_relax90_normalized','integration_duration', ...
    'max_force_rate','min_force_rate','signal_to_noise', ...
    'missing_relaxation_50','missing_relaxation_90','low_signal_to_noise'});
end

function write_feature_dictionary(file)
fid = fopen(file, 'w');
if fid < 0
    error('mava_feature_analysis:writeFailed', 'Could not write %s.', file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, ['Thresholds are relative to the baseline-corrected robust peak.\n' ...
    'relaxation_50_time: peak-centroid to 50%% remaining force.\n' ...
    'relaxation_90_time: peak-centroid to 10%% remaining force.\n' ...
    'duration_above_X: rising-to-falling width at X%% amplitude.\n' ...
    'plateau_duration: contiguous time at or above 95%% amplitude.\n' ...
    'auc_normalized: full available positive AUC divided by peak amplitude.\n' ...
    'auc_to_relax50_normalized: comparable shape AUC ending at 50%% relaxation.\n' ...
    'auc_to_relax90_normalized: shape AUC ending at 90%% relaxation when observed.\n' ...
    'max/min_force_rate: force derivatives, not shortening velocity.\n' ...
    'decay_X_from_plateau_end: decay timing with broad peak duration removed.\n']);
end

function summary = summarize_feature_groups(features)
feature_names = {'peak_amplitude','time_to_peak','relaxation_50_time', ...
    'relaxation_90_time','duration_above_50','plateau_duration', ...
    'auc_to_relax50_normalized','max_force_rate','min_force_rate'};
groups = unique(features(:, {'genotype','exposure'}), 'rows', 'stable');
summary = table;
for group_idx = 1:height(groups)
    selected = features.genotype == groups.genotype(group_idx) & ...
        features.exposure == groups.exposure(group_idx);
    for feature_idx = 1:numel(feature_names)
        feature_name = feature_names{feature_idx};
        values = features.(feature_name)(selected);
        values = values(isfinite(values));
        if isempty(values)
            med = NaN; q1 = NaN; q3 = NaN;
        else
            med = median(values);
            q1 = simple_percentile(values, 25);
            q3 = simple_percentile(values, 75);
        end
        row = table(groups.genotype(group_idx), groups.exposure(group_idx), ...
            string(feature_name), numel(values), med, q1, q3, ...
            'VariableNames', {'genotype','exposure','feature','n', ...
            'median','q1','q3'});
        summary = [summary; row]; %#ok<AGROW>
    end
end
end

function value = simple_percentile(values, percent)
values = sort(values(:));
position = 1 + (numel(values)-1)*percent/100;
lower = floor(position);
upper = ceil(position);
if lower == upper
    value = values(lower);
else
    value = values(lower) + (position-lower)*(values(upper)-values(lower));
end
end

function plot_feature_overview(features, out_dir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [30 30 1200 750]);
labels = categorical(features.trace, features.trace, 'Ordinal', true);
subplot(2, 2, 1);
bar(labels, features.peak_amplitude); ylabel('Peak amplitude'); grid on;
title('Magnitude');
subplot(2, 2, 2);
bar(labels, 1000*[features.time_to_peak features.relaxation_50_time ...
    features.relaxation_90_time]); ylabel('Time (ms)'); grid on;
legend('Time to peak', '50% relaxation', '90% relaxation', ...
    'Location', 'best'); title('Timing');
subplot(2, 2, 3);
bar(labels, 1000*[features.duration_above_50 features.plateau_duration]);
ylabel('Time (ms)'); grid on; legend('Width at 50%', '95% plateau', ...
    'Location', 'best'); title('Shape');
subplot(2, 2, 4);
bar(labels, features.auc_to_relax50_normalized);
ylabel('Onset-to-50%-relaxation AUC / peak (s)'); grid on;
title('Integrated force shape');
for ax = findall(fig, 'Type', 'axes')'
    ax.TickLabelInterpreter = 'none';
    ax.XTickLabelRotation = 25;
end
sgtitle('Mavacamten twitch features');
saveas(fig, fullfile(out_dir, 'mava_feature_overview.png'));
close(fig);
end
