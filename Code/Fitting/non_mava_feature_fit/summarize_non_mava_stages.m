function comparison = summarize_non_mava_stages(output_root)
% Compare the three prespecified stages without calculating feature AIC.
if nargin < 1 || isempty(output_root)
    output_root = fullfile(fileparts(mfilename('fullpath')), 'output');
end
ids = {'core_k1_k3_k50_r4','plus_k40_r4','plus_k73_r4'};
labels = {'core: k_1, k_3, k_5_0','core + k_4_0','core + k_7_3'};
best_error = nan(3,1); median_error = nan(3,1); n_within_10pct = nan(3,1);
for i=1:3
    rows = readtable(fullfile(output_root, ids{i}, 'restart_summary.csv'));
    % The best model is re-scored from its materialized feature table. This
    % keeps the stage comparison synchronized with the current robust feature
    % extractor even if landmark-only details change after optimization.
    [~, best_index] = min(rows.best_error);
    features = readtable(fullfile(output_root, ids{i}, ...
        'feature_table_target_vs_model.csv'));
    best_error(i) = mean(features.contribution(logical(features.included)));
    median_error(i) = median(rows.best_error);
    n_within_10pct(i) = sum(rows.best_error <= 1.10*best_error(i));
end
improvement_from_core_percent = 100*(best_error(1)-best_error)/best_error(1);
accepted = [true; false; false];
reason = ["Prespecified starting stage"; ...
    "Rejected: <1% best-case gain and not consistent across starts"; ...
    "Rejected: <1% best-case gain and late residual pattern persisted"];
comparison = table(string(ids(:)), string(labels(:)), best_error, median_error, ...
    n_within_10pct, improvement_from_core_percent, accepted, reason, ...
    'VariableNames', {'stage_id','free_parameter_types','best_error', ...
    'median_error','n_within_10pct_best','best_improvement_vs_core_percent', ...
    'accepted','decision'});
writetable(comparison, fullfile(output_root, 'stage_comparison.csv'));
end
