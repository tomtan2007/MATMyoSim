function length_sweep_6state(demo_dir)
% LENGTH_SWEEP_6STATE  Length-tension characterization of a fitted 6-state twitch model.
%
% Sweeps the operating half-sarcomere length (hs_props.hs_length) over
% 800-1200 nm (+/-20% around the current 1000 nm baseline) with all fitted
% kinetic parameters and passive_hsl_slack held fixed at temp/best/model_best.json
% values -- no refit, pure characterization (same philosophy as
% sensitivity_all_params.m, but on the length axis instead of a kinetic rate,
% which that sweep structurally never covered).
%
% For each length, runs the standard twitch protocol and records:
%   peak force, % half-sarcomere shortening, relaxation half-time,
%   baseline/at-peak SRX fraction (M1) and DRX fraction (M2)
%
% Usage (from Code/Fitting, or anywhere):
%   length_sweep_6state('twitch_6state_control')
%   length_sweep_6state('twitch_6state_HCM')
%
% Writes into <demo_dir>/temp/sweeps/:
%   length_sweep.csv
%   length_sweep.png   (force-length curve + measurable-output panels)

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
tmp_model = fullfile('temp', 'length_sweep_model.json');

hsl_baseline = model_best.MyoSim_model.hs_props.hs_length;
ca_onset     = 352;   % protocol_1s.txt Ca onset row, project convention (see parameter_sweep_6state_control.m)

lengths = 800:50:1200;   % 9 points, includes 1000 nm baseline exactly

R = struct('hs_length', {}, 'peak_force', {}, 'pct_shortening', {}, ...
           'relax_half_time', {}, 'srx_baseline', {}, 'srx_at_peak', {}, ...
           'drx_baseline', {}, 'drx_at_peak', {});

fprintf('Baseline hs_length (from model_best.json) = %.1f nm\n\n', hsl_baseline);

for i = 1:numel(lengths)
    L = lengths(i);
    fprintf('Running hs_length = %d nm ...\n', L);

    model = model_best;
    model.MyoSim_model.hs_props.hs_length = L;
    savejson('', model, tmp_model);

    out = run_one(tmp_model, protocol_file, options_file, ca_onset);

    R(end+1) = struct( ...      %#ok<AGROW>
        'hs_length',        L, ...
        'peak_force',       out.peak_force, ...
        'pct_shortening',   out.pct_shortening, ...
        'relax_half_time',  out.relax_half_time, ...
        'srx_baseline',     out.srx_baseline, ...
        'srx_at_peak',      out.srx_at_peak, ...
        'drx_baseline',     out.drx_baseline, ...
        'drx_at_peak',      out.drx_at_peak);

    fprintf('  peak=%.1f N/m^2  shortening=%.2f%%  relax_half=%.4g s  SRX %.3f->%.3f  DRX %.3f->%.3f\n', ...
        out.peak_force, out.pct_shortening, out.relax_half_time, ...
        out.srx_baseline, out.srx_at_peak, out.drx_baseline, out.drx_at_peak);
end

% ---- CSV ----
T = struct2table(R);
csv_path = fullfile('temp', 'sweeps', 'length_sweep.csv');
writetable(T, csv_path);
fprintf('\nSaved %s\n', csv_path);

% ---- plot ----
fig = figure('Color', 'w', 'Position', [40 40 1100 800], 'Name', 'Length sweep');

subplot(2, 2, 1);
plot([R.hs_length], [R.peak_force], 'o-', 'LineWidth', 2, ...
     'MarkerFaceColor', [0.15 0.55 0.55], 'Color', [0.15 0.55 0.55]);
xline(hsl_baseline, '--', 'baseline', 'HandleVisibility', 'off');
xlabel('Operating length (nm)'); ylabel('Peak force (N/m^2)');
title('Length-tension curve'); box off; grid on;

subplot(2, 2, 2);
plot([R.hs_length], [R.pct_shortening], 's-', 'LineWidth', 2, ...
     'MarkerFaceColor', [0.8 0.3 0.2], 'Color', [0.8 0.3 0.2]);
xline(hsl_baseline, '--', 'baseline', 'HandleVisibility', 'off');
xlabel('Operating length (nm)'); ylabel('% shortening');
title('Sarcomere shortening'); box off; grid on;

subplot(2, 2, 3);
plot([R.hs_length], [R.relax_half_time], '^-', 'LineWidth', 2, ...
     'MarkerFaceColor', [0.4 0.4 0.7], 'Color', [0.4 0.4 0.7]);
xline(hsl_baseline, '--', 'baseline', 'HandleVisibility', 'off');
xlabel('Operating length (nm)'); ylabel('Relaxation half-time (s)');
title('Relaxation kinetics'); box off; grid on;

subplot(2, 2, 4);
hold on;
plot([R.hs_length], [R.srx_baseline], 'o--', 'Color', [0.15 0.55 0.55], 'LineWidth', 1.5);
plot([R.hs_length], [R.srx_at_peak],  'o-',  'Color', [0.15 0.55 0.55], 'LineWidth', 2);
plot([R.hs_length], [R.drx_baseline], 's--', 'Color', [0.8 0.3 0.2], 'LineWidth', 1.5);
plot([R.hs_length], [R.drx_at_peak],  's-',  'Color', [0.8 0.3 0.2], 'LineWidth', 2);
xline(hsl_baseline, '--', 'baseline', 'HandleVisibility', 'off');
legend({'SRX baseline','SRX at peak','DRX baseline','DRX at peak'}, 'Location', 'best');
xlabel('Operating length (nm)'); ylabel('Fraction');
title('SRX/DRX recruitment'); box off; grid on;

sgtitle(sprintf('Length sweep: %s', strrep(demo_dir_leaf(demo_dir), '_', '\_')));
png_path = fullfile('temp', 'sweeps', 'length_sweep.png');
saveas(fig, png_path);
fprintf('Saved %s\n', png_path);
end

% ---------------------------------------------------------------------------
function m = run_one(model_file, protocol_file, options_file, ca_onset)
try
    s = simulation_driver( ...
        'model_json_file_string',          model_file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string',        options_file);
    f  = s.muscle_force(:);
    t  = s.time_s(:);
    hs = s.hs_length(:);
    m1 = s.M1(:, 1);
    m2 = s.M2(:, 1);

    hsl0 = hs(1);
    [pk, pidx] = max(f);
    baseline   = mean(f(1:min(300, numel(f))));
    half       = baseline + 0.5 * (pk - baseline);
    ridx       = find(f(pidx:end) <= half, 1, 'first');
    if isempty(ridx)
        t_half = NaN;
    else
        t_half = t(pidx + ridx - 1) - t(pidx);
    end

    m.peak_force      = pk;
    m.pct_shortening  = 100 * (hsl0 - min(hs)) / hsl0;
    m.relax_half_time = t_half;
    m.srx_baseline    = mean(m1(1:ca_onset));
    m.srx_at_peak     = m1(pidx);
    m.drx_baseline    = mean(m2(1:ca_onset));
    m.drx_at_peak     = m2(pidx);
catch err
    warning('run_one failed: %s', err.message);
    m.peak_force = NaN; m.pct_shortening = NaN; m.relax_half_time = NaN;
    m.srx_baseline = NaN; m.srx_at_peak = NaN; m.drx_baseline = NaN; m.drx_at_peak = NaN;
end
end

function leaf = demo_dir_leaf(p)
parts = strsplit(p, filesep);
parts = parts(~cellfun(@isempty, parts));
leaf  = parts{end};
end
