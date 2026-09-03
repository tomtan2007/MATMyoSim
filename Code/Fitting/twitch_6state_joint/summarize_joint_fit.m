function summarize_joint_fit(best_opt_file)
% Prints the shared vs split parameter values/ratios from a completed
% joint control+HCM fit, and the AIC-vs-independent-fits comparison.
%
% Usage: summarize_joint_fit('temp/best/best_6state_joint.json')

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(genpath(repo_root));
cd(fileparts(mfilename('fullpath')));

if nargin < 1
    best_opt_file = 'temp/best/best_6state_joint.json';
end

bo = loadjson(best_opt_file);
params = bo.MyoSim_optimization.parameter;

fprintf('\n=== JOINT FIT RESULTS (%s) ===\n', best_opt_file);
fprintf('\n--- Shared parameters (identical ctrl & HCM) ---\n');
for i = 1:numel(params)
    pr = params{i};
    if ~isfield(pr, 'job')
        val = return_parameter_value(pr, pr.p_value);
        fprintf('  %-10s = %.6g\n', pr.name, val);
    end
end

fprintf('\n--- Split parameters (allowed to differ ctrl vs HCM) ---\n');
target_names = {};
for i = 1:numel(params)
    if isfield(params{i}, 'job')
        tn = params{i}.target_name;
        if ~any(strcmp(target_names, tn))
            target_names{end+1} = tn; %#ok<AGROW>
        end
    end
end
for t = 1:numel(target_names)
    tn = target_names{t};
    ctrl_val = NaN; hcm_val = NaN;
    for i = 1:numel(params)
        if isfield(params{i}, 'job') && strcmp(params{i}.target_name, tn)
            v = return_parameter_value(params{i}, params{i}.p_value);
            if params{i}.job == 1
                ctrl_val = v;
            elseif params{i}.job == 2
                hcm_val = v;
            end
        end
    end
    fprintf('  %-8s : ctrl=%.6g  hcm=%.6g  ratio(hcm/ctrl)=%.3f\n', ...
        tn, ctrl_val, hcm_val, hcm_val / ctrl_val);
end

fr_file = fullfile(fileparts(best_opt_file), 'fit_results.json');
if isfile(fr_file)
    fr = loadjson(fr_file);
    fprintf('\n--- Fit quality ---\n');
    fprintf('  combined error (mean of ctrl/HCM MSE) = %.6f\n', fr.best_error);
    fprintf('  n_free_params = %d,  AIC (approx, see fit_controller.m note) = %.1f\n', ...
        fr.n_free_params, fr.aic);
end
fprintf('\n');
end
