function profile_likelihood_hcm(param_name, scan_values, tag)
% Profile-likelihood scan for the reduced-parameter 6-state HCM fit.
%
% For each value in scan_values, FIXES param_name at that value (writes
% it directly into a scratch copy of the reduced model template) and
% re-optimizes every OTHER free parameter in
% twitch_6state_HCM/sim_input/optimization_reduced.json via fminsearch.
% Records the resulting best error. Plotting best_error vs the fixed
% value answers the identifiability question directly:
%   - flat/shallow curve over a wide range  => genuine structural
%     non-identifiability (the twitch data cannot distinguish these
%     values of param_name from each other, no amount of better
%     optimization will fix this)
%   - a single sharp minimum                => random-restart
%     fminsearch was just failing to find it; joint/tighter-bounds
%     fitting should eventually converge on one basin
%
% Does NOT touch temp/multistart_reduced/ (owned by the sibling
% multistart run) or any canonical temp/best/model_best.json. Uses its
% own scratch directory temp/profile_likelihood/<tag>/.
%
% Usage:
%   profile_likelihood_hcm('k_1', [0.5 1 2 5 10 20 35 50 70 100], 'k1scan')

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

demo_dir = fullfile(fileparts(mfilename('fullpath')), 'twitch_6state_HCM');
cd(demo_dir);

opt = loadjson('sim_input/optimization_reduced.json');
os0 = opt.MyoSim_optimization;
os0.figure_current_fit = 0;
os0.figure_optimization_progress = 0;

% Remove param_name from the free-parameter list (it will be fixed
% directly in the model template instead), keep everything else free.
par_names_all = cellfun(@(p) p.name, os0.parameter, 'UniformOutput', false);
fix_idx = find(strcmp(par_names_all, param_name));
if numel(fix_idx) ~= 1
    error('param_name %s must appear exactly once in optimization_reduced.json (found %d)', ...
        param_name, numel(fix_idx));
end
os_reduced = os0;
os_reduced.parameter(fix_idx) = [];
np = numel(os_reduced.parameter);

outdir = fullfile('temp', 'profile_likelihood', tag);
if ~isfolder(outdir), mkdir(outdir); end
csv = fullfile(outdir, 'profile.csv');
fid = fopen(csv, 'w');
fprintf(fid, 'fixed_value,best_error,%s\n', strjoin( ...
    cellfun(@(p) p.name, os_reduced.parameter, 'UniformOutput', false), ','));
fclose(fid);

base_template = loadjson(os0.model_template_file_string);

actual = @(p, i) 10.^(os_reduced.parameter{i}.min_value + ...
    p .* (os_reduced.parameter{i}.max_value - os_reduced.parameter{i}.min_value));

for k = 1:numel(scan_values)
    fixed_val = scan_values(k);
    fprintf('=== PROFILE %s: fixing %s = %.6g (%d/%d) ===\n', ...
        tag, param_name, fixed_val, k, numel(scan_values));

    % Write a scratch model template with param_name fixed
    scratch_template = base_template;
    scratch_template.MyoSim_model.hs_props.parameters.(param_name) = fixed_val;
    template_file = fullfile(outdir, sprintf('template_%02d.json', k));
    out_string = strrep(savejson('MyoSim_model', scratch_template.MyoSim_model), '\/', '/');
    of = fopen(template_file, 'w');
    fprintf(of, '%s', out_string);
    fclose(of);

    os = os_reduced;
    os.model_template_file_string = template_file;

    rdir = fullfile(outdir, sprintf('r%02d', k));
    if ~isfolder(rdir), mkdir(rdir); end
    worker = fullfile(outdir, sprintf('worker_%02d.json', k));
    os.job{1}.model_file_string  = worker;
    os.model_working_file_string = worker;
    os.best_model_file_string    = fullfile(rdir, 'model_best.json');
    os.best_opt_file_string      = fullfile(rdir, 'best_opt.json');
    os.best_model_folder         = rdir;
    % Cap runtime per scan point so a multi-point scan finishes in
    % bounded time on the shared MATLAB license slot.
    os.max_fun_evals             = 1200;

    % Use a fresh, mid-range starting point for the free params each
    % scan point (0.5 in p-space = geometric midpoint of each bound)
    for i = 1:np
        os.parameter{i}.p_value = 0.5;
    end

    err = NaN; vals = nan(1, np);
    try
        fit_controller(os);
        fr = loadjson(fullfile(rdir, 'fit_results.json'));
        err = fr.best_error;
        bo = loadjson(fullfile(rdir, 'best_opt.json'));
        bp = bo.MyoSim_optimization.parameter;
        for i = 1:np
            vals(i) = actual(bp{i}.p_value, i);
        end
    catch ME
        fprintf('scan point %d (%s=%.6g) FAILED: %s\n', k, param_name, fixed_val, ME.message);
    end

    fid = fopen(csv, 'a');
    fprintf(fid, '%.6g,%.6f', fixed_val, err);
    fprintf(fid, ',%.6g', vals);
    fprintf(fid, '\n');
    fclose(fid);
    fprintf('=== scan point %d done: %s=%.6g  e=%.6f ===\n', k, param_name, fixed_val, err);
end

fprintf('PROFILE LIKELIHOOD %s (%s) COMPLETE\n', tag, param_name);
end
