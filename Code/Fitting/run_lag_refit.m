% run_lag_refit.m
% Refit all 6 twitch models (3/4/6-state x ctrl/HCM) using the Ca-onset +14ms
% lagged protocol (protocol_1s_lag14.txt), starting from each model's current
% best-fit params (the p_values already seeded in optimization.json).
% ALL outputs go to a scratch dir — canonical temp/best/* are never touched.
% Compares new (lagged) AIC vs canonical (original-protocol) AIC per model.

repo_root = fileparts(mfilename('fullpath'));           % Code/Fitting
code_root = fileparts(repo_root);                        % Code
addpath(genpath(code_root));
addpath(genpath(fullfile(code_root, 'System')));

lag_proto = fullfile(code_root, 'System', 'protocols', 'protocol_1s_lag14.txt');
scratch   = '/private/tmp/claude-503/-Users-tomtan-Research-MATMyoSim/4ad0e06f-1d17-488d-962b-8f5e65c611d9/scratchpad/lag_refit';
if ~isfolder(scratch), mkdir(scratch); end

demos = { 'twitch_3state_control','twitch_3state_HCM', ...
          'twitch_4state_control','twitch_4state_HCM', ...
          'twitch_6state_control','twitch_6state_HCM' };

summary = {};
for d = 1:numel(demos)
    name     = demos{d};
    demo_dir = fullfile(repo_root, name);
    out_dir  = fullfile(scratch, name);
    if ~isfolder(out_dir), mkdir(out_dir); end

    % Canonical (original-protocol) result for comparison
    can = fullfile(demo_dir, 'temp', 'best', 'fit_results.json');
    if isfile(can)
        cj = loadjson(can); can_e = cj.best_error; can_aic = cj.aic;
    else
        can_e = NaN; can_aic = NaN;
    end

    cd(demo_dir);   % relative template/options/target paths resolve from here
    % Seed from the canonical best-fit opt file so the refit starts AT the
    % optimum — only the protocol (Ca lag) differs from the canonical fit.
    best_opt_name = ['best_' erase(name,'twitch_') '.json'];
    opt = loadjson(fullfile('temp','best',best_opt_name));
    o   = opt.MyoSim_optimization;

    % Redirect protocol -> lagged, all model outputs -> scratch
    o.job{1}.protocol_file_string = lag_proto;
    o.job{1}.model_file_string    = fullfile(out_dir, 'model_worker.json');
    o.job{1}.results_file_string  = fullfile(out_dir, 'twitch.myo');
    o.model_working_file_string   = o.job{1}.model_file_string;
    o.best_model_file_string      = fullfile(out_dir, 'model_best.json');
    o.best_model_folder           = out_dir;
    o.best_opt_file_string        = fullfile(out_dir, 'best_opt.json');
    o.figure_current_fit          = 0;
    o.figure_optimization_progress= 0;

    fprintf('\n===== Refitting %s (lag14) =====\n', name);
    try
        fit_controller(o);
        rj = loadjson(fullfile(out_dir, 'fit_results.json'));
        new_e = rj.best_error; new_aic = rj.aic;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        new_e = NaN; new_aic = NaN;
    end

    summary(end+1,:) = {name, can_e, new_e, can_aic, new_aic, new_aic-can_aic}; %#ok<AGROW>
end

% Write summary table
fprintf('\n\n================ LAG-14 REFIT SUMMARY ================\n');
fprintf('%-22s %10s %10s %10s %10s %10s\n', 'model','e_orig','e_lag','AIC_orig','AIC_lag','dAIC');
fid = fopen(fullfile(scratch,'lag_refit_summary.csv'),'w');
fprintf(fid,'model,e_orig,e_lag,AIC_orig,AIC_lag,dAIC\n');
for i = 1:size(summary,1)
    fprintf('%-22s %10.5f %10.5f %10.1f %10.1f %+10.1f\n', summary{i,:});
    fprintf(fid,'%s,%.6f,%.6f,%.2f,%.2f,%.2f\n', summary{i,:});
end
fclose(fid);
fprintf('Saved: %s\n', fullfile(scratch,'lag_refit_summary.csv'));
