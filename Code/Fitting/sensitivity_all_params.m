function sensitivity_all_params(demo_dir)
% SENSITIVITY_ALL_PARAMS  Sweep EVERY numeric parameter of a fitted model.
%
% For each numeric scalar parameter in temp/best/model_best.json this
% perturbs the value around its best fit and measures how the twitch
% responds, reporting two metrics on two outputs:
%
%   elasticity  = normalised local slope  =  (%change in output) / (%change in param)
%                 computed from a +/-10% step around the best fit
%                 ("rise over run" magnitude, comparable across all params)
%   fold        = max/min output over a wide 0.1x - 10x sweep (saturation view)
%
%   outputs measured: peak force  and  relaxation half-time (peak -> 50% decay)
%
% Parameters fixed at exactly 0 (e.g. off transitions k_8, k_10) cannot be
% swept multiplicatively, so they get an additive ladder and elasticity = NaN
% (raw peak force at each test value is still recorded in the CSV).
%
% Usage (from Code/Fitting, or anywhere):
%   sensitivity_all_params('twitch_6state_HCM')
%   sensitivity_all_params('/abs/path/to/twitch_6state_control')
%
% Writes into <demo_dir>/temp/sweeps/:
%   sensitivity_all.csv   ranked table (sorted by |peak elasticity|)
%   sensitivity_all.png   elasticity bar chart

script_dir = fileparts(mfilename('fullpath'));          % Code/Fitting
repo_root  = fullfile(script_dir, '..', '..');          % repo root
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));  % beat worktree shadowing

if ~startsWith(demo_dir, filesep)
    demo_dir = fullfile(script_dir, demo_dir);
end
cd(demo_dir);

model_best    = loadjson(fullfile('temp', 'best', 'model_best.json'));
opt           = loadjson(fullfile('sim_input', 'optimization.json'));
job           = opt.MyoSim_optimization.job{1};
protocol_file = job.protocol_file_string;
options_file  = job.options_file_string;

if ~isfolder(fullfile('temp', 'sweeps')), mkdir(fullfile('temp', 'sweeps')); end
tmp_model = fullfile('temp', 'sensitivity_model.json');

P     = model_best.MyoSim_model.hs_props.parameters;
names = fieldnames(P);

% Baseline (unperturbed) run
savejson('', model_best, tmp_model);
base = run_one(tmp_model, protocol_file, options_file);
fprintf('Baseline: peak=%.1f N/m^2  relax_half=%.4g s\n\n', base.peak, base.t_half);

mult_lo = 0.1; mult_hi = 10;          % wide fold-range sweep
loc_lo  = 0.9; loc_hi  = 1.1;         % local +/-10% for elasticity
add_ladder = [0 0.5 1 5 50];          % for params fixed at 0

R = struct('name', {}, 'best', {}, 'mode', {}, ...
           'peak_elast', {}, 'peak_fold', {}, 'peak_dir', {}, ...
           'relax_elast', {}, 'relax_fold', {});

for i = 1:numel(names)
    nm = names{i};
    v  = P.(nm);
    if ~(isnumeric(v) && isscalar(v))
        continue;   % skip strings (passive_force_mode) and arrays
    end

    fprintf('Sweeping %-20s (best=%.4g) ...\n', nm, v);

    if v ~= 0
        mode      = 'mult';
        test_vals = v * [mult_lo, loc_lo, 1, loc_hi, mult_hi];
        i0        = 3;                 % index of the 1.0x point
    else
        mode      = 'add';
        test_vals = add_ladder;
        i0        = 1;                 % baseline value (0)
    end

    peaks  = nan(1, numel(test_vals));
    relaxs = nan(1, numel(test_vals));
    for s = 1:numel(test_vals)
        model = model_best;
        model.MyoSim_model.hs_props.parameters.(nm) = test_vals(s);
        savejson('', model, tmp_model);
        out       = run_one(tmp_model, protocol_file, options_file);
        peaks(s)  = out.peak;
        relaxs(s) = out.t_half;
    end

    % Elasticity from the local +/-10% points (mult only)
    if strcmp(mode, 'mult')
        F0          = peaks(i0);
        peak_elast  = (peaks(4) - peaks(2)) / (0.2 * F0);
        r0          = relaxs(i0);
        relax_elast = (relaxs(4) - relaxs(2)) / (0.2 * r0);
    else
        peak_elast  = NaN;
        relax_elast = NaN;
    end

    R(end+1) = struct( ...
        'name', nm, 'best', v, 'mode', mode, ...
        'peak_elast',  peak_elast, ...
        'peak_fold',   safe_fold(peaks), ...
        'peak_dir',    dir_str(peaks), ...
        'relax_elast', relax_elast, ...
        'relax_fold',  safe_fold(relaxs)); %#ok<AGROW>
