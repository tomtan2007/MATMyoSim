function k71_shape_analysis()
% K71_SHAPE_ANALYSIS  Deep-dive on k_7_1 (strain-dependent detachment
% sensitivity) in the 6-state model, control and HCM.
%
% r7 = k_7_0 * exp(-(k_cb * x * k_7_1)/(1e18*kB*T))  (per x-bin, capped at max_rate)
%   +x (force-bearing) heads: larger k_7_1 -> slower detachment (more force)
%   -x heads:                 larger k_7_1 -> explosively faster detachment
%
% Produces, per condition:
%   1. FINE sweep of k_7_1 (18 log pts, 0.1x..10x best): peak, net-peak,
%      relaxation half-time -> locate the "cliff".
%   2. Three representative k_7_1 (below-opt, best, past-cliff): overlaid
%      force waveforms and attached-population (M3+M4) waveforms.
%   3. r7-vs-x profile at the 3 values + count of x-bins pinned at max_rate.
%
% Figures + CSVs written to twitch_6state_<cond>/temp/sweeps/.

script_dir = fileparts(mfilename('fullpath'));
repo_root  = fullfile(script_dir, '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

conds = {'twitch_6state_control', 'twitch_6state_HCM'};
for c = 1:numel(conds)
    analyse_one(fullfile(script_dir, conds{c}), conds{c});
end
disp('K71_DONE');
end

% ---------------------------------------------------------------------------
function analyse_one(demo_dir, tag)
cd(demo_dir);
model_best    = loadjson(fullfile('temp', 'best', 'model_best.json'));
opt           = loadjson(fullfile('sim_input', 'optimization.json'));
job           = opt.MyoSim_optimization.job{1};
protocol_file = job.protocol_file_string;
options_file  = job.options_file_string;
if ~isfolder(fullfile('temp','sweeps')), mkdir(fullfile('temp','sweeps')); end
if ~isfolder(fullfile('temp','scratch')), mkdir(fullfile('temp','scratch')); end
tmp = fullfile('temp','scratch','k71_model.json');

P    = model_best.MyoSim_model.hs_props.parameters;
best = P.k_7_1;
fprintf('\n=== %s : k_7_1 best = %.4g ===\n', tag, best);

% ---- 1. fine log sweep ----
mult = logspace(-1, 1, 18);
vals = best * mult;
peak = nan(size(vals)); netpk = nan(size(vals)); thalf = nan(size(vals));
for i = 1:numel(vals)
    m = model_best;
    m.MyoSim_model.hs_props.parameters.k_7_1 = vals(i);
    savejson('', m, tmp);
    r = run_full(tmp, protocol_file, options_file);
    peak(i)  = r.peak; netpk(i) = r.netpeak; thalf(i) = r.t_half;
end
[~, imax] = max(netpk);
fprintf('net-peak max at k_7_1=%.4g (%.2fx best); best sits at %.2fx of that\n', ...
        vals(imax), vals(imax)/best, best/vals(imax));

T1 = table(vals(:), mult(:), peak(:), netpk(:), thalf(:), ...
     'VariableNames', {'k_7_1','mult_of_best','peak','net_peak','relax_half'});
writetable(T1, fullfile('temp','sweeps','k71_fine_sweep.csv'));

fig1 = figure('Color','w','Position',[40 40 900 380]);
subplot(1,2,1);
semilogx(vals, netpk, 'o-','LineWidth',1.5,'Color',[0.15 0.55 0.55]); hold on;
xline(best,'k--','best'); xline(vals(imax),'r:','opt');
xlabel('k\_7\_1'); ylabel('net peak force (N/m^2)');
title('Peak vs k\_7\_1 (cliff)'); grid on;
subplot(1,2,2);
semilogx(vals, thalf*1000,'o-','LineWidth',1.5,'Color',[0.75 0.35 0.15]); hold on;
xline(best,'k--','best');
xlabel('k\_7\_1'); ylabel('relaxation half-time (ms)');
title('Relaxation vs k\_7\_1'); grid on;
sgtitle(sprintf('%s : k\\_7\\_1 fine sweep', strrep(tag,'_','\_')));
saveas(fig1, fullfile('temp','sweeps','k71_fine_sweep.png'));

% ---- 2 & 3. three representative values ----
reps = [0.3*best, best, 10*best];      % below-opt, best, past-cliff
lbl  = {sprintf('0.3x (%.3g)',reps(1)), sprintf('best (%.3g)',reps(2)), ...
        sprintf('10x (%.3g)',reps(3))};
cols = [0.20 0.45 0.80; 0.10 0.55 0.30; 0.80 0.20 0.20];

fig2 = figure('Color','w','Position',[40 40 1000 400]);
ax1 = subplot(1,2,1); hold(ax1,'on');
ax2 = subplot(1,2,2); hold(ax2,'on');
for k = 1:3
    m = model_best;
    m.MyoSim_model.hs_props.parameters.k_7_1 = reps(k);
    savejson('', m, tmp);
    r = run_full(tmp, protocol_file, options_file);
    plot(ax1, r.t, r.force, 'LineWidth',1.5,'Color',cols(k,:));
    plot(ax2, r.t, r.attached, 'LineWidth',1.5,'Color',cols(k,:));
    % r7 profile across x-bins
    r7 = compute_r7(P, reps(k), r.xbins);
    n_cap = sum(r7 >= P.max_rate - 1e-6);
    fprintf('  k_7_1=%.4g: peak=%.1f netpk=%.1f thalf=%.4f  r7_bins_capped=%d/%d (max r7=%.0f)\n', ...
            reps(k), r.peak, r.netpeak, r.t_half, n_cap, numel(r7), max(r7));
end
xlabel(ax1,'time (s)'); ylabel(ax1,'muscle force (N/m^2)');
title(ax1,'Force waveform'); grid(ax1,'on'); legend(ax1,lbl,'Location','best');
xlabel(ax2,'time (s)'); ylabel(ax2,'attached pop (M3+M4)');
title(ax2,'Attached population'); grid(ax2,'on'); legend(ax2,lbl,'Location','best');
sgtitle(sprintf('%s : waveforms at 3 k\\_7\\_1 values', strrep(tag,'_','\_')));
saveas(fig2, fullfile('temp','sweeps','k71_waveforms.png'));

% r7-vs-x profile figure
fig3 = figure('Color','w','Position',[40 40 560 400]); hold on;
xb = linspace(-10,10,200);
for k = 1:3
    plot(xb, compute_r7(P, reps(k), xb), 'LineWidth',1.5,'Color',cols(k,:));
end
yline(P.max_rate,'k--','max\_rate cap');
xlabel('cb strain x (nm)'); ylabel('r7 detachment rate (s^{-1})');
set(gca,'YScale','log'); title(sprintf('%s : r7(x) vs k\\_7\\_1',strrep(tag,'_','\_')));
legend(lbl,'Location','best'); grid on;
saveas(fig3, fullfile('temp','sweeps','k71_r7_profile.png'));

fprintf('  saved k71_fine_sweep.png, k71_waveforms.png, k71_r7_profile.png\n');
end

% ---------------------------------------------------------------------------
function r7 = compute_r7(P, k_7_1, x)
den = 1e18 * P.k_boltzmann * P.temperature;
r7  = P.k_7_0 * exp(-(P.k_cb .* x .* k_7_1) ./ den);
r7(r7 > P.max_rate) = P.max_rate;
r7(r7 < 0) = 0;
end

function r = run_full(model_file, protocol_file, options_file)
try
    s = simulation_driver('model_json_file_string', model_file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string', options_file);
    f = s.muscle_force(:); t = s.time_s(:);
    n_pre = min(300, numel(f)); baseline = mean(f(1:n_pre));
    [pk, pidx] = max(f);
    half = baseline + 0.5*(pk-baseline);
    ridx = find(f(pidx:end) <= half, 1, 'first');
    if isempty(ridx), th = NaN; else, th = t(pidx+ridx-1)-t(pidx); end
    att = s.M3(:) + s.M4(:);          % attached states in 6-state
    r.t = t; r.force = f; r.attached = att;
    r.peak = pk; r.netpeak = pk - baseline; r.t_half = th;
    r.xbins = linspace(-10,10,200);
catch e
    fprintf('  sim failed: %s\n', e.message);
    r.t=NaN; r.force=NaN; r.attached=NaN; r.peak=NaN; r.netpeak=NaN;
    r.t_half=NaN; r.xbins=linspace(-10,10,200);
end
end
