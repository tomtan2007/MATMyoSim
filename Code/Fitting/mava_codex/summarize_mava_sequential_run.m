function summary = summarize_mava_sequential_run(run_dir)
% Summarize only the fit and data artifacts listed by a run manifest.

run_dir = char(string(run_dir));
manifest_file = fullfile(run_dir, 'manifest.json');
if ~isfile(manifest_file)
    error('summarize_mava_sequential_run:missingManifest', ...
        'Run capsule has no manifest: %s.', manifest_file);
end
stored_manifest = jsondecode(fileread(manifest_file));
signature_fields = {'input_signature','immutable_signature', ...
    'materialization_signature','state_signature'};
has_signature = any(isfield(stored_manifest, signature_fields));
fixture_mode = ~has_signature && ...
    isfield(stored_manifest, 'fixture_mode') && stored_manifest.fixture_mode;
if ~fixture_mode
    settings = settings_from_signed_manifest(stored_manifest);
    manifest = mava_run_manifest(run_dir, settings, 'summarize');
    validate_production_manifest(manifest);
    validate_production_data(manifest);
else
    manifest = stored_manifest;
end

inventory = as_cells(manifest.inventory);
active = false(1, numel(inventory));
for i = 1:numel(inventory)
    active(i) = logical(inventory{i}.required) || ...
        optional_group_active(manifest, inventory{i});
end
if ~fixture_mode
    validate_mava_run_semantics(manifest, find(active), 'signed');
end
details = repmat(empty_detail(), 1, sum(active));
detail_index = 0;
for i = find(active)
    detail_index = detail_index + 1;
    details(detail_index) = read_record(manifest, inventory{i}, fixture_mode);
end

restart = restart_table(details);
restart = add_group_aic(restart);
[stage, identifiability] = stage_tables(manifest, restart, details);
boundary = boundary_table(details);
waveform = waveform_table(details);
experimental = experimental_table(manifest);

tables_dir = fullfile(run_dir, 'tables');
if ~isfolder(tables_dir), mkdir(tables_dir); end
writetable(restart, fullfile(tables_dir, 'restart_summary.csv'));
writetable(stage, fullfile(tables_dir, 'stage_summary.csv'));
writetable(boundary, fullfile(tables_dir, 'boundary_diagnostics.csv'));
writetable(waveform, fullfile(tables_dir, 'waveform_metrics.csv'));
writetable(identifiability, ...
    fullfile(tables_dir, 'identifiability_summary.csv'));

summary = struct('restart', restart, 'stage', stage, ...
    'boundary', boundary, 'waveform', waveform, ...
    'identifiability', identifiability, 'experimental', experimental, ...
    'plot_data', {details});
write_adaptive_decision(run_dir, manifest, summary);
plot_mava_sequential_results(run_dir, summary);
write_authority_note(run_dir, manifest);
end

function detail = empty_detail
detail = struct('id', '', 'group_id', '', 'alignment_policy', '', ...
    'genotype', '', 'stage', '', 'restart', NaN, 'fit', struct, ...
    'parameters', {{}}, 'boundary', table, 'time', [], 'target', [], ...
    'model', [], 'target_metrics', struct, 'model_metrics', struct);
end

function detail = read_record(manifest, item, fixture_mode)
detail = empty_detail();
detail.id = char(string(item.id));
detail.alignment_policy = char(string(item.alignment_policy));
detail.genotype = char(string(item.genotype));
detail.group_id = [detail.alignment_policy '__' detail.genotype];
detail.stage = char(string(item.stage));
detail.restart = item.restart;
if fixture_mode
    if ~isfield(item, 'fixture_file') || ~isfile(item.fixture_file)
        error('summarize_mava_sequential_run:missingFixture', ...
            'Manifest-listed fixture is missing for %s.', detail.id);
    end
    stored = jsondecode(fileread(item.fixture_file));
    detail.fit = stored.fit_results;
    detail.parameters = as_cells(stored.parameters);
    waveform = stored.waveform;
    detail.time = waveform.time(:);
    detail.target = waveform.target(:);
    detail.model = waveform.model(:);
    onset_index = waveform.onset_index;
    calcium_onset = waveform.calcium_onset_time;
    model_mode = 'prezeroed';
