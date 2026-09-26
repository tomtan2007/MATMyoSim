function summary = run_mava_followup_multistart(primary_run_dir, followup_dir, mode)
% Run 100 additional starts for the AIC-selected Mavacamten stages.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(script_dir);

primary_run_dir = char(string(primary_run_dir));
followup_dir = char(string(followup_dir));
mode = char(string(mode));
if ~ismember(mode, {'dry_run','execute','summarize'})
    error('run_mava_followup_multistart:badMode', ...
        'Mode must be dry_run, execute, or summarize.');
end

manifest = loadjson(fullfile(primary_run_dir, 'manifest.json'));
if ~strcmp(char(string(manifest.status)), 'complete')
    error('run_mava_followup_multistart:primaryIncomplete', ...
        'The primary capsule must be complete before the 100-start follow-up.');
end
stage_file = fullfile(primary_run_dir, 'tables', 'stage_summary.csv');
if ~isfile(stage_file)
    error('run_mava_followup_multistart:missingStageTable', ...
        'Summarize the primary capsule before starting the follow-up.');
end

selection = select_groups(readtable(stage_file, 'TextType', 'string'));
if strcmp(mode, 'summarize')
    summary = summarize_followup(followup_dir, selection);
    return;
end
if ~isfolder(followup_dir)
    mkdir(followup_dir);
    copyfile(fullfile(primary_run_dir, 'data'), fullfile(followup_dir, 'data'));
end
writetable(selection, fullfile(followup_dir, 'selected_stages.csv'));
if strcmp(mode, 'dry_run')
    summary = selection;
    return;
end

settings = struct('fit_start_index', manifest.settings.fit_start_index, ...
    'max_fun_evals', manifest.settings.max_fun_evals, ...
    'tol_fun', manifest.settings.tol_fun, 'tol_x', manifest.settings.tol_x);
for g = 1:height(selection)
    for restart = 5:(4 + selection.n_new_starts(g))
        [config_file, record] = build_mava_sequential_fit_config( ...
            followup_dir, char(selection.alignment_policy(g)), ...
            char(selection.genotype(g)), char(selection.stage(g)), ...
            restart, [], settings);
        required = {fullfile(record.result_dir, 'model_best.json'), ...
            fullfile(record.result_dir, 'best_optimization.json'), ...
            fullfile(record.result_dir, 'fit_results.json')};
        if all(cellfun(@isfile, required)), continue; end
        write_status(record, 'running');
        loaded = loadjson(config_file);
        opt = loaded.MyoSim_optimization;
        opt.model_working_file_string = opt.job{1}.model_file_string;
        opt.best_model_file_string = fullfile(record.result_dir, 'model_best.json');
        try
            fit_controller(opt);
            write_status(record, 'complete');
        catch ME
            write_status(record, 'failed', ME);
            rethrow(ME);
        end
    end
end
summary = summarize_followup(followup_dir, selection);
end

function selection = select_groups(stage)
groups = ["shared_by_genotype__Control"; "shared_by_genotype__H251N"; ...
    "independent_trace__Control"];
allocations = [15; 70; 15];
selection = table(groups, allocations, 'VariableNames', {'group_id','n_new_starts'});
selection.alignment_policy = strings(height(selection),1);
selection.genotype = strings(height(selection),1);
selection.stage = strings(height(selection),1);
for i = 1:height(selection)
    rows = stage.group_id == selection.group_id(i) & logical(stage.defensible);
    if ~any(rows)
        error('run_mava_followup_multistart:noDefensibleStage', ...
            'No defensible stage for %s.', selection.group_id(i));
    end
    candidates = stage(rows,:);
    [~, best] = min(candidates.best_AIC);
    selection.alignment_policy(i) = candidates.alignment_policy(best);
    selection.genotype(i) = candidates.genotype(best);
    selection.stage(i) = candidates.stage(best);
end
end

function summary = summarize_followup(followup_dir, selection)
rows = table;
for g = 1:height(selection)
    for restart = 5:(4 + selection.n_new_starts(g))
        result_dir = fullfile(followup_dir, 'results', ...
            char(selection.alignment_policy(g)), char(selection.genotype(g)), ...
            char(selection.stage(g)), sprintf('s%02d', restart));
        fit_file = fullfile(result_dir, 'fit_results.json');
        opt_file = fullfile(result_dir, 'best_optimization.json');
        if ~isfile(fit_file) || ~isfile(opt_file), continue; end
        fit = loadjson(fit_file);
        loaded = loadjson(opt_file);
        opt = loaded.MyoSim_optimization;
        D = mava_boundary_diagnostics(opt.parameter);
        boundary_hit = any(D.classification ~= "interior");
        row = table(selection.group_id(g), selection.alignment_policy(g), ...
            selection.genotype(g), selection.stage(g), restart, ...
            fit.best_error, fit.aic, fit.exitflag, boundary_hit, ...
            'VariableNames', {'group_id','alignment_policy','genotype','stage', ...
            'restart','best_error','AIC','exitflag','boundary_hit'});
        rows = [rows; row]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(followup_dir, 'restart_summary.csv'));
group_summary = table;
for g = 1:height(selection)
    D = rows(rows.group_id == selection.group_id(g), :);
    if isempty(D), continue; end
    near = D.AIC - min(D.AIC) <= 2;
    group_summary = [group_summary; table(selection.group_id(g), ...
        height(D), sum(D.exitflag > 0), min(D.best_error), ...
        median(D.best_error), max(D.best_error), sum(D.boundary_hit), ...
        sum(near), 'VariableNames', {'group_id','completed_starts', ...
        'converged_starts','best_error','median_error','worst_error', ...
        'boundary_starts','near_optimal_starts'})]; %#ok<AGROW>
end
writetable(group_summary, fullfile(followup_dir, 'group_summary.csv'));
summary = struct('restart', rows, 'group', group_summary);
end

function write_status(record, state, ME)
if nargin < 3, ME = []; end
status = struct('alignment_policy', record.alignment_policy, ...
    'genotype', record.genotype, 'stage', record.stage, ...
    'restart', record.restart, 'status', state, ...
    'updated_at', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')));
if ~isempty(ME), status.identifier = ME.identifier; status.message = ME.message; end
fid = fopen(fullfile(record.result_dir, 'status.json'), 'w');
if fid < 0, error('run_mava_followup_multistart:writeFailed', 'Cannot write status.'); end
fprintf(fid, '%s', jsonencode(status)); fclose(fid);
end
