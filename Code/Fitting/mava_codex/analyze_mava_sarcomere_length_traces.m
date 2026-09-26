function [metrics, paired_changes] = analyze_mava_sarcomere_length_traces(data_dir, output_dir)
% Extract descriptive shortening and velocity features from paired SL traces.
%
% Filenames must follow: c<group> mava <cell> <before|acute|24hr>.csv.
% Group labels are retained as supplied; this function does not infer a
% genotype from c3/c4. Derivatives use a 3-sample moving mean only to avoid
% reporting single-sample tracking noise as a velocity extreme.

if nargin < 1 || isempty(data_dir), error('analyze_mava_sarcomere_length_traces:missingData', 'Supply data_dir.'); end
if nargin < 2 || isempty(output_dir), output_dir = fullfile(data_dir, 'analysis'); end
data_dir = char(string(data_dir)); output_dir = char(string(output_dir));
files = dir(fullfile(data_dir, '*.csv'));
if isempty(files), error('analyze_mava_sarcomere_length_traces:noFiles', 'No CSV files in %s.', data_dir); end
if ~isfolder(output_dir), mkdir(output_dir); end

metrics = table;
pattern = '^c(\d+) mava (\d+) (before|acute|24hr)\.csv$';
for i = 1:numel(files)
    tokens = regexp(files(i).name, pattern, 'tokens', 'once');
    if isempty(tokens)
        warning('analyze_mava_sarcomere_length_traces:skippedFile', ...
            'Skipped unexpected file name: %s', files(i).name);
        continue;
    end
    data = readmatrix(fullfile(files(i).folder, files(i).name));
    t = data(:,1); sl = data(:,2);
    valid = isfinite(t) & isfinite(sl);
    t = t(valid); sl = sl(valid);
    if numel(t) < 8 || any(diff(t) <= 0)
        error('analyze_mava_sarcomere_length_traces:badTrace', ...
            'Trace %s must have monotonic time and at least 8 samples.', files(i).name);
    end
    smooth_sl = movmean(sl, 3);
    velocity = gradient(smooth_sl, t);
    n_base = min(10, numel(sl));
    baseline = median(sl(1:n_base));
    [min_sl, min_idx] = min(smooth_sl);
    [max_sl, max_idx] = max(smooth_sl);
    [max_shortening_velocity, short_idx] = min(velocity);
    [max_relengthening_velocity, relength_idx] = max(velocity);
    row = table(string(tokens{1}), string(tokens{2}), string(tokens{3}), ...
        baseline, min_sl, max_sl, baseline-min_sl, max_sl-min_sl, ...
        max_shortening_velocity, max_relengthening_velocity, ...
        t(min_idx), t(max_idx), t(short_idx), t(relength_idx), ...
        'VariableNames', {'group_id','cell_id','condition', ...
        'baseline_sl_um','minimum_sl_um','maximum_sl_um', ...
        'baseline_to_min_shortening_um','trace_excursion_um', ...
        'max_shortening_velocity_um_per_s','max_relengthening_velocity_um_per_s', ...
        'time_minimum_sl_s','time_maximum_sl_s', ...
        'time_max_shortening_velocity_s','time_max_relengthening_velocity_s'});
    metrics = [metrics; row]; %#ok<AGROW>
end
metrics = sortrows(metrics, {'group_id','cell_id','condition'});
writetable(metrics, fullfile(output_dir, 'sarcomere_length_feature_metrics.csv'));

paired_changes = make_paired_changes(metrics);
writetable(paired_changes, fullfile(output_dir, 'sarcomere_length_paired_changes.csv'));
end

function changes = make_paired_changes(metrics)
measurements = {'baseline_to_min_shortening_um','trace_excursion_um', ...
    'max_shortening_velocity_um_per_s','max_relengthening_velocity_um_per_s'};
changes = table;
ids = unique(metrics(:, {'group_id','cell_id'}), 'rows');
for i = 1:height(ids)
    idx = metrics.group_id == ids.group_id(i) & metrics.cell_id == ids.cell_id(i);
    rows = metrics(idx,:);
    before = rows(rows.condition == "before", :);
    for condition = ["acute" "24hr"]
        after = rows(rows.condition == condition, :);
        if height(before) ~= 1 || height(after) ~= 1, continue; end
        delta = nan(1,numel(measurements));
        for j = 1:numel(measurements)
            delta(j) = after.(measurements{j}) - before.(measurements{j});
        end
        row = array2table(delta, 'VariableNames', strcat(measurements, '_change'));
        row = addvars(row, ids.group_id(i), ids.cell_id(i), condition, ...
            'Before', 1, 'NewVariableNames', {'group_id','cell_id','comparison'});
        changes = [changes; row]; %#ok<AGROW>
    end
end
end