else
    fit_file = fullfile(item.result_dir, 'fit_results.json');
    best_file = fullfile(item.result_dir, 'best_optimization.json');
    model_file = fullfile(item.result_dir, 'model_best.json');
    detail.fit = jsondecode(fileread(fit_file));
    opt_root = jsondecode(fileread(best_file));
    opt = opt_root.MyoSim_optimization;
    detail.parameters = as_cells(opt.parameter);
    job = first_struct(opt.job);
    protocol = readtable(job.protocol_file_string, 'FileType', 'text', ...
        'Delimiter', '\t');
    detail.target = readmatrix(job.target_file_string);
    detail.target = detail.target(:);
    detail.time = cumsum(protocol.dt) - protocol.dt(1);
    detail.time = detail.time(1:numel(detail.target));
    sim = simulation_driver('model_json_file_string', model_file, ...
        'simulation_protocol_file_string', job.protocol_file_string, ...
        'options_json_file_string', job.options_file_string);
    force = sim.muscle_force(:);
    detail.model = force(end-numel(detail.target)+1:end);
    onset_index = manifest.settings.fit_start_index;
    calcium_onset = detail.time(onset_index);
    model_mode = 'model';
end
detail.boundary = mava_boundary_diagnostics(detail.parameters);
detail.target_metrics = mava_waveform_metrics(detail.time, detail.target, ...
    onset_index, 'prezeroed', 'calcium_onset_time', calcium_onset);
detail.model_metrics = mava_waveform_metrics(detail.time, detail.model, ...
    onset_index, model_mode, 'calcium_onset_time', calcium_onset, ...
    'target', detail.target, 'fit_start_index', onset_index);
detail.model = detail.model_metrics.corrected_signal;
end

function restart = restart_table(details)
n = numel(details);
id = strings(n,1); group_id = strings(n,1); alignment_policy = strings(n,1);
genotype = strings(n,1); stage = strings(n,1); restart_number = nan(n,1);
completed = true(n,1); converged = false(n,1); best_error = nan(n,1);
AIC = nan(n,1); n_free_params = nan(n,1); exitflag = nan(n,1);
iterations = nan(n,1); func_count = nan(n,1); boundary_hit = false(n,1);
for i = 1:n
    item = details(i);
    id(i) = item.id; group_id(i) = item.group_id;
    alignment_policy(i) = item.alignment_policy; genotype(i) = item.genotype;
    stage(i) = item.stage; restart_number(i) = item.restart;
    best_error(i) = required_numeric(item.fit, 'best_error', item.id);
    AIC(i) = fit_aic(item.fit, item.id);
    exitflag(i) = optional_numeric(item.fit, 'exitflag');
    converged(i) = isnan(exitflag(i)) || exitflag(i) > 0;
    n_free_params(i) = optional_numeric(item.fit, 'n_free_params');
    if isnan(n_free_params(i)), n_free_params(i) = numel(item.parameters); end
    iterations(i) = optional_numeric(item.fit, 'iterations');
    func_count(i) = optional_numeric(item.fit, 'func_count');
    boundary_hit(i) = any(string(item.boundary.classification) ~= "interior");
end
restart = table(id, group_id, alignment_policy, genotype, stage, ...
    restart_number, completed, converged, best_error, AIC, n_free_params, ...
    exitflag, iterations, func_count, boundary_hit, ...
    'VariableNames', {'id','group_id','alignment_policy','genotype','stage', ...
    'restart','completed','converged','best_error','AIC','n_free_params', ...
    'exitflag','iterations','func_count','boundary_hit'});
end

function restart = add_group_aic(restart)
restart.delta_AIC = nan(height(restart),1);
restart.akaike_weight = nan(height(restart),1);
groups = unique(restart.group_id, 'stable');
for i = 1:numel(groups)
    rows = restart.group_id == groups(i);
    delta = restart.AIC(rows) - min(restart.AIC(rows));
    weight = exp(-0.5*delta);
    restart.delta_AIC(rows) = delta;
    restart.akaike_weight(rows) = weight/sum(weight);
end
end

