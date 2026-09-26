function [cell_features, group_summary, bootstrap] = ...
        analyze_mava_population_features(workbook_file, output_dir, varargin)
% Extract individual-cell twitch features and bootstrap genotype differences.
%
% Expected layout: one sheet per analysis group; column 1 is time (s), and
% columns 2 onward are individual cells. Sheet names must include Control
% (or Ctrl/WT) or H251N (or HCM/Mut). This deliberately rejects averaged
% six-column workbooks, which cannot provide population uncertainty.

p = inputParser;
addRequired(p, 'workbook_file', @(x) ischar(x) || isstring(x));
addRequired(p, 'output_dir', @(x) ischar(x) || isstring(x));
addParameter(p, 'BootstrapSamples', 2000, ...
    @(x) isscalar(x) && x >= 100 && x == floor(x));
addParameter(p, 'RandomSeed', 20260917, ...
    @(x) isscalar(x) && isfinite(x));
parse(p, workbook_file, output_dir, varargin{:});
options = p.Results;
workbook_file = char(string(options.workbook_file));
output_dir = char(string(options.output_dir));
if ~isfile(workbook_file)
    error('analyze_mava_population_features:missingWorkbook', ...
        'Workbook not found: %s', workbook_file);
end
if ~isfolder(output_dir), mkdir(output_dir); end

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
protocol = readtable(fullfile(repo_root, 'Code', 'System', 'protocols', ...
    'protocol_1s.txt'), 'FileType', 'text', 'Delimiter', '\t');
sim_t = cumsum(protocol.dt) - protocol.dt(1);
reference_time = sim_t(find(protocol.pCa < 6.70, 1, 'first'));
feature_names = {'peak_amplitude','force_onset_delay','rise_20_to_50', ...
    'time_to_peak','duration_above_50','peak_plateau_duration', ...
    'relaxation_50_time','relaxation_90_time', ...
    'auc_to_relax50_normalized'};

all_rows = table;
sheets = sheetnames(workbook_file);
for i = 1:numel(sheets)
    [genotype, recognized] = genotype_from_label(sheets{i});
    if ~recognized, continue; end
    raw = readcell(workbook_file, 'Sheet', sheets{i});
    if size(raw,2) < 3
        error('analyze_mava_population_features:notIndividualCells', ...
            'Sheet %s has fewer than two cell columns.', sheets{i});
    end
    t = numeric_column(raw(2:end,1));
    for col = 2:size(raw,2)
        y = numeric_column(raw(2:end,col));
        valid = isfinite(t) & isfinite(y);
        if sum(valid) < 8, continue; end
        ti = t(valid); yi = y(valid);
        try
            landmarks = detect_mava_trace_landmarks(ti, yi);
            ti = ti - landmarks.trough_time + reference_time;
            yi = yi - landmarks.baseline_value;
            metric = mava_feature_metrics(ti, yi, ...
                'ReferenceOnsetTime', reference_time, ...
                'BaselineIndices', find(ti < reference_time));
        catch ME
            warning('analyze_mava_population_features:excludedTrace', ...
                'Excluded %s column %d: %s', sheets{i}, col, ME.message);
            continue;
        end
        values = nan(1,numel(feature_names));
        for k = 1:numel(feature_names), values(k) = metric.(feature_names{k}); end
        row = array2table(values, 'VariableNames', feature_names);
        header = string(raw{1,col});
        if ismissing(header) || strlength(header)==0, header = "cell" + col; end
        row = addvars(row, string(sheets{i}), genotype, header, ...
            'Before', 1, 'NewVariableNames', {'sheet','genotype','cell_id'});
        all_rows = [all_rows; row]; %#ok<AGROW>
    end
end
if height(all_rows) < 4 || numel(unique(all_rows.genotype)) < 2
    error('analyze_mava_population_features:insufficientCells', ...
        'Need at least two recognized genotypes and four valid cell traces.');
end
cell_features = all_rows;
writetable(cell_features, fullfile(output_dir, 'cell_feature_metrics.csv'));

group_summary = summarize_groups(cell_features, feature_names);
writetable(group_summary, fullfile(output_dir, 'group_feature_summary.csv'));
bootstrap = bootstrap_differences(cell_features, feature_names, ...
    options.BootstrapSamples, options.RandomSeed);
writetable(bootstrap, fullfile(output_dir, 'bootstrap_h251n_minus_control.csv'));
end

function value = numeric_column(cells)
value = nan(numel(cells),1);
for i = 1:numel(cells)
    if isnumeric(cells{i}) && isscalar(cells{i}), value(i) = cells{i}; end
end
end

function [genotype, recognized] = genotype_from_label(label)
label = lower(string(label));
if contains(label, {'h251','hcm','mut'})
    genotype = "H251N"; recognized = true;
elseif contains(label, {'control','ctrl','wt'})
    genotype = "Control"; recognized = true;
else
    genotype = ""; recognized = false;
end
end

function summary = summarize_groups(cells, features)
summary = table;
groups = unique(cells.genotype);
for i = 1:numel(groups)
    idx = cells.genotype == groups(i);
    for j = 1:numel(features)
        x = cells.(features{j})(idx); x = x(isfinite(x));
        row = table(groups(i), string(features{j}), numel(x), mean(x), ...
            median(x), std(x), 'VariableNames', ...
            {'genotype','feature','n','mean','median','sd'});
        summary = [summary; row]; %#ok<AGROW>
    end
end
end

function results = bootstrap_differences(cells, features, n_boot, seed)
rng(seed, 'twister');
results = table;
for j = 1:numel(features)
    control = cells.(features{j})(cells.genotype == "Control");
    hcm = cells.(features{j})(cells.genotype == "H251N");
    control = control(isfinite(control)); hcm = hcm(isfinite(hcm));
    if numel(control) < 2 || numel(hcm) < 2, continue; end
    delta = nan(n_boot,1);
    for b = 1:n_boot
        delta(b) = mean(hcm(randi(numel(hcm),numel(hcm),1))) - ...
            mean(control(randi(numel(control),numel(control),1)));
    end
    ci = prctile(delta, [2.5 97.5]);
    p_two_sided = min(1, 2*min(mean(delta >= 0), mean(delta <= 0)));
    row = table(string(features{j}), mean(hcm)-mean(control), ci(1), ci(2), ...
        p_two_sided, 'VariableNames', {'feature','mean_difference', ...
        'ci_low','ci_high','bootstrap_p_two_sided'});
    results = [results; row]; %#ok<AGROW>
end
end