end

% Rank by |peak elasticity| (NaN / additive params sort to the bottom)
key = arrayfun(@(r) abs_or_neg(r.peak_elast), R);
[~, order] = sort(key, 'descend');
R = R(order);

% ---- console table ----
fprintf('\n===== Sensitivity ranking: %s =====\n', demo_dir);
fprintf('%-20s %-6s %10s %9s %8s %11s\n', ...
    'param', 'mode', 'peak_elast', 'peak_fold', 'dir', 'relax_elast');
for i = 1:numel(R)
    fprintf('%-20s %-6s %10.3f %8.1fx %8s %11.3f\n', ...
        R(i).name, R(i).mode, R(i).peak_elast, R(i).peak_fold, ...
        R(i).peak_dir, R(i).relax_elast);
end

% ---- CSV ----
T = struct2table(R);
csv_path = fullfile('temp', 'sweeps', 'sensitivity_all.csv');
writetable(T, csv_path);
fprintf('\nSaved %s\n', csv_path);

% ---- bar chart of peak elasticity ----
valid = ~isnan([R.peak_elast]);
fig = figure('Color', 'w', 'Position', [40 40 700 max(400, 26*sum(valid))]);
barh(categorical({R(valid).name}), [R(valid).peak_elast], ...
     'FaceColor', [0.15 0.55 0.55]);
set(gca, 'YDir', 'reverse');
xlabel('Peak-force elasticity  (%\Delta force / %\Delta param)');
title(sprintf('All-parameter sensitivity: %s', ...
      strrep(demo_dir_leaf(demo_dir), '_', '\_')));
grid on; box off;
png_path = fullfile('temp', 'sweeps', 'sensitivity_all.png');
saveas(fig, png_path);
fprintf('Saved %s\n', png_path);
end

% ---------------------------------------------------------------------------
function m = run_one(model_file, protocol_file, options_file)
% Run one simulation; return peak force and relaxation half-time.
% Returns NaNs if the parameter value makes the simulation fail.
try
    s = simulation_driver( ...
        'model_json_file_string',          model_file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string',        options_file);
    f = s.muscle_force(:);
    t = s.time_s(:);
    n_pre    = min(300, numel(f));              % pre-Ca-onset baseline
    baseline = mean(f(1:n_pre));
    [pk, pidx] = max(f);
    half = baseline + 0.5 * (pk - baseline);
    ridx = find(f(pidx:end) <= half, 1, 'first');
    if isempty(ridx)
        t_half = NaN;
    else
        t_half = t(pidx + ridx - 1) - t(pidx);
    end
    m.peak = pk; m.t_half = t_half;
catch
    m.peak = NaN; m.t_half = NaN;
end
end

function f = safe_fold(v)
v = v(~isnan(v) & v > 0);
if numel(v) < 2, f = NaN; else, f = max(v) / min(v); end
end

function d = dir_str(v)
v = v(~isnan(v));
if numel(v) < 2, d = '-'; elseif v(end) > v(1), d = 'up'; else, d = 'down'; end
end

function k = abs_or_neg(x)
if isnan(x), k = -Inf; else, k = abs(x); end
end

function leaf = demo_dir_leaf(p)
parts = strsplit(p, filesep);
parts = parts(~cellfun(@isempty, parts));
leaf  = parts{end};
end
