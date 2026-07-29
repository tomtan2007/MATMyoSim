function sweep_all_grid(demo_dir)
% SWEEP_ALL_GRID  Peak-force sweep of EVERY numeric parameter, one panel each.
%
% For each numeric scalar parameter in temp/best/model_best.json this sweeps
% the value 0.1x -> 10x its best fit (log-spaced) and records peak twitch
% force. It then draws a spacious grid of peak-force-vs-parameter panels
% (log x-axis), one figure per model. No SRX occupancy row.
%
% Usage:
%   sweep_all_grid('twitch_6state_control')
%
% Writes <demo_dir>/temp/sweeps/sweep_all_grid.png  (+ .csv of raw points)

script_dir = fileparts(mfilename('fullpath'));            % Code/Fitting
repo_root  = fullfile(script_dir, '..', '..');
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
tmp_model = fullfile('temp', 'sweep_grid_model.json');

P     = model_best.MyoSim_model.hs_props.parameters;
names = fieldnames(P);

nvals = 7;
mults = logspace(-1, 1, nvals);          % 0.1x .. 10x, log-spaced, includes 1x

% ---- collect sweepable (nonzero numeric scalar) parameters ----
sw = struct('name', {}, 'best', {}, 'xvals', {}, 'peaks', {});
for i = 1:numel(names)
    nm = names{i};
    v  = P.(nm);
    if ~(isnumeric(v) && isscalar(v)) || v == 0
        continue;   % skip strings, arrays, and params fixed at 0
    end
    xvals = v * mults;
    peaks = nan(1, nvals);
    fprintf('Sweeping %-20s (best=%.4g) ...\n', nm, v);
    for s = 1:nvals
        model = model_best;
        model.MyoSim_model.hs_props.parameters.(nm) = xvals(s);
        savejson('', model, tmp_model);
        peaks(s) = run_one(tmp_model, protocol_file, options_file);
    end
    sw(end+1) = struct('name', nm, 'best', v, 'xvals', xvals, 'peaks', peaks); %#ok<AGROW>
end

% ---- order panels by |peak elasticity|-ish (span), most responsive first ----
span = arrayfun(@(p) local_span(p.peaks), sw);
[~, order] = sort(span, 'descend');
sw = sw(order);

n      = numel(sw);
ncols  = 5;
nrows  = ceil(n / ncols);

teal = [0.15 0.55 0.55];
fig  = figure('Color', 'w', 'Position', [0 0 460*ncols 300*nrows + 90]);
tl   = tiledlayout(nrows, ncols, 'Padding', 'compact', 'TileSpacing', 'compact');

for i = 1:n
    ax = nexttile(tl); %#ok<LAXES>
    plot(ax, sw(i).xvals, sw(i).peaks, '-o', 'Color', teal, ...
         'MarkerFaceColor', teal, 'MarkerSize', 5, 'LineWidth', 1.6);
    set(ax, 'XScale', 'log', 'FontSize', 9, 'Box', 'off');
    grid(ax, 'on'); ax.GridAlpha = 0.15;
    title(ax, strrep(sw(i).name, '_', '\_'), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel(ax, strrep(sw(i).name, '_', '\_'), 'FontSize', 8);
    ylabel(ax, 'Peak force (N m^{-2})', 'FontSize', 8);
    xlim(ax, [min(sw(i).xvals) max(sw(i).xvals)]);
end

leaf = demo_dir_leaf(demo_dir);
sgtitle(pretty_title(leaf), 'FontSize', 15, 'FontWeight', 'bold');

png_path = fullfile('temp', 'sweeps', 'sweep_all_grid.png');
exportgraphics(fig, png_path, 'Resolution', 130);
fprintf('\nSaved %s  (%d parameters)\n', png_path, n);

% ---- raw sweep points to CSV ----
rows = {};
for i = 1:n
    for s = 1:nvals
        rows(end+1, :) = {sw(i).name, sw(i).best, sw(i).xvals(s), sw(i).peaks(s)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'param', 'best', 'x_value', 'peak_force'});
csv_path = fullfile('temp', 'sweeps', 'sweep_all_grid.csv');
writetable(T, csv_path);
fprintf('Saved %s\n', csv_path);
end

% ---------------------------------------------------------------------------
function pk = run_one(model_file, protocol_file, options_file)
try
    s = simulation_driver( ...
        'model_json_file_string',          model_file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string',        options_file);
    pk = max(s.muscle_force(:));
catch
    pk = NaN;
end
end

function d = local_span(v)
v = v(~isnan(v) & v > 0);
if numel(v) < 2, d = 0; else, d = max(v) / min(v); end
end

function leaf = demo_dir_leaf(p)
parts = strsplit(p, filesep);
parts = parts(~cellfun(@isempty, parts));
leaf  = parts{end};
end

function t = pretty_title(leaf)
% twitch_6state_control -> "6-State Control"
t = leaf;
t = regexprep(t, '^twitch_', '');
t = regexprep(t, '(\d)state', '$1-State');
t = strrep(t, '_control', ' Control');
t = strrep(t, '_HCM', ' HCM');
t = regexprep(t, '^(\d-State)', '${upper($1)}');
end