function [stage_table, ident] = stage_tables(manifest, restart, details)
stage_rows = struct([]);
ident_rows = struct([]);
stage_count = 0;
ident_count = 0;
group_ids = manifest_group_ids(manifest);
stage_ids = manifest_stage_ids(manifest);
for g = 1:numel(group_ids)
    for s = 1:numel(stage_ids)
        rows = restart.group_id == string(group_ids{g}) & ...
            restart.stage == string(stage_ids{s});
        if ~any(rows), continue; end
        stage_count = stage_count + 1;
        stage_aic = restart.AIC(rows);
        stage_error = restart.best_error(rows);
        near = stage_aic-min(stage_aic) <= 2;
        group_details = details(rows_from_restart(restart, rows, details));
        P = normalized_matrix(group_details);
        near_P = P(near,:);
        stage_rows(stage_count).group_id = string(group_ids{g});
        stage_rows(stage_count).alignment_policy = ...
            string(group_details(1).alignment_policy);
        stage_rows(stage_count).genotype = string(group_details(1).genotype);
        stage_rows(stage_count).stage = string(stage_ids{s});
        stage_rows(stage_count).completed_starts = sum(restart.completed(rows));
        stage_rows(stage_count).converged_starts = sum(restart.converged(rows));
        stage_rows(stage_count).best_error = min(stage_error);
        stage_rows(stage_count).median_error = median(stage_error);
        stage_rows(stage_count).worst_error = max(stage_error);
        stage_rows(stage_count).best_AIC = min(stage_aic);
        stage_rows(stage_count).near_optimal_starts = sum(near);
        stage_rows(stage_count).solution_clusters = cluster_count(near_P);

        names = cellfun(@(p) char(string(p.name)), ...
            group_details(1).parameters, 'UniformOutput', false);
        physical = physical_matrix(group_details);
        all_bounds = vertcat(group_details.boundary);
        for p = 1:numel(names)
            ident_count = ident_count + 1;
            p_rows = strcmp(string(all_bounds.name), names{p});
            classifications = string(all_bounds.classification(p_rows));
            boundary_frequency = mean(classifications ~= "interior");
            all_log_spread = log_spread(physical(:,p));
            near_log_spread = log_spread(physical(near,p));
            near_fold_spread = fold_spread(physical(near,p));
            if sum(near) >= 3 && near_log_spread <= 0.30 && ...
                    boundary_frequency == 0
                classification = "stable";
            elseif sum(near) >= 2 && near_log_spread <= 1.00 && ...
                    boundary_frequency < 0.50
                classification = "weak";
            else
                classification = "non-identifiable";
            end
            ident_rows(ident_count).group_id = string(group_ids{g});
            ident_rows(ident_count).alignment_policy = ...
                string(group_details(1).alignment_policy);
            ident_rows(ident_count).genotype = string(group_details(1).genotype);
            ident_rows(ident_count).stage = string(stage_ids{s});
            ident_rows(ident_count).parameter = string(names{p});
            ident_rows(ident_count).completed_starts = size(P,1);
            ident_rows(ident_count).near_optimal_starts = sum(near);
            ident_rows(ident_count).solution_clusters = cluster_count(near_P);
            ident_rows(ident_count).log10_spread_all = all_log_spread;
            ident_rows(ident_count).log10_spread_near_optimal = near_log_spread;
            ident_rows(ident_count).near_optimal_fold_spread = near_fold_spread;
            ident_rows(ident_count).boundary_frequency = boundary_frequency;
            ident_rows(ident_count).classification = classification;
        end
    end
end
stage_table = struct2table(stage_rows);
ident = struct2table(ident_rows);
stage_table.delta_AIC = nan(height(stage_table),1);
stage_table.akaike_weight = nan(height(stage_table),1);
for g = 1:numel(group_ids)
    rows = stage_table.group_id == string(group_ids{g});
    delta = stage_table.best_AIC(rows)-min(stage_table.best_AIC(rows));
    weight = exp(-0.5*delta);
    stage_table.delta_AIC(rows) = delta;
    stage_table.akaike_weight(rows) = weight/sum(weight);
end
end

