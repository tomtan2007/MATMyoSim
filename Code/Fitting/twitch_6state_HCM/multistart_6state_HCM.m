function multistart_6state_HCM(n_restarts)
% Random-restart wrapper for the 6-state HCM fit.
% Randomizes free-param starting p_values each restart, logs key params.
if nargin < 1, n_restarts = 6; end

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
cd(fileparts(mfilename('fullpath')));

rng(42);  % reproducible restart seeds

opt = loadjson('sim_input/optimization.json');
base = opt.MyoSim_optimization;
base.model_working_file_string = base.job{1}.model_file_string;

if ~isfolder('temp/restarts'), mkdir('temp/restarts'); end

npar = numel(base.parameter);
names = cell(1,npar);
for i = 1:npar, names{i} = base.parameter{i}.name; end
track = {'k_1','k_7_1','k_5_0','k_3','k_off','k_4_0','k_coop'};

results = [];
for r = 1:n_restarts
    o = base;
    % Randomize starting p_values in [0.15, 0.85] for every free param
    for i = 1:npar
        o.parameter{i}.p_value = 0.15 + 0.70*rand();
    end
    o.best_model_file_string = sprintf('temp/restarts/model_best_r%d.json', r);
    o.best_opt_file_string   = sprintf('temp/restarts/best_opt_r%d.json', r);

    fprintf('\n===== RESTART %d/%d =====\n', r, n_restarts);
    try
        fit_controller(o);
    catch ME
        fprintf('restart %d ERROR: %s\n', r, ME.message);
        continue;
    end

    % Read resulting best model params + error/AIC (fit_results.json lands
    % in fileparts(best_opt_file_string) = temp/restarts/)
    m = loadjson(o.best_model_file_string);
    p = m.MyoSim_model.hs_props.parameters;
    fr = loadjson('temp/restarts/fit_results.json');
    row.restart = r;
    row.error = fr.best_error;
    row.aic = fr.aic;
    for t = 1:numel(track)
        row.(track{t}) = p.(track{t});
    end
    results = [results; row];
    fprintf('restart %d: e=%.5f AIC=%.1f  k_1=%.2f  k_7_1=%.3f  k_5_0=%.1f  k_3=%.2f  k_off=%.2f\n', ...
        r, fr.best_error, fr.aic, p.k_1, p.k_7_1, p.k_5_0, p.k_3, p.k_off);
end

fprintf('\n===== MULTISTART SUMMARY (6-state HCM) =====\n');
fprintf('%-8s %9s %9s %8s %8s %8s %8s %8s\n','restart','error','AIC','k_1','k_7_1','k_5_0','k_3','k_off');
for i = 1:numel(results)
    fprintf('%-8d %9.5f %9.1f %8.2f %8.3f %8.1f %8.2f %8.2f\n', ...
        results(i).restart, results(i).error, results(i).aic, results(i).k_1, ...
        results(i).k_7_1, results(i).k_5_0, results(i).k_3, results(i).k_off);
end

% Save CSV
T = struct2table(results);
writetable(T, 'temp/restarts/multistart_summary.csv');
fprintf('Saved temp/restarts/multistart_summary.csv\n');
end
