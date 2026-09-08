function config_files = build_mava_free_k2_fit_configs(out_dir, max_fun_evals, restarts)
% Build acute Mava fits with k_1, k_2, and k_3 independently free.

if nargin < 2 || isempty(max_fun_evals), max_fun_evals = 400; end
if nargin < 3 || isempty(restarts), restarts = 1; end
script_dir = fileparts(mfilename('fullpath'));
fitting_dir = fileparts(script_dir);
if ~isfolder(out_dir), mkdir(out_dir); end

cases = struct('id', {'ctrl','hcm'}, ...
    'demo', {'twitch_6state_control','twitch_6state_HCM'}, ...
    'target', {'ctrl_acute','hcm_acute'});
free_names = {'k_1','k_2','k_3'};
config_files = cell(1, numel(cases)*restarts);
counter = 0;

for c = 1:numel(cases)
    demo_dir = fullfile(fitting_dir, cases(c).demo);
    template = fullfile(demo_dir, 'temp', 'best', 'model_best.json');
    options = fullfile(demo_dir, 'sim_input', 'sim_options.json');
    base = loadjson(template);
    parameters = base.MyoSim_model.hs_props.parameters;
    for restart = 1:restarts
        counter = counter + 1;
        run_id = sprintf('%s_acute_free_k2_s%02d', cases(c).id, restart);
        result_dir = fullfile(out_dir, 'results', run_id);
        if ~isfolder(result_dir), mkdir(result_dir); end

        opt = struct;
        opt.model_template_file_string = template;
        opt.fit_mode = 'fit_in_time_domain';
        opt.fit_variable = 'muscle_force';
        opt.best_model_folder = result_dir;
        opt.best_opt_file_string = fullfile(result_dir, 'best_optimization.json');
        opt.figure_current_fit = 0;
        opt.figure_optimization_progress = 0;
        opt.max_fun_evals = max_fun_evals;
        opt.tol_fun = 1e-5;
        opt.tol_x = 1e-3;
        opt.job = {struct( ...
            'model_file_string', fullfile(result_dir, 'model_worker.json'), ...
            'protocol_file_string', fullfile(out_dir, 'data', ...
                [cases(c).target '_protocol.txt']), ...
            'options_file_string', options, ...
            'results_file_string', fullfile(result_dir, 'twitch.myo'), ...
            'fit_start_index', 481, ...
            'target_file_string', fullfile(out_dir, 'data', ...
                [cases(c).target '_target.txt']))};

        opt.parameter = cell(1, numel(free_names));
        for p = 1:numel(free_names)
            name = free_names{p};
            value = parameters.(name);
            opt.parameter{p} = struct('name', name, ...
                'min_value', log10(value)-1, ...
                'max_value', log10(value)+1, ...
                'p_value', 0.5, 'p_mode', 'log');
        end

        config_file = fullfile(out_dir, [run_id '_optimization.json']);
        fid = fopen(config_file, 'w');
        if fid < 0, error('Could not write %s.', config_file); end
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        fprintf(fid, '%s', savejson('MyoSim_optimization', opt));
        clear cleanup;
        config_files{counter} = config_file;
    end
end
end