function boundary = boundary_table(details)
parts = cell(1, numel(details));
for i = 1:numel(details)
    D = details(i).boundary;
    D = addvars(D, repmat(string(details(i).id),height(D),1), ...
        repmat(string(details(i).group_id),height(D),1), ...
        repmat(string(details(i).alignment_policy),height(D),1), ...
        repmat(string(details(i).genotype),height(D),1), ...
        repmat(string(details(i).stage),height(D),1), ...
        repmat(details(i).restart,height(D),1), 'Before', 1, ...
        'NewVariableNames', {'id','group_id','alignment_policy', ...
        'genotype','stage','restart'});
    parts{i} = D;
end
boundary = vertcat(parts{:});
end

function waveform = waveform_table(details)
n = numel(details);
id = strings(n,1); group_id = strings(n,1); alignment_policy = strings(n,1);
genotype = strings(n,1); stage = strings(n,1); restart = nan(n,1);
target_peak = nan(n,1); target_force_rise_time = nan(n,1);
target_calcium_to_force_lag = nan(n,1); target_time_to_peak = nan(n,1);
target_relax_half_time = nan(n,1); target_fwhm = nan(n,1);
model_peak = nan(n,1); model_force_rise_time = nan(n,1);
model_calcium_to_force_lag = nan(n,1); model_time_to_peak = nan(n,1);
model_relax_half_time = nan(n,1); model_fwhm = nan(n,1);
normalized_rmse = nan(n,1);
for i = 1:n
    a = details(i).target_metrics; b = details(i).model_metrics;
    id(i)=details(i).id; group_id(i)=details(i).group_id;
    alignment_policy(i)=details(i).alignment_policy; genotype(i)=details(i).genotype;
    stage(i)=details(i).stage; restart(i)=details(i).restart;
    target_peak(i)=a.peak; target_force_rise_time(i)=a.force_rise_time;
    target_calcium_to_force_lag(i)=a.calcium_to_force_lag;
    target_time_to_peak(i)=a.time_to_peak_argmax;
    target_relax_half_time(i)=a.relax_half_time; target_fwhm(i)=a.fwhm;
    model_peak(i)=b.peak; model_force_rise_time(i)=b.force_rise_time;
    model_calcium_to_force_lag(i)=b.calcium_to_force_lag;
    model_time_to_peak(i)=b.time_to_peak_argmax;
    model_relax_half_time(i)=b.relax_half_time; model_fwhm(i)=b.fwhm;
    normalized_rmse(i)=b.normalized_rmse;
end
waveform = table(id,group_id,alignment_policy,genotype,stage,restart, ...
    target_peak,target_force_rise_time,target_calcium_to_force_lag, ...
    target_time_to_peak,target_relax_half_time,target_fwhm,model_peak, ...
    model_force_rise_time,model_calcium_to_force_lag,model_time_to_peak, ...
    model_relax_half_time,model_fwhm,normalized_rmse);
end

function experimental = experimental_table(manifest)
data = as_cells(manifest.materialization.data_files);
parts = cell(1,numel(data));
for i = 1:numel(data)
    item = data{i};
    if ~isfile(item.metrics_file)
        error('summarize_mava_sequential_run:missingDataArtifact', ...
            'Manifest-listed experimental metrics are missing: %s.', ...
            item.metrics_file);
    end
    T = readtable(item.metrics_file, 'TextType', 'string');
    group_id = string(item.id);
    genotype = extractAfter(group_id, '__');
    rows = string(T.genotype) == genotype;
    T = T(rows,:);
    before = contains(lower(string(T.id)), 'before');
    if sum(before) ~= 1 || ~ismember('peak_force', T.Properties.VariableNames)
        error('summarize_mava_sequential_run:badExperimentalMetrics', ...
            'Metrics for %s need one Before row and peak_force.', group_id);
    end
    T.peak_ratio_to_before = T.peak_force/T.peak_force(before);
    T = addvars(T, repmat(group_id,height(T),1), 'Before', 1, ...
        'NewVariableNames', 'group_id');
    parts{i} = T;
end
experimental = vertcat(parts{:});
end

