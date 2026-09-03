function results = compare_models(varargin)
% Runs two or more models through one protocol and plots them side by side.
% No optimizer -- this is for quick manual parameter fiddling, so you can
% edit a model JSON, rerun, and see what changed in a few seconds.
%
%   compare_models()
%       Control best-fit vs H251N best-fit on protocol_1s.txt.
%
%   compare_models('models', {'a.json','b.json'}, 'labels', {'A','B'})
%       Any set of model JSONs. Paths may be absolute or relative to
%       Code/Fitting/.
%
%   compare_models('protocol', p, 'options', o, 'out', 'my_fig.png')
%       Override the protocol, the sim_options JSON, or the figure path.
%
% Returns a struct array with one entry per model holding the raw sim
% output plus the summary metrics printed to the console.
%
% Only ever starts ONE MATLAB simulation at a time -- the license dies
% silently at three instances, so do not run this alongside a fit.

repo_root = fileparts(mfilename('fullpath'));       % Code/Fitting
code_root = fileparts(repo_root);                   % Code
addpath(genpath(code_root));
addpath(genpath(fullfile(code_root, 'System')));    % must follow: worktrees shadow

p = inputParser;
addParameter(p, 'models', {});
addParameter(p, 'labels', {});
addParameter(p, 'protocol', fullfile(code_root, 'System', 'protocols', 'protocol_1s.txt'));
addParameter(p, 'options', fullfile(repo_root, 'twitch_6state_control', 'sim_input', 'sim_options.json'));
addParameter(p, 'out', fullfile(repo_root, 'fit_comparison_figures', 'compare_models.png'));
parse(p, varargin{:});
opt = p.Results;

if isempty(opt.models)
    opt.models = { ...
        fullfile(repo_root, 'twitch_6state_control', 'temp', 'best', 'model_best.json'), ...
        fullfile(repo_root, 'twitch_6state_HCM',     'temp', 'best', 'model_best.json')};
    if isempty(opt.labels)
        opt.labels = {'6-state control', '6-state H251N'};
    end
end
if ischar(opt.models) || isstring(opt.models)
    opt.models = cellstr(opt.models);
end
n = numel(opt.models);
if isempty(opt.labels)
    opt.labels = cell(1, n);
    for i = 1:n
        [~, base] = fileparts(opt.models{i});
        opt.labels{i} = strrep(base, '_', ' ');
    end
end
if numel(opt.labels) ~= n
    error('compare_models:labelMismatch', ...
        'Got %d models but %d labels.', n, numel(opt.labels));
end

% Resolve relative paths against Code/Fitting and fail early on typos
for i = 1:n
    if ~isfile(opt.models{i})
        candidate = fullfile(repo_root, opt.models{i});
        if isfile(candidate)
            opt.models{i} = candidate;
        else
            error('compare_models:missingModel', ...
                'Model %d not found: %s', i, opt.models{i});
        end
    end
end
if ~isfile(opt.protocol)
    error('compare_models:missingProtocol', 'Protocol not found: %s', opt.protocol);
end

% Ca onset sets the baseline window and the relative time axis
proto     = readtable(opt.protocol, 'FileType', 'text', 'Delimiter', '\t');
t_abs     = cumsum(proto.dt) - proto.dt(1);
onset_idx = find(proto.pCa < 6.70, 1);
if isempty(onset_idx)
    error('compare_models:noCaOnset', ...
        'No row with pCa < 6.70 in %s -- is this an activating protocol?', opt.protocol);
end
t_onset = t_abs(onset_idx);

% 50 rows immediately before onset: equilibrated, and past the startup ramp.
% Do not average the whole pre-activation region -- the model ramps from
% its initial condition over roughly the first 100 rows.
pre_win = max(1, onset_idx - 50) : (onset_idx - 1);

fprintf('Protocol : %s\n', opt.protocol);
fprintf('Ca onset : row %d (t = %.3f s)\n\n', onset_idx, t_onset);

results = struct('label', {}, 'model', {}, 'sim', {}, 'force', {}, ...
                 'time_rel', {}, 'peak', {}, 't_peak', {}, 't_half', {}, ...
                 'srx_rest', {}, 'srx_peak', {});

for i = 1:n
    fprintf('Running %s ...\n', opt.labels{i});
    sim = simulation_driver( ...
        'model_json_file_string', opt.models{i}, ...
        'simulation_protocol_file_string', opt.protocol, ...
        'options_json_file_string', opt.options);

    force = sim.muscle_force(:) - mean(sim.muscle_force(pre_win));
    m     = twitch_metrics(force, sim, t_abs, onset_idx);

    results(i).label    = opt.labels{i};
    results(i).model    = opt.models{i};
    results(i).sim      = sim;
    results(i).force    = force;
    results(i).time_rel = t_abs - t_onset;
    results(i).peak     = m.peak;
    results(i).t_peak   = m.t_peak;
    results(i).t_half   = m.t_half;
    results(i).srx_rest = m.srx_rest;
    results(i).srx_peak = m.srx_peak;
end

print_summary(results);
plot_comparison(results, opt);
end


