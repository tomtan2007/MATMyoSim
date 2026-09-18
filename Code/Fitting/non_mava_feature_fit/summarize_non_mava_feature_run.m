function outputs = summarize_non_mava_feature_run(run_dir)
% Materialize feature table, residuals, overlays, and restart identifiability.
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root)); addpath(genpath(fullfile(repo_root,'Code','System')));
rows = readtable(fullfile(run_dir, 'restart_summary.csv'), 'TextType', 'string');
[~, ibest] = min(rows.best_error); best_restart = rows.restart(ibest);
restart_dir = fullfile(run_dir, sprintf('s%02d', best_restart));
opt = loadjson(fullfile(restart_dir, 'results', 'joint_feature_fit', ...
    'best_optimization.json')).MyoSim_optimization;
conditions = {'Control','H251N'};
all_details = cell(1,2); simulations = cell(1,2); targets = cell(1,2);
for j = 1:2
    simulations{j} = simulation_driver('model_json_file_string', ...
        opt.best_model_file_string{j}, 'simulation_protocol_file_string', ...
        opt.job{j}.protocol_file_string, 'options_json_file_string', ...
        opt.job{j}.options_file_string);
    targets{j} = load(opt.job{j}.target_file_string);
    [~,~,details] = evaluate_mava_feature_fit(simulations{j}, targets{j}, ...
        'fit_start_index', opt.job{j}.fit_start_index);
    details.condition = repmat(string(conditions{j}), height(details), 1);
    all_details{j} = details;
end
feature_table = [all_details{1}; all_details{2}];
feature_table = movevars(feature_table, 'condition', 'Before', 1);
writetable(feature_table, fullfile(run_dir, 'feature_table_target_vs_model.csv'));

fig = figure('Visible','off','Color','w','Position',[40 40 1150 760]);
for j = 1:2
    target = targets{j}(:); n = numel(target);
    t = simulations{j}.time_s(end-n+1:end);
    model = align_time_fit_baseline(simulations{j}.muscle_force(end-n+1:end), ...
        target, opt.job{j}.fit_start_index);
    subplot(2,1,j); plot(t,target,'k-','LineWidth',2); hold on;
    plot(t,model,'LineWidth',1.7,'Color',[0.12 0.45 0.75]);
    xline(t(opt.job{j}.fit_start_index),':','Ca reference');
    title(conditions{j}); ylabel('Force (N m^{-2})'); grid on; box off;
    if j==2, xlabel('Time (s)'); end
end
legend('Target','Model','Location','best'); sgtitle('Non-Mava joint feature fit');
saveas(fig, fullfile(run_dir, 'trace_overlays.png')); close(fig);

fig = figure('Visible','off','Color','w','Position',[40 40 1200 620]);
for j=1:2
    d=all_details{j}; subplot(1,2,j); keep=d.included;
    bar(categorical(d.feature(keep),d.feature(keep),'Ordinal',true), ...
        d.standardized_residual(keep)); yline(1,'--r'); yline(-1,'--r');
    title(conditions{j}); ylabel('Standardized residual'); grid on;
    ax=gca; ax.TickLabelInterpreter='none'; ax.XTickLabelRotation=35;
end
sgtitle('Feature residuals (model - target) / tolerance');
saveas(fig, fullfile(run_dir, 'feature_residuals.png')); close(fig);

% Decode every restart's bounded coordinates and actual kinetic values.
parameter_rows = table;
for r = 1:height(rows)
    file = fullfile(run_dir, sprintf('s%02d',rows.restart(r)), ...
        'results','joint_feature_fit','best_optimization.json');
    bo = loadjson(file).MyoSim_optimization;
    for i = 1:numel(bo.parameter)
        q = bo.parameter{i};
        actual = return_parameter_value(q, q.p_value);
        parameter_rows = [parameter_rows; table(rows.restart(r), string(q.name), ...
            q.p_value, actual, rows.best_error(r), ...
            'VariableNames',{'restart','parameter','p_value','actual_value','best_error'})]; %#ok<AGROW>
    end
end
writetable(parameter_rows, fullfile(run_dir, 'restart_parameter_values.csv'));
quality_cutoff = min(rows.best_error)*1.10;
near = rows.best_error <= quality_cutoff;
ident = table(height(rows), sum(near), min(rows.best_error), ...
    median(rows.best_error), max(rows.best_error), std(rows.best_error), ...
    quality_cutoff, 'VariableNames', {'n_restarts','n_within_10pct_best', ...
    'best_error','median_error','worst_error','error_sd','near_best_cutoff'});
writetable(ident, fullfile(run_dir, 'identifiability_summary.csv'));
unique_parameters = unique(parameter_rows.parameter, 'stable');
parameter_identifiability = table;
for i = 1:numel(unique_parameters)
    name = unique_parameters(i);
    subset = parameter_rows(parameter_rows.parameter == name, :);
    near_values = subset.actual_value(ismember(subset.restart, rows.restart(near)));
    parameter_identifiability = [parameter_identifiability; table(name, ...
        min(subset.actual_value), max(subset.actual_value), ...
        max(subset.actual_value)/max(min(subset.actual_value), eps), ...
        min(near_values), max(near_values), ...
        'VariableNames', {'parameter','all_restart_min','all_restart_max', ...
        'all_restart_fold_range','near_best_min','near_best_max'})]; %#ok<AGROW>
end
writetable(parameter_identifiability, ...
    fullfile(run_dir, 'parameter_identifiability_summary.csv'));
outputs = struct('best_restart',best_restart,'feature_table',feature_table, ...
    'restart_summary',rows,'identifiability_summary',ident, ...
    'parameter_identifiability',parameter_identifiability);
end