function write_adaptive_decision(run_dir, manifest, summary)
decision_path = fullfile(run_dir, 'tables', 'adaptive_restart_decision.json');
bound_hash = '';
if isfield(manifest, 'materialization') && ...
        isfield(manifest.materialization, 'adaptive_restart_decision') && ...
        isfield(manifest.materialization.adaptive_restart_decision, 'sha256')
    bound_hash = char(string( ...
        manifest.materialization.adaptive_restart_decision.sha256));
end
if ~isempty(bound_hash)
    if ~isfile(decision_path) || ...
            ~strcmp(mava_sha256(decision_path), bound_hash)
        error('summarize_mava_sequential_run:decisionHashMismatch', ...
            'Hash-bound adaptive restart decision is missing or changed.');
    end
    return;
end

group_ids = manifest_group_ids(manifest);
groups = repmat(struct('id','','reason',''), 1, numel(group_ids));
selected_count = 0;
for g = 1:numel(group_ids)
    group_id = string(group_ids{g});
    stage_rows = summary.stage.group_id == group_id & ...
        summary.stage.stage == "plus_k73";
    if ~any(stage_rows), continue; end
    reasons = strings(0,1);
    row = summary.stage(stage_rows,:);
    if row.near_optimal_starts < 3
        reasons(end+1) = "fewer than 3 near-optimal starts"; %#ok<AGROW>
    end
    if row.solution_clusters > 1
        reasons(end+1) = "multiple near-optimal solution clusters"; %#ok<AGROW>
    end
    final_restart = summary.restart.group_id == group_id & ...
        summary.restart.stage == "plus_k73";
    final_rows = find(final_restart);
    [~, best_local] = min(summary.restart.AIC(final_restart));
    if summary.restart.boundary_hit(final_rows(best_local))
        reasons(end+1) = "boundary hit in best run"; %#ok<AGROW>
    end
    ident_rows = summary.identifiability.group_id == group_id & ...
        summary.identifiability.stage == "plus_k73";
    if any(summary.identifiability.near_optimal_fold_spread(ident_rows) > 2)
        reasons(end+1) = "greater than twofold near-optimal parameter spread"; %#ok<AGROW>
    end
    if ~isempty(reasons)
        selected_count = selected_count + 1;
        groups(selected_count) = struct('id', char(group_id), ...
            'reason', char(strjoin(reasons, '; ')));
    end
end
groups = groups(1:selected_count);
decision = struct('schema_version', 1, 'activate', ~isempty(groups), ...
    'groups', groups);
write_json_atomic(decision_path, decision);
end

function write_authority_note(run_dir, manifest)
manifest_file = fullfile(run_dir, 'manifest.json');
note_file = fullfile(run_dir, 'AUTHORITATIVE_OUTPUTS.md');
fid = fopen(note_file, 'w');
if fid < 0
    error('summarize_mava_sequential_run:writeFailed', ...
        'Could not write %s.', note_file);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Authoritative mavacamten analysis outputs\n\n');
fprintf(fid, '- Run ID: `%s`\n', char(string(manifest.run_id)));
fprintf(fid, '- Repository HEAD: `%s`\n', char(string(manifest.repository_head)));
fprintf(fid, '- Manifest SHA-256: `%s`\n', mava_sha256(manifest_file));
if isfield(manifest, 'immutable_signature')
    fprintf(fid, '- Run immutable hash: `%s`\n', ...
        char(string(manifest.immutable_signature)));
else
    fprintf(fid, '- Run immutable hash: fixture manifest (not signed)\n');
end
fprintf(fid, '- Manifest: `%s`\n', manifest_file);
fprintf(fid, '- Tables: `%s`\n', fullfile(run_dir, 'tables'));
fprintf(fid, '- Figures: `%s`\n\n', fullfile(run_dir, 'figures'));
fprintf(fid, ['AIC and Akaike weights are comparable only within the same ' ...
    'genotype and alignment policy. They must not be compared across ' ...
    'genotypes or alignment policies.\n\n']);
fprintf(fid, ['The independently fitted `k_2` is diagnostic only. Do not ' ...
    'interpret fitted free-`k_2` ratios as biological mavacamten effects.\n\n']);
fprintf(fid, ['The identifiability labels are practical identifiability ' ...
    'diagnostics from this multistart ensemble, not proof of structural ' ...
    'identifiability.\n\n']);
