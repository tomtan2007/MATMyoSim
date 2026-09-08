function T = mava_metrics(results_root, out_csv)
% Reports every requested metric for each completed mavacamten fit.
%
% Re-runs each fitted model through its own protocol and compares model to
% target on peak force, time-to-peak, and 50% relaxation time, alongside
% the fitted rates, bound hits, and SRX at rest and peak.
%
% Time-to-peak uses the centroid of all samples within 5% of the maximum,
% not argmax. At the 31 Hz sampling of the experimental traces the peak is
% a plateau six samples wide, and argmax picks an arbitrary member of it --
% that artifact is what made the control trace look 4x too fast.

if nargin < 1 || isempty(results_root)
    results_root = fullfile(fileparts(mfilename('fullpath')), 'mava_codex', 'output', 'results');
end
if nargin < 2 || isempty(out_csv)
    out_csv = fullfile(fileparts(results_root), 'matched_metrics.csv');
end

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

runs = dir(results_root);
runs = runs([runs.isdir] & ~startsWith({runs.name}, '.'));

rows = {};
for i = 1:numel(runs)
    rdir = fullfile(results_root, runs(i).name);
    mfile = fullfile(rdir, 'model_best.json');
    ffile = fullfile(rdir, 'fit_results.json');
    if ~isfile(mfile) || ~isfile(ffile), continue; end

    fit  = loadjson(ffile);
    cfg  = find_config(rdir, runs(i).name);
    if isempty(cfg), continue; end
    o    = cfg.MyoSim_optimization;
    job  = o.job{1};

    sim = simulation_driver( ...
        'model_json_file_string', mfile, ...
        'simulation_protocol_file_string', job.protocol_file_string, ...
        'options_json_file_string', job.options_file_string);

    tgt   = load(job.target_file_string);
    proto = readtable(job.protocol_file_string, 'FileType', 'text', 'Delimiter', '\t');
    t     = cumsum(proto.dt) - proto.dt(1);
    onset = find(proto.pCa < 6.70, 1);

    % Optimizer compares the LAST n rows of the simulation to the target
    n     = numel(tgt);
    mf    = sim.muscle_force(:);
    mf    = mf(end - n + 1 : end);
    tm    = t(end - n + 1 : end);
    on_r  = max(1, onset - (numel(t) - n));

    pre   = max(1, on_r - 50) : max(1, on_r - 1);
    mf    = mf - mean(mf(pre));
    tgt   = tgt(:) - mean(tgt(pre));

    M = waveform(mf,  tm, on_r);
    G = waveform(tgt, tm, on_r);

    pr = loadjson(mfile).MyoSim_model.hs_props.parameters;
    [bnd, pvals] = bound_report(o.parameter, pr);

    m1 = sim.M1(:, 1);  m1 = m1(end - n + 1 : end);
    if isfield(sim, 'M6')
        m6 = sim.M6(:, 1); m6 = m6(end - n + 1 : end);
    else
        m6 = zeros(size(m1));
    end

    rows(end+1, :) = { runs(i).name, fit.best_error, fit.aic, fit.n_active_points, ...
        pr.k_1, pr.k_2, pr.k_3, pr.k_5_0, ...
        M.peak, G.peak, 100*(M.peak - G.peak)/G.peak, ...
        M.tpeak, G.tpeak, 1000*(M.tpeak - G.tpeak), ...
        M.thalf, G.thalf, 1000*(M.thalf - G.thalf), ...
        m1(on_r-1) + m6(on_r-1), m1(M.pidx) + m6(M.pidx), bnd, pvals }; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'run','error','aic','n_points','k_1','k_2','k_3','k_5_0', ...
    'peak_model','peak_target','peak_err_pct', ...
    'tpeak_model','tpeak_target','tpeak_err_ms', ...
    'thalf_model','thalf_target','thalf_err_ms', ...
    'srx_rest','srx_peak','bounds_hit','p_values'});
writetable(T, out_csv);

fprintf('\n%-18s %8s %9s %8s %9s %9s %8s %8s  %s\n', 'run','error', ...
    'peak%err','tp err ms','th err ms','k_1','k_3','k_5_0','bounds');
fprintf('%s\n', repmat('-', 1, 108));
for i = 1:height(T)
    fprintf('%-18s %8.5f %9.1f %9.0f %9.0f %9.4g %8.4g %8.5g  %s\n', ...
        T.run{i}, T.error(i), T.peak_err_pct(i), T.tpeak_err_ms(i), ...
        T.thalf_err_ms(i), T.k_1(i), T.k_3(i), T.k_5_0(i), T.bounds_hit{i});
end
fprintf('\nCSV: %s\n', out_csv);
end


function w = waveform(y, t, onset)
% Peak, plateau-centroid time-to-peak, and 50% relaxation, from Ca onset.
act = onset : numel(y);
[w.peak, rel] = max(y(act));
w.pidx = act(rel);

near = act(y(act) >= 0.95 * w.peak);      % plateau, not a single sample
w.tpeak = mean(t(near)) - t(onset);

tail = y(w.pidx:end);
h = find(tail < 0.5 * w.peak, 1);
if isempty(h)
    w.thalf = NaN;
else
    w.thalf = t(w.pidx + h - 1) - t(w.pidx);
end
end


function [txt, pvals] = bound_report(par, pr)
% Flags any fitted rate sitting within 1% of its log-space bound.
hits = {}; ps = [];
for i = 1:numel(par)
    p = par{i};
    if ~isfield(pr, p.name), ps(end+1) = NaN; continue; end %#ok<AGROW>
    pv = (log10(pr.(p.name)) - p.min_value) / (p.max_value - p.min_value);
    ps(end+1) = pv; %#ok<AGROW>
    if pv <= 0.01, hits{end+1} = [p.name ' low'];  end %#ok<AGROW>
    if pv >= 0.99, hits{end+1} = [p.name ' high']; end %#ok<AGROW>
end
if isempty(hits), txt = 'none'; else, txt = strjoin(hits, '; '); end
pvals = strjoin(compose('%.3f', ps), ' ');
end


function cfg = find_config(rdir, name)
cand = fullfile(fileparts(fileparts(rdir)), [name '_optimization.json']);
if isfile(cand), cfg = loadjson(cand); else, cfg = []; end
end