function m = twitch_metrics(force, sim, t_abs, onset_idx)
% Peak, time-to-peak, and 50% relaxation time, all measured from Ca onset.
% SRX follows the existing convention in sensitivity_all_params.m: M1 only.
% For 6-state models M6 (SRXT) is reported too, since total SRX is M1 + M6.

active = onset_idx : numel(force);
[m.peak, rel_idx] = max(force(active));
pidx   = active(rel_idx);
m.t_peak = t_abs(pidx) - t_abs(onset_idx);

% First crossing below half peak after the peak; NaN if it never relaxes
% within the record (this is a real HCM signature above ~1050 nm, not a bug)
tail = force(pidx:end);
half = find(tail < 0.5 * m.peak, 1);
if isempty(half)
    m.t_half = NaN;
else
    m.t_half = t_abs(pidx + half - 1) - t_abs(pidx);
end

if isfield(sim, 'M1')
    m1 = sim.M1(:, 1);
    m.srx_rest = m1(onset_idx - 1);
    m.srx_peak = m1(pidx);
    if isfield(sim, 'M6')
        m6 = sim.M6(:, 1);
        m.srx_rest_total = m.srx_rest + m6(onset_idx - 1);
        m.srx_peak_total = m.srx_peak + m6(pidx);
    end
else
    m.srx_rest = NaN;
    m.srx_peak = NaN;
end
end


function print_summary(r)
fprintf('\n%-22s %12s %10s %10s %10s %10s\n', ...
    'model', 'peak N/m^2', 't_peak s', 't_half s', 'SRX rest', 'SRX peak');
fprintf('%s\n', repmat('-', 1, 78));
for i = 1:numel(r)
    fprintf('%-22s %12.1f %10.4f %10.4f %10.3f %10.3f\n', ...
        r(i).label, r(i).peak, r(i).t_peak, r(i).t_half, ...
        r(i).srx_rest, r(i).srx_peak);
end

% Ratios against the first model, which is the usual reason for running this
if numel(r) > 1
    fprintf('\nratios vs %s:\n', r(1).label);
    for i = 2:numel(r)
        fprintf('  %-20s peak x%.3f', r(i).label, r(i).peak / r(1).peak);
        if ~isnan(r(i).t_half) && ~isnan(r(1).t_half)
            fprintf('   t_half x%.3f', r(i).t_half / r(1).t_half);
        else
            fprintf('   t_half n/a');
        end
        fprintf('\n');
    end
end
fprintf('\n');
end


function plot_comparison(r, opt)
n      = numel(r);
colors = lines(max(n, 3));

fig = figure('Name', 'Model comparison', 'Position', [40 40 1150 750], 'Color', 'w');

% Force
ax1 = subplot(3, 1, 1); hold(ax1, 'on');
for i = 1:n
    plot(ax1, r(i).time_rel, r(i).force, 'LineWidth', 1.6, 'Color', colors(i, :), ...
        'DisplayName', sprintf('%s (peak %.0f)', r(i).label, r(i).peak));
end
yline(ax1, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
xline(ax1, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
ylabel(ax1, 'force (N m^{-2})');
title(ax1, 'Force, baseline-zeroed at Ca onset');
legend(ax1, 'Location', 'northeast'); grid(ax1, 'on');

% SRX -- M1 solid, total M1+M6 dashed where the model has six states
ax2 = subplot(3, 1, 2); hold(ax2, 'on');
any_total = false;
for i = 1:n
    s = r(i).sim;
    if ~isfield(s, 'M1'), continue; end
    plot(ax2, r(i).time_rel, s.M1(:, 1), 'LineWidth', 1.6, 'Color', colors(i, :), ...
        'DisplayName', sprintf('%s M1', r(i).label));
    if isfield(s, 'M6')
        plot(ax2, r(i).time_rel, s.M1(:, 1) + s.M6(:, 1), '--', ...
            'LineWidth', 1.2, 'Color', colors(i, :), ...
            'DisplayName', sprintf('%s M1+M6', r(i).label));
        any_total = true;
    end
end
xline(ax2, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
ylabel(ax2, 'SRX fraction');
if any_total
    title(ax2, 'SRX: M1 (solid), total M1+M6 (dashed)');
else
    title(ax2, 'SRX fraction (M1)');
end
legend(ax2, 'Location', 'northeast'); grid(ax2, 'on');

% Ca -- identical across models by construction, so plot it once as a check
ax3 = subplot(3, 1, 3); hold(ax3, 'on');
if isfield(r(1).sim, 'Ca')
    plot(ax3, r(1).time_rel, r(1).sim.Ca(:, 1), 'LineWidth', 1.6, 'Color', [0.2 0.2 0.2]);
    ylabel(ax3, '[Ca^{2+}] (M)');
    title(ax3, 'Calcium transient (shared -- same protocol for every model)');
end
xline(ax3, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
xlabel(ax3, 'time from Ca onset (s)');
grid(ax3, 'on');

linkaxes([ax1 ax2 ax3], 'x');

out_dir = fileparts(opt.out);
if ~isempty(out_dir) && ~isfolder(out_dir)
    mkdir(out_dir);
end
exportgraphics(fig, opt.out, 'Resolution', 150);
fprintf('Figure saved: %s\n', opt.out);
fprintf('View it with:  open %s\n', opt.out);
end