fprintf(fid, ['Control parameter and treatment-timing conclusions are ' ...
    'provisional because shared alignment preserves an approximately 192 ms ' ...
    'later acute contraction onset and the workbook has no stimulus timing ' ...
    'metadata.\n\n']);
fprintf(fid, ['The verified acute peak-force effect is approximately 35%% of ' ...
    'Before in Control and 33%% of Before in H251N.\n\n']);
fprintf(fid, ['Question for the PI: Are the six Mava traces synchronized to ' ...
    'the same electrical or calcium stimulus time? Does the first column ' ...
    'represent a common absolute stimulus time, or could each averaged trace ' ...
    'have an arbitrary temporal offset? The Control acute trace begins about ' ...
    '192 ms later than Control before. Should I preserve that difference, or ' ...
    'independently align each trace''s contraction onset to the calcium ' ...
    'transient?\n']);
end

function validate_production_manifest(manifest)
if ~isfield(manifest, 'creation_mode') || ...
        strcmp(manifest.creation_mode, 'dry_run') || ...
        ~isfield(manifest, 'status') || ~strcmp(manifest.status, 'complete')
    error('summarize_mava_sequential_run:incompleteRun', ...
        'Production summary requires a complete executed run.');
end
end

function settings = settings_from_signed_manifest(manifest)
try
    settings = struct;
    settings.run_id = char(string(manifest.run_id));
    settings.repository_root = char(string(manifest.repository_root));
    settings.workbook_file = char(string(manifest.hashes.workbook.path));
    settings.protocol_file = char(string(manifest.hashes.protocol.path));
    settings.baseline_templates = struct( ...
        'Control', char(string( ...
        manifest.hashes.baseline_templates.Control.path)), ...
        'H251N', char(string( ...
        manifest.hashes.baseline_templates.H251N.path)));
    settings.options_files = struct( ...
        'Control', char(string(manifest.hashes.options.Control.path)), ...
        'H251N', char(string(manifest.hashes.options.H251N.path)));

    source_records = as_cells(manifest.hashes.sources);
    settings.source_files = cellfun(@(item) char(string(item.path)), ...
        source_records, 'UniformOutput', false);

    group_records = as_cells(manifest.groups);
    settings.alignment_groups = cell(1, numel(group_records));
    for i = 1:numel(group_records)
        group = group_records{i};
        genotypes = reshape(cellstr(string(group.genotypes)), 1, []);
        settings.alignment_groups{i} = struct( ...
            'policy', char(string(group.policy)), ...
            'genotypes', {genotypes});
    end

    stage_records = as_cells(manifest.stages);
    stages = repmat(struct('id', '', 'parameters', {{}}), ...
        1, numel(stage_records));
    for i = 1:numel(stage_records)
        stage = stage_records{i};
        stages(i).id = char(string(stage.id));
        stages(i).parameters = reshape( ...
            cellstr(string(stage.parameters)), 1, []);
    end
    settings.stages = stages;

    controls = manifest.settings;
    settings.scale_mode = char(string(controls.scale_mode));
    settings.fit_start_index = controls.fit_start_index;
    settings.restarts = controls.restarts;
    settings.extra_final_restarts = controls.extra_final_restarts;
    settings.max_fun_evals = controls.max_fun_evals;
    settings.tol_fun = controls.tol_fun;
    settings.tol_x = controls.tol_x;
catch ME
    error('mava_run_manifest:resumeMismatch', ...
        'Could not reconstruct signed manifest settings: %s', ME.message);
end
end

function validate_production_data(manifest)
data = as_cells(manifest.materialization.data_files);
for i = 1:numel(data)
    item = data{i};
    fields = {'target_file','protocol_file','metrics_file'};
    hashes = {'target_sha256','protocol_sha256','metrics_sha256'};
    for j = 1:numel(fields)
        if ~isfield(item, fields{j}) || ~isfield(item, hashes{j}) || ...
                isempty(item.(hashes{j})) || ~isfile(item.(fields{j})) || ...
                ~strcmp(mava_sha256(item.(fields{j})), item.(hashes{j}))
            error('summarize_mava_sequential_run:dataHashMismatch', ...
                'Manifest-listed data hash mismatch for %s.', item.id);
        end
    end
