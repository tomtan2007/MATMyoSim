function result = mava_feature_parameter_screen(out_dir, varargin)
% Screen 6-state parameters by their trace-specific twitch-feature signatures.
%
% The screen changes one parameter at a time around each condition's current
% baseline model.  It is a selection screen, not a parameter fit: a candidate
% must produce a measurable primary-feature effect while retaining valid model
% behavior before it can enter a later joint optimization stage.

p = inputParser;
addParameter(p, 'WorkbookFile', '');
addParameter(p, 'AlignmentPolicy', 'independent_trace');
addParameter(p, 'FoldLevels', [0.5 0.75 1 1.25 2]);
addParameter(p, 'ParameterNames', {});
addParameter(p, 'K2K1Ratio', 10);
addParameter(p, 'EffectThreshold', 1);
addParameter(p, 'CorrelationThreshold', 0.85);
parse(p, varargin{:});
settings = p.Results;

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
if nargin < 1 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output', 'feature_parameter_screen');
end
if ~isfolder(out_dir), mkdir(out_dir); end
if isempty(settings.WorkbookFile)
    settings.WorkbookFile = fullfile(repo_root, 'Code', 'System', ...
        'experimental_data', 'Mava data.xlsx');
end
if ~isfile(settings.WorkbookFile)
    error('mava_feature_parameter_screen:missingWorkbook', ...
        'Workbook not found: %s.', settings.WorkbookFile);
end
if ~ismember(char(string(settings.AlignmentPolicy)), ...
        {'independent_trace', 'shared_by_genotype'})
    error('mava_feature_parameter_screen:badAlignment', ...
        'AlignmentPolicy must be independent_trace or shared_by_genotype.');
