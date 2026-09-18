function [config_file, record] = build_non_mava_joint_config( ...
        restart_dir, stage_parameters, settings)
% Build one two-condition non-Mava feature-fit configuration.
if nargin < 3, settings = struct; end
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
addpath(genpath(repo_root));
stage_parameters = cellstr(string(stage_parameters));
if any(strcmp(stage_parameters, 'k_2'))
    error('build_non_mava_joint_config:k2Tied', ...
        'k_2 is tied to 10*k_1 and cannot be free.');
end
if ~isfolder(restart_dir), mkdir(restart_dir); end
data_dir = fullfile(restart_dir, 'data');
prepare_non_mava_feature_data(data_dir);
result_dir = fullfile(restart_dir, 'results', 'joint_feature_fit');
if ~isfolder(result_dir), mkdir(result_dir); end

demo_names = {'twitch_6state_control','twitch_6state_HCM'};
labels = {'control','h251n'};
targets = {'control_target.txt','h251n_target.txt'};
base = cell(1,2);
for j = 1:2
    source = fullfile(repo_root, 'Code', 'Fitting', demo_names{j}, ...
        'temp', 'best', 'model_best.json');
    base{j} = loadjson(source);
end
% Hold thin-filament kinetics identical at the Control baseline.
thin = {'k_on','k_off','k_coop'};
for j = 1:2
    for i = 1:numel(thin)
        base{j}.MyoSim_model.hs_props.parameters.(thin{i}) = ...
            base{1}.MyoSim_model.hs_props.parameters.(thin{i});
    end
    template_file = fullfile(data_dir, [labels{j} '_template.json']);
    write_json(template_file, 'MyoSim_model', base{j}.MyoSim_model);
    template_files{j} = template_file; %#ok<AGROW>
end

opt = struct('fit_mode', 'fit_twitch_features', ...
    'fit_variable', 'muscle_force', 'figure_current_fit', 0, ...
    'figure_optimization_progress', 0, ...
    'max_fun_evals', setting_or(settings, 'max_fun_evals', 300), ...
    'tol_fun', 1e-4, 'tol_x', 1e-3, 'k_2_k_1_ratio', 10, ...
    'best_model_folder', result_dir, ...
    'best_opt_file_string', fullfile(result_dir, 'best_optimization.json'));
reference_idx = mava_reference_onset_index(fullfile(data_dir, 'protocol_1s.txt'));
opt.job = cell(1,2); opt.model_working_file_string = cell(1,2);
opt.best_model_file_string = cell(1,2);
for j = 1:2
    demo_dir = fullfile(repo_root, 'Code', 'Fitting', demo_names{j});
    working = fullfile(result_dir, [labels{j} '_worker.json']);
    best = fullfile(result_dir, [labels{j} '_best.json']);
    opt.job{j} = struct('model_template_file_string', template_files{j}, ...
        'model_file_string', working, ...
        'protocol_file_string', fullfile(data_dir, 'protocol_1s.txt'), ...
        'options_file_string', fullfile(demo_dir, 'sim_input', 'sim_options.json'), ...
        'results_file_string', fullfile(result_dir, [labels{j} '.myo']), ...
        'target_file_string', fullfile(data_dir, targets{j}), ...
        'fit_start_index', reference_idx);
    opt.model_working_file_string{j} = working;
    opt.best_model_file_string{j} = best;
end
opt.parameter = {};
for i = 1:numel(stage_parameters)
    name = stage_parameters{i};
    for j = 1:2
        baseline = base{j}.MyoSim_model.hs_props.parameters.(name);
        entry = struct('name', sprintf('%s_%s', name, labels{j}), ...
            'target_name', name, 'job', j, ...
            'min_value', log10(baseline)-1, ...
            'max_value', log10(baseline)+1, ...
            'p_value', 0.5, 'p_mode', 'log');
        opt.parameter{end+1} = entry; %#ok<AGROW>
    end
end
if isfield(settings, 'start_vector') && ~isempty(settings.start_vector)
    for i = 1:numel(opt.parameter)
        opt.parameter{i}.p_value = settings.start_vector(i);
    end
end
config_file = fullfile(restart_dir, 'joint_feature_optimization.json');
write_json(config_file, 'MyoSim_optimization', opt);
record = struct('result_dir', result_dir, 'n_free', numel(opt.parameter));
end

function value = setting_or(settings, name, default)
if isfield(settings, name), value = settings.(name); else, value = default; end
end

function write_json(file, root_name, value)
fid = fopen(file, 'w'); cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson(root_name, value, 'FloatFormat', '%.17g'));
end
