function multistart_fit_control(tag, idx_start, idx_end, seed)
% Multi-start for the CANONICAL 6-state CONTROL fit (protocol_1s.txt,
% Con_target.txt, sim_input/optimization.json — 10 free params). Runs
% restarts idx_start..idx_end in ONE MATLAB process (robust to
% background-task kills), randomizing each free parameter's p_value and
% writing one CSV row per restart as it completes.
%
% Adapted from multistart_fit.m (which targets the slow-onset 6-state HCM
% fit). This version targets twitch_6state_control / optimization.json
% (canonical protocol, no slow-onset changes). Does NOT touch
% temp/best/model_best.json — outputs go to temp/multistart/ only.
%
% Two instances (e.g. tag 'A' 1-5, tag 'B' 6-10) can run concurrently —
% each uses its own worker model file so they don't collide.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

demo_dir = fullfile(fileparts(mfilename('fullpath')), 'twitch_6state_control');
cd(demo_dir);

opt = loadjson('sim_input/optimization.json');
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

outdir = fullfile('temp', 'multistart');
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
