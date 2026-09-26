function [config_file, record] = build_mava_joint_feature_fit_config( ...
        run_dir, stage_parameters, settings)
% Build a trace-specific, two-condition feature-fit configuration.
%
% Kinetic parameters supplied in stage_parameters are condition-specific.
% Thin-filament parameters can be supplied in settings.shared_parameters and
% are then written identically to both jobs.

if nargin < 3 || isempty(settings), settings = struct; end
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
run_dir = char(string(run_dir));
stage_parameters = cellstr(string(stage_parameters));
if ~isfield(settings, 'shared_parameters')
    settings.shared_parameters = {};
end
shared_parameters = cellstr(string(settings.shared_parameters));
if ~isfield(settings, 'fixed_shared_parameters')
    settings.fixed_shared_parameters = {'k_on','k_off','k_coop'};
end
fixed_shared_parameters = cellstr(string(settings.fixed_shared_parameters));
if any(strcmp([stage_parameters shared_parameters], 'k_2'))
    error('build_mava_joint_feature_fit_config:k2Fixed', ...
        'k_2 is constrained to k_1 and cannot be free.');
end
if any(ismember(stage_parameters, {'k_force','k_9','k_10','k_11','k_12','k_13','k_14'}))
    error('build_mava_joint_feature_fit_config:heldParameter', ...
        'Structural and force-feedback parameters are held in the initial stages.');
end
if any(ismember(fixed_shared_parameters, [stage_parameters shared_parameters]))
    error('build_mava_joint_feature_fit_config:sharedParameterConflict', ...
        'A fixed shared parameter cannot also be free.');
end

alignment = 'independent_trace';
data_dir = fullfile(run_dir, 'data', alignment);
prepare_mava_data([], data_dir, 'peak', alignment);
fit_start_index = mava_reference_onset_index( ...
    fullfile(data_dir, 'ctrl_acute_protocol.txt'));
cases = struct('name', {'Control','H251N'}, 'id', {'ctrl_acute','hcm_acute'}, ...
    'demo', {'twitch_6state_control','twitch_6state_HCM'});
opt = struct;
opt.fit_mode = 'fit_twitch_features';
opt.fit_variable = 'muscle_force';
opt.figure_current_fit = 0;
opt.figure_optimization_progress = 0;
opt.max_fun_evals = setting_or(settings, 'max_fun_evals', 100);
opt.tol_fun = setting_or(settings, 'tol_fun', 1e-4);
opt.tol_x = setting_or(settings, 'tol_x', 1e-3);
opt.k_2_k_1_ratio = setting_or(settings, 'k_2_k_1_ratio', 10);
result_dir = fullfile(run_dir, 'results', 'joint_feature_fit');
opt.best_model_folder = result_dir;
opt.best_opt_file_string = fullfile(result_dir, 'best_optimization.json');
opt.job = cell(1, numel(cases));
opt.model_working_file_string = cell(1, numel(cases));
opt.best_model_file_string = cell(1, numel(cases));
base_parameters = cell(1, numel(cases));
for j = 1:numel(cases)
    demo_dir = fullfile(repo_root, 'Code', 'Fitting', cases(j).demo);
    template = fullfile(demo_dir, 'temp', 'best', 'model_best.json');
    base = loadjson(template);
    base_parameters{j} = base.MyoSim_model.hs_props.parameters;
    opt.job{j} = struct('model_template_file_string', template, ...
        'model_file_string', fullfile(result_dir, [lower(cases(j).name) '_worker.json']), ...
        'protocol_file_string', fullfile(data_dir, [cases(j).id '_protocol.txt']), ...
        'options_file_string', fullfile(demo_dir, 'sim_input', 'sim_options.json'), ...
        'results_file_string', fullfile(result_dir, [lower(cases(j).name) '.myo']), ...
        'target_file_string', fullfile(data_dir, [cases(j).id '_target.txt']), ...
        'fit_start_index', fit_start_index);
    opt.model_working_file_string{j} = opt.job{j}.model_file_string;
    opt.best_model_file_string{j} = fullfile(result_dir, ...
        [lower(cases(j).name) '_best.json']);
end

% The thin-filament parameters are deliberately identical across conditions
% in the initial kinetic screen. Use Control's template values as the common
% baseline; they are not fit until a later, explicitly approved stage.
opt.fixed_parameter = {};
for i = 1:numel(fixed_shared_parameters)
    name = fixed_shared_parameters{i};
    assert_present(base_parameters{1}, name);
    assert_present(base_parameters{2}, name);
    opt.fixed_parameter{end+1} = struct('name', name, ...
        'value', base_parameters{1}.(name)); %#ok<AGROW>
end

opt.parameter = {};
for i = 1:numel(shared_parameters)
    name = shared_parameters{i};
    assert_present(base_parameters{1}, name);
    assert_present(base_parameters{2}, name);
    opt.parameter{end+1} = parameter_spec(name, base_parameters{1}.(name)); %#ok<AGROW>
end
for i = 1:numel(stage_parameters)
    name = stage_parameters{i};
    for j = 1:numel(cases)
        assert_present(base_parameters{j}, name);
        entry = parameter_spec([name '_' lower(cases(j).name)], ...
            base_parameters{j}.(name));
        entry.target_name = name;
        entry.job = j;
        opt.parameter{end+1} = entry; %#ok<AGROW>
    end
end

if isfield(settings, 'start_vector') && ~isempty(settings.start_vector)
    start_vector = settings.start_vector(:)';
    if numel(start_vector) ~= numel(opt.parameter) || ...
            any(~isfinite(start_vector)) || any(start_vector < 0) || ...
            any(start_vector > 1)
        error('build_mava_joint_feature_fit_config:badStartVector', ...
            'start_vector must contain one normalized value in [0,1] per free parameter.');
    end
    for i = 1:numel(opt.parameter)
        opt.parameter{i}.p_value = start_vector(i);
    end
end

if ~isfolder(result_dir), mkdir(result_dir); end
config_file = fullfile(run_dir, 'joint_feature_optimization.json');
fid = fopen(config_file, 'w');
if fid < 0
    error('build_mava_joint_feature_fit_config:writeFailed', ...
        'Could not write %s.', config_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('MyoSim_optimization', opt, ...
    'FloatFormat', '%.17g'));
record = struct('config_file', config_file, 'result_dir', result_dir, ...
    'alignment_policy', alignment, 'condition_specific_parameters', ...
    {stage_parameters}, 'shared_parameters', {shared_parameters}, ...
    'n_free_params', numel(opt.parameter));
end

function value = setting_or(settings, name, default)
if isfield(settings, name), value = settings.(name); else, value = default; end
end

function entry = parameter_spec(name, baseline)
entry = struct('name', name, 'min_value', log10(baseline)-1, ...
    'max_value', log10(baseline)+1, 'p_value', 0.5, 'p_mode', 'log');
end

function assert_present(parameters, name)
if ~isfield(parameters, name)
    error('build_mava_joint_feature_fit_config:unknownParameter', ...
        'Parameter %s is absent from the selected template.', name);
end
end
