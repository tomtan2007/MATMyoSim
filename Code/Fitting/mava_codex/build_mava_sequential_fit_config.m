function [config_file, record] = build_mava_sequential_fit_config( ...
    run_dir, alignment, genotype, stage, restart, previous_best, settings)
% Write one deterministic nested Mava fit configuration.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
run_dir = char(string(run_dir));
alignment = char(string(alignment));
genotype = char(string(genotype));

if isstruct(stage)
    stage_id = stage.id;
    parameter_names = stage.parameters;
else
    stage_id = char(string(stage));
    stages = mava_parameter_stages();
    stage_index = find(strcmp({stages.id}, stage_id), 1);
    if isempty(stage_index)
        error('build_mava_sequential_fit_config:unknownStage', ...
            'Unknown Mava parameter stage: %s.', stage_id);
    end
    parameter_names = stages(stage_index).parameters;
end

switch genotype
    case 'Control'
        demo_name = 'twitch_6state_control';
        target_id = 'ctrl_acute';
    case 'H251N'
        demo_name = 'twitch_6state_HCM';
        target_id = 'hcm_acute';
    otherwise
        error('build_mava_sequential_fit_config:unknownGenotype', ...
            'Unknown Mava genotype: %s.', genotype);
end

demo_dir = fullfile(repo_root, 'Code', 'Fitting', demo_name);
template_file = fullfile(demo_dir, 'temp', 'best', 'model_best.json');
options_file = fullfile(demo_dir, 'sim_input', 'sim_options.json');
base = loadjson(template_file);
base_parameters = base.MyoSim_model.hs_props.parameters;

config_dir = fullfile(run_dir, 'configs');
result_dir = fullfile(run_dir, 'results', alignment, genotype, ...
    stage_id, sprintf('s%02d', restart));
if ~isfolder(config_dir), mkdir(config_dir); end
if ~isfolder(result_dir), mkdir(result_dir); end

fit_start_index = 481;
if isfield(settings, 'fit_start_index')
    fit_start_index = settings.fit_start_index;
end
optimizer_defaults = struct('max_fun_evals', 1200, 'tol_fun', 1e-5, ...
    'tol_x', 1e-3, 'figure_current_fit', 0, ...
    'figure_optimization_progress', 0);

opt = struct;
opt.model_template_file_string = template_file;
opt.fit_mode = 'fit_in_time_domain';
opt.fit_variable = 'muscle_force';
opt.best_model_folder = result_dir;
opt.best_opt_file_string = fullfile(result_dir, 'best_optimization.json');
optimizer_names = fieldnames(optimizer_defaults);
for i = 1:numel(optimizer_names)
    name = optimizer_names{i};
    opt.(name) = optimizer_defaults.(name);
    if isfield(settings, name)
        opt.(name) = settings.(name);
    end
end

data_dir = fullfile(run_dir, 'data', alignment);
opt.job = {struct( ...
    'model_file_string', fullfile(result_dir, 'model_worker.json'), ...
    'protocol_file_string', fullfile(data_dir, [target_id '_protocol.txt']), ...
    'options_file_string', options_file, ...
    'results_file_string', fullfile(result_dir, 'twitch.myo'), ...
    'fit_start_index', fit_start_index, ...
    'target_file_string', fullfile(data_dir, [target_id '_target.txt']))};

start = mava_deterministic_start(numel(parameter_names), restart, ...
    previous_best);
opt.parameter = cell(1, numel(parameter_names));
for i = 1:numel(parameter_names)
    name = parameter_names{i};
    baseline_value = base_parameters.(name);
    center = log10(baseline_value);
    opt.parameter{i} = struct('name', name, ...
        'min_value', center - 1, 'max_value', center + 1, ...
        'p_value', start(i), 'p_mode', 'log');
end

config_file = fullfile(config_dir, sprintf('%s__%s__%s__s%02d.json', ...
    alignment, genotype, stage_id, restart));
fid = fopen(config_file, 'w');
if fid < 0
    error('build_mava_sequential_fit_config:writeFailed', ...
        'Could not write %s.', config_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('MyoSim_optimization', opt, ...
    'FloatFormat', '%.17g'));
clear cleanup;

record = struct('alignment_policy', alignment, 'genotype', genotype, ...
    'stage', stage_id, 'restart', restart, 'config_file', config_file, ...
    'result_dir', result_dir, 'template_file', template_file, ...
    'target_id', target_id, 'parameter_names', {parameter_names}, ...
    'start', start);
end
