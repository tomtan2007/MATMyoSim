function metrics = analyze_mava_csa_normalized_averages(workbook_file, output_file)
% Extract twitch features from the six CSA-normalized condition averages.
%
% This is intentionally an averaged-trace analysis. It must not be used for
% cell-level confidence intervals, bootstraps, or a population likelihood.

if nargin < 1 || isempty(workbook_file)
    error('analyze_mava_csa_normalized_averages:missingWorkbook', ...
        'Supply the CSA-normalized workbook path.');
end
workbook_file = char(string(workbook_file));
if ~isfile(workbook_file)
    error('analyze_mava_csa_normalized_averages:missingWorkbook', ...
        'Workbook not found: %s', workbook_file);
end
if nargin < 2 || isempty(output_file)
    [folder, name] = fileparts(workbook_file);
    output_file = fullfile(folder, [name '_csa_feature_metrics.csv']);
end

cells = readcell(workbook_file);
headers = string(cells(1, :));
condition_start = find(headers == "Control Before", 1, 'last');
if isempty(condition_start) || condition_start + 5 > size(cells, 2)
    error('analyze_mava_csa_normalized_averages:layout', ...
        'Could not locate six CSA-normalized condition columns.');
end
condition = headers(condition_start:condition_start+5)';
t = cell2mat(cells(2:end, 1));
y_all = cell2mat(cells(2:end, condition_start:condition_start+5));

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
values = nan(6, numel(feature_names));
for i = 1:6
    valid = isfinite(t) & isfinite(y_all(:, i));
    ti = t(valid);
    yi = y_all(valid, i);
    landmarks = detect_mava_trace_landmarks(ti, yi);
    ti = ti - landmarks.trough_time + reference_time;
    yi = yi - landmarks.baseline_value;
    metric = mava_feature_metrics(ti, yi, ...
        'ReferenceOnsetTime', reference_time, ...
        'BaselineIndices', find(ti < reference_time));
    for j = 1:numel(feature_names)
        values(i,j) = metric.(feature_names{j});
    end
end
metrics = array2table(values, 'VariableNames', feature_names);
metrics = addvars(metrics, condition, 'Before', 1, ...
    'NewVariableNames', 'condition');
output_folder = fileparts(output_file);
if ~isempty(output_folder) && ~isfolder(output_folder), mkdir(output_folder); end
writetable(metrics, output_file);
end