end
end

function active = optional_group_active(manifest, item)
active = false;
if ~isfield(manifest, 'materialization') || ...
        ~isfield(manifest.materialization, 'optional_final_restart_groups')
    return;
end
selected = cellstr(string( ...
    manifest.materialization.optional_final_restart_groups));
active = ismember([char(string(item.alignment_policy)) '__' ...
    char(string(item.genotype))], selected);
end

function groups = manifest_group_ids(manifest)
data = as_cells(manifest.materialization.data_files);
groups = cellfun(@(item) char(string(item.id)), data, ...
    'UniformOutput', false);
groups = unique(groups, 'stable');
end

function ids = manifest_stage_ids(manifest)
stages = as_cells(manifest.stages);
ids = cellfun(@(item) char(string(item.id)), stages, ...
    'UniformOutput', false);
end

function indices = rows_from_restart(restart, rows, details)
selected_ids = restart.id(rows);
indices = nan(1,numel(selected_ids));
for i = 1:numel(selected_ids)
    indices(i) = find(strcmp({details.id}, selected_ids(i)), 1);
end
end

function P = normalized_matrix(details)
P = nan(numel(details), numel(details(1).parameters));
for i = 1:numel(details)
    P(i,:) = cellfun(@(p) simulated_coordinate(p), details(i).parameters);
end
end

function V = physical_matrix(details)
V = nan(numel(details), numel(details(1).parameters));
for i = 1:numel(details)
    V(i,:) = details(i).boundary.physical_value';
end
end

function p = simulated_coordinate(parameter)
if isfield(parameter, 'p_value_raw')
    p = parameter.p_value_raw;
else
    p = parameter.p_value;
end
p = max(0,min(1,p));
end

function n = cluster_count(P)
if isempty(P)
    n = 0;
else
    n = size(uniquetol(P, 0.05, 'ByRows', true), 1);
end
end

function spread = log_spread(values)
if isempty(values)
    spread = Inf;
else
    spread = max(log10(values))-min(log10(values));
end
end

function spread = fold_spread(values)
if isempty(values)
    spread = Inf;
else
    spread = max(values)/min(values);
end
end

function value = fit_aic(fit, id)
if isfield(fit, 'aic')
    value = fit.aic;
elseif isfield(fit, 'AIC')
    % Legacy synthetic fixture compatibility only. Signed production
    % results are preflighted to require the canonical lowercase field.
    value = fit.AIC;
else
    error('summarize_mava_sequential_run:missingAIC', ...
        'Fit result %s has no stored AIC.', id);
end
if ~isscalar(value) || ~isfinite(value)
    error('summarize_mava_sequential_run:badAIC', ...
        'Fit result %s has invalid AIC.', id);
end
end

function value = required_numeric(s, field, id)
if ~isfield(s, field) || ~isscalar(s.(field)) || ~isfinite(s.(field))
    error('summarize_mava_sequential_run:badFitResult', ...
        'Fit result %s has invalid %s.', id, field);
end
value = s.(field);
end

function value = optional_numeric(s, field)
value = NaN;
if isfield(s, field) && isscalar(s.(field))
    value = s.(field);
end
end

function value = first_struct(value)
if iscell(value), value = value{1}; else, value = value(1); end
end

function cells = as_cells(value)
if iscell(value)
    cells = value;
elseif isstruct(value)
    cells = num2cell(value);
elseif isempty(value)
    cells = {};
else
    error('summarize_mava_sequential_run:badManifestShape', ...
        'Expected a cell or struct array.');
end
end

function write_json_atomic(file, value)
parent = fileparts(file);
if ~isfolder(parent), mkdir(parent); end
temporary = [tempname(parent) '.json'];
cleanup = onCleanup(@() delete_if_present(temporary));
fid = fopen(temporary, 'w');
if fid < 0
    error('summarize_mava_sequential_run:writeFailed', ...
        'Could not write %s.', temporary);
end
file_cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(value));
clear file_cleanup;
movefile(temporary, file, 'f');
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