end
levels = unique(settings.FoldLevels(:)');
if numel(levels) < 3 || any(~isfinite(levels) | levels <= 0) || ...
        ~any(abs(levels-1) < eps)
    error('mava_feature_parameter_screen:badLevels', ...
        'FoldLevels must include positive values and exactly include 1.');
end

if isempty(settings.ParameterNames)
    settings.ParameterNames = {'k_1','k_3','k_5_0','k_4_0', ...
        'k_7_1','k_7_2','k_7_3'};
end
parameter_names = cellstr(string(settings.ParameterNames));
for i = 1:numel(parameter_names)
    if strcmp(parameter_names{i}, 'k_2') || startsWith(parameter_names{i}, 'k_9') || ...
            ismember(parameter_names{i}, {'k_10','k_11','k_12','k_13','k_14','k_force'})
        error('mava_feature_parameter_screen:heldParameter', ...
            '%s is held fixed in the initial feature screen.', parameter_names{i});
    end
end

data_dir = fullfile(out_dir, 'data', char(string(settings.AlignmentPolicy)));
prepare_mava_data(settings.WorkbookFile, data_dir, 'peak', ...
    char(string(settings.AlignmentPolicy)));

cases = struct('genotype', {'Control','H251N'}, ...
    'target_id', {'ctrl_acute','hcm_acute'}, ...
    'demo', {'twitch_6state_control','twitch_6state_HCM'});
responses = table;
for case_idx = 1:numel(cases)
    case_info = cases(case_idx);
    demo_dir = fullfile(repo_root, 'Code', 'Fitting', case_info.demo);
    base_file = fullfile(demo_dir, 'temp', 'best', 'model_best.json');
    options_file = fullfile(demo_dir, 'sim_input', 'sim_options.json');
    base = loadjson(base_file);
    base_parameters = base.MyoSim_model.hs_props.parameters;
    protocol_file = fullfile(data_dir, [case_info.target_id '_protocol.txt']);
    target = load(fullfile(data_dir, [case_info.target_id '_target.txt']));
    protocol = readtable(protocol_file, 'FileType', 'text', 'Delimiter', '\t');
    t = cumsum(protocol.dt) - protocol.dt(1);
    onset_idx = find(protocol.pCa < 6.70, 1, 'first');
    baseline_indices = max(1, onset_idx-50):(onset_idx-1);
    target_metrics = mava_feature_metrics(t, target, ...
        'ReferenceOnsetTime', t(onset_idx), ...
        'BaselineIndices', baseline_indices);
    [primary_names, primary_scales] = primary_feature_spec(target_metrics);
    validation_names = validation_feature_names();
    model_file = fullfile(out_dir, 'work', char( ...
        lower(string(case_info.genotype)) + "_screen_model.json"));

    for parameter_idx = 1:numel(parameter_names)
        parameter_name = parameter_names{parameter_idx};
        if ~isfield(base_parameters, parameter_name)
            error('mava_feature_parameter_screen:unknownParameter', ...
                '%s is not in %s.', parameter_name, base_file);
        end
        baseline_value = base_parameters.(parameter_name);
        for level_idx = 1:numel(levels)
            fold = levels(level_idx);
            model = base;
            parameters = model.MyoSim_model.hs_props.parameters;
            parameters.(parameter_name) = baseline_value * fold;
            parameters.k_2 = settings.K2K1Ratio * parameters.k_1;
            model.MyoSim_model.hs_props.parameters = parameters;
            write_model(model, model_file);

            valid = true;
            model_metrics = empty_metrics(target_metrics);
            try
                sim = simulation_driver( ...
                    'model_json_file_string', model_file, ...
                    'simulation_protocol_file_string', protocol_file, ...
                    'options_json_file_string', options_file);
                model_force = align_time_fit_baseline( ...
                    sim.muscle_force(end-numel(target)+1:end), target, onset_idx);
                model_metrics = mava_feature_metrics(t, model_force, ...
                    'ReferenceOnsetTime', t(onset_idx), ...
                    'BaselineIndices', baseline_indices);
                valid = all(isfinite([model_metrics.peak_amplitude, ...
                    model_metrics.time_to_peak, model_metrics.duration_above_50])) && ...
                    model_metrics.peak_amplitude > 0;
            catch
                valid = false;
            end

            responses = append_features(responses, case_info.genotype, ...
                parameter_name, fold, valid, target_metrics, model_metrics, ...
                primary_names, primary_scales, validation_names); %#ok<AGROW>
        end
    end
end

summary = summarize_parameter_effects(responses, parameter_names, ...
    settings.EffectThreshold);
correlations = signature_correlations(responses, parameter_names, ...
    settings.CorrelationThreshold);
recommendations = recommend_stages(summary, correlations, parameter_names, ...
    settings.EffectThreshold, settings.CorrelationThreshold);
writetable(responses, fullfile(out_dir, 'feature_responses.csv'));
writetable(summary, fullfile(out_dir, 'parameter_screen_summary.csv'));
writetable(correlations, fullfile(out_dir, 'signature_correlations.csv'));
writetable(recommendations, fullfile(out_dir, 'stage_recommendations.csv'));
result = struct('responses', responses, 'summary', summary, ...
    'correlations', correlations, 'recommendations', recommendations, ...
    'settings', settings);
end

function [names, scales] = primary_feature_spec(metrics)
spec = mava_default_feature_spec(metrics);
names = string({spec.name})';
scales = [spec.scale]';
end

function names = validation_feature_names()
names = ["rise_50_to_90"; "duration_above_90"; ...
    "relaxation_to_rise_auc_ratio"; "max_force_rate"; "min_force_rate"];
end

function metrics = empty_metrics(reference)
metrics = reference;
fields = fieldnames(metrics);
for i = 1:numel(fields)
    if isnumeric(metrics.(fields{i})) && isscalar(metrics.(fields{i}))
        metrics.(fields{i}) = NaN;
    end
end
end

function T = append_features(T, genotype, parameter, fold, valid, target, ...
        model, primary_names, primary_scales, validation_names)
all_names = [primary_names; validation_names];
for i = 1:numel(all_names)
    name = char(all_names(i));
    is_primary = i <= numel(primary_names);
    target_value = target.(name);
    model_value = model.(name);
    if is_primary
        scale = primary_scales(i);
    else
        scale = validation_scale(target_value, name);
    end
    if valid && isfinite(target_value) && isfinite(model_value) && ...
            isfinite(scale) && scale > 0
        standardized_delta = (model_value-target_value)/scale;
    else
        standardized_delta = NaN;
    end
    row = table(string(genotype), string(parameter), fold, string(name), ...
        is_primary, valid, target_value, model_value, scale, standardized_delta, ...
        'VariableNames', {'genotype','parameter','fold','feature', ...
        'is_primary','valid','target_value','model_value','scale', ...
        'standardized_delta'});
    T = [T; row]; %#ok<AGROW>
end
end

function scale = validation_scale(value, name)
if ~isfinite(value)
    scale = NaN;
elseif contains(name, 'rate')
    scale = max(0.10*abs(value), eps);
elseif contains(name, 'ratio')
    scale = max(0.10*abs(value), 0.10);
else
    scale = max(0.10*abs(value), 0.0321);
end
end

function summary = summarize_parameter_effects(responses, parameter_names, threshold)
summary = table;
genotypes = unique(responses.genotype, 'stable');
for g = 1:numel(genotypes)
    for p = 1:numel(parameter_names)
        idx = responses.genotype == genotypes(g) & ...
            responses.parameter == string(parameter_names{p});
        D = responses(idx,:);
        all_valid = all(D.valid);
        primary = D(D.is_primary & D.fold ~= 1 & isfinite(D.standardized_delta), :);
        if isempty(primary)
            max_effect = NaN;
            n_distinct = 0;
        else
            max_effect = max(abs(primary.standardized_delta));
            n_distinct = numel(unique(primary.feature( ...
                abs(primary.standardized_delta) >= threshold)));
        end
        eligible = all_valid && n_distinct >= 1;
        row = table(genotypes(g), string(parameter_names{p}), all_valid, ...
            max_effect, n_distinct, eligible, ...
            'VariableNames', {'genotype','parameter','all_folds_valid', ...
            'max_primary_effect','n_primary_features_over_threshold', ...
            'eligible'});
        summary = [summary; row]; %#ok<AGROW>
    end
end
end

function correlations = signature_correlations(responses, parameter_names, threshold)
correlations = table;
genotypes = unique(responses.genotype, 'stable');
for g = 1:numel(genotypes)
    for a = 1:numel(parameter_names)-1
        for b = a+1:numel(parameter_names)
            va = endpoint_signature(responses, genotypes(g), parameter_names{a});
            vb = endpoint_signature(responses, genotypes(g), parameter_names{b});
            finite = isfinite(va) & isfinite(vb);
            if nnz(finite) >= 3 && std(va(finite)) > 0 && std(vb(finite)) > 0
                r = corr(va(finite), vb(finite));
            else
                r = NaN;
            end
            row = table(genotypes(g), string(parameter_names{a}), ...
                string(parameter_names{b}), r, isfinite(r) && abs(r) >= threshold, ...
                'VariableNames', {'genotype','parameter_a','parameter_b', ...
                'signature_correlation','redundant'});
            correlations = [correlations; row]; %#ok<AGROW>
        end
    end
end
end

function values = endpoint_signature(responses, genotype, parameter)
D = responses(responses.genotype == genotype & ...
    responses.parameter == string(parameter) & responses.is_primary, :);
features = unique(D.feature, 'stable');
values = nan(numel(features), 1);
for i = 1:numel(features)
    E = D(D.feature == features(i), :);
    low = E(abs(E.fold-min(E.fold)) < eps, :);
    high = E(abs(E.fold-max(E.fold)) < eps, :);
    if ~isempty(low) && ~isempty(high)
        values(i) = high.standardized_delta(1) - low.standardized_delta(1);
    end
end
end

function recommendations = recommend_stages(summary, correlations, names, threshold, correlation_threshold)
base = ["k_1"; "k_3"; "k_5_0"];
recommendations = table;
for genotype = unique(summary.genotype, 'stable')'
    for stage = 1:2
        if stage == 1
            parameter = strjoin(base, ',');
            decision = "start";
            reason = "Minimal thick-filament/crossbridge stage";
        else
            row = summary(summary.genotype == genotype & ...
                summary.parameter == "k_4_0", :);
            parameter = "k_4_0";
            if row.eligible && row.max_primary_effect >= threshold
                decision = "screen_after_base";
                reason = "Candidate for width/plateau/relaxation residuals";
            else
                decision = "hold";
                reason = "No measurable valid primary-feature signature";
            end
        end
        recommendations = [recommendations; table(genotype, stage, parameter, ...
            decision, reason, 'VariableNames', {'genotype','stage', ...
            'parameter','decision','reason'})]; %#ok<AGROW>
    end

    k7 = summary(summary.genotype == genotype & ...
        ismember(summary.parameter, ["k_7_1","k_7_2","k_7_3"]) & ...
        summary.eligible, :);
    if isempty(k7)
        choice = "none";
        decision = "hold";
        reason = "No valid measurable k_7-family signature";
    else
        [~, order] = sort(k7.max_primary_effect, 'descend');
        choice = "none";
        for i = 1:numel(order)
            candidate = k7.parameter(order(i));
            pair = correlations(correlations.genotype == genotype & ...
                (correlations.parameter_a == candidate | ...
                 correlations.parameter_b == candidate), :);
            if ~any(pair.redundant & abs(pair.signature_correlation) >= correlation_threshold)
                choice = candidate;
                break;
            end
        end
        if choice == "none"
            decision = "hold";
            reason = "All measurable k_7 candidates are signature-redundant";
        else
            decision = "screen_after_k4";
            reason = "Most distinct eligible k_7-family signature";
        end
    end
    recommendations = [recommendations; table(genotype, 3, choice, decision, ...
        reason, 'VariableNames', {'genotype','stage','parameter','decision','reason'})]; %#ok<AGROW>
end

shared = ["k_on"; "k_off"; "k_coop"];
for parameter = shared'
    recommendations = [recommendations; table("both", 4, parameter, ...
        "hold_shared", "Screen only after persistent onset/rise residuals", ...
        'VariableNames', {'genotype','stage','parameter','decision','reason'})]; %#ok<AGROW>
end
recommendations = [recommendations; table("both", 5, "k_force", ...
    "hold", "Requires force-length or load-dependent data", ...
    'VariableNames', {'genotype','stage','parameter','decision','reason'})];
end

function write_model(model, file)
folder = fileparts(file);
if ~isfolder(folder), mkdir(folder); end
fid = fopen(file, 'w');
if fid < 0
    error('mava_feature_parameter_screen:writeModel', ...
        'Could not write %s.', file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('MyoSim_model', model.MyoSim_model, ...
    'FloatFormat', '%.17g'));
end
