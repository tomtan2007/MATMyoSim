function multistart_fit_hcm_reduced(tag, idx_start, idx_end, seed)
% Multi-start for the REDUCED-PARAMETER 6-state HCM fit
% (sim_input/optimization_reduced.json — 9 free params, k_off FIXED at the
% control canonical best-fit value 12.2886 s^-1, k_on/k_coop bounds
% tightened per Campbell 2018 + control-multistart clustering). Runs
% restarts idx_start..idx_end in ONE MATLAB process (robust to
% background-task kills), randomizing each free parameter's p_value and
% writing one CSV row per restart as it completes.
%
% Adapted from multistart_fit_control.m. Does NOT touch
% temp/best/model_best.json (the canonical 10-param HCM fit) — outputs go
% to temp/multistart_reduced/ only, using a separate model_template_reduced
% + separate best_model_folder (temp/best_reduced) so the canonical run is
% never overwritten.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

demo_dir = fullfile(fileparts(mfilename('fullpath')), 'twitch_6state_HCM');
cd(demo_dir);

opt = loadjson('sim_input/optimization_reduced.json');
os0 = opt.MyoSim_optimization;
os0.figure_current_fit = 0;
os0.figure_optimization_progress = 0;

np     = numel(os0.parameter);
pnames = cell(1, np);
mn = zeros(1,np); mx = zeros(1,np);
for i = 1:np
    pnames{i} = os0.parameter{i}.name;
    mn(i) = os0.parameter{i}.min_value;
    mx(i) = os0.parameter{i}.max_value;
end
actual = @(p, i) 10.^(mn(i) + p .* (mx(i) - mn(i)));   % log p_mode

outdir = fullfile('temp', 'multistart_reduced');
if ~isfolder(outdir), mkdir(outdir); end
csv = fullfile(outdir, sprintf('ms_%s.csv', tag));
if ~isfile(csv)
    fid = fopen(csv, 'w');
    fprintf(fid, 'restart,error,%s\n', strjoin(pnames, ','));
    fclose(fid);
end

rng(seed);
% pre-draw all random starts so each restart index is reproducible
starts = 0.05 + 0.90 * rand(idx_end, np);

for r = idx_start:idx_end
    os = os0;
    for i = 1:np
        os.parameter{i}.p_value = starts(r, i);
    end
    rdir = fullfile(outdir, sprintf('r%02d_%s', r, tag));
    if ~isfolder(rdir), mkdir(rdir); end
    worker = fullfile(outdir, sprintf('worker_%s.json', tag));
    os.job{1}.model_file_string   = worker;
    os.model_working_file_string  = worker;
    os.best_model_file_string     = fullfile(rdir, 'model_best.json');
    os.best_opt_file_string       = fullfile(rdir, 'best_opt.json');
    os.best_model_folder          = rdir;

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
        fprintf('restart %d (%s) FAILED: %s\n', r, tag, ME.message);
    end

    fid = fopen(csv, 'a');
    fprintf(fid, '%d,%.6f', r, err);
    fprintf(fid, ',%.6g', vals);
    fprintf(fid, '\n');
    fclose(fid);
    fprintf('=== restart %d (%s) done: e=%.6f ===\n', r, tag, err);
end

fprintf('MULTISTART %s COMPLETE (%d-%d)\n', tag, idx_start, idx_end);
end
