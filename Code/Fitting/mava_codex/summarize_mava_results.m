function summary = summarize_mava_results(out_dir)
% Summarize fitted parameters, waveform metrics, SRX, and fit overlays.

script_dir = fileparts(mfilename('fullpath'));
fitting_dir = fileparts(script_dir);
repo_root = fullfile(script_dir, '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

cases = struct( ...
    'run_id', {'ctrl_acute_r10','ctrl_acute_r20','hcm_acute_r10','hcm_acute_r20'}, ...
    'genotype', {'Control','Control','H251N','H251N'}, ...
    'ratio', {10,20,10,20}, ...
    'target_id', {'ctrl_acute','ctrl_acute','hcm_acute','hcm_acute'}, ...
    'demo', {'twitch_6state_control','twitch_6state_control', ...
             'twitch_6state_HCM','twitch_6state_HCM'});

n = numel(cases);
run_id = strings(n,1); genotype = strings(n,1); ratio = nan(n,1);
best_error = nan(n,1); aic = nan(n,1);
k_1 = nan(n,1); k_2 = nan(n,1); k_3 = nan(n,1); k_5_0 = nan(n,1);
k_1_fold = nan(n,1); k_3_fold = nan(n,1); k_5_0_fold = nan(n,1);
model_peak = nan(n,1); model_time_to_peak = nan(n,1);
model_relax_half_time = nan(n,1); srx_rest_total = nan(n,1);
srx_peak_total = nan(n,1); boundary_parameters = strings(n,1);

plot_data = repmat(struct('t',[],'target',[],'force',[]), n, 1);

for i = 1:n
    result_dir = fullfile(out_dir, 'results', cases(i).run_id);
    model_file = fullfile(result_dir, 'model_best.json');
    fit = loadjson(fullfile(result_dir, 'fit_results.json'));
    best_opt = loadjson(fullfile(result_dir, 'best_optimization.json'));
    opt = best_opt.MyoSim_optimization;
    model = loadjson(model_file);
    base_file = fullfile(fitting_dir, cases(i).demo, 'temp', 'best', 'model_best.json');
    base = loadjson(base_file);
    p = model.MyoSim_model.hs_props.parameters;
    p0 = base.MyoSim_model.hs_props.parameters;

    protocol = readtable(opt.job{1}.protocol_file_string, ...
        'FileType', 'text', 'Delimiter', '\t');
    target = load(opt.job{1}.target_file_string);
    sim = simulation_driver( ...
        'model_json_file_string', model_file, ...
        'simulation_protocol_file_string', opt.job{1}.protocol_file_string, ...
        'options_json_file_string', opt.job{1}.options_file_string);
    t = cumsum(protocol.dt) - protocol.dt(1);
    onset_idx = find(protocol.pCa < 6.70, 1, 'first');
    pre = max(1, onset_idx-50):(onset_idx-1);
    force = sim.muscle_force(:) - mean(sim.muscle_force(pre));
    m = model_metrics(t, force, sim, onset_idx);

    run_id(i) = cases(i).run_id;
    genotype(i) = cases(i).genotype;
    ratio(i) = cases(i).ratio;
    best_error(i) = fit.best_error;
    aic(i) = fit.aic;
    k_1(i) = p.k_1; k_2(i) = p.k_2; k_3(i) = p.k_3; k_5_0(i) = p.k_5_0;
    k_1_fold(i) = p.k_1 / p0.k_1;
    k_3_fold(i) = p.k_3 / p0.k_3;
    k_5_0_fold(i) = p.k_5_0 / p0.k_5_0;
    model_peak(i) = m.peak;
    model_time_to_peak(i) = m.time_to_peak;
    model_relax_half_time(i) = m.relax_half_time;
    srx_rest_total(i) = m.srx_rest_total;
    srx_peak_total(i) = m.srx_peak_total;
    boundary_parameters(i) = boundary_string(opt.parameter);
    plot_data(i).t = t;
    plot_data(i).target = target;
    plot_data(i).force = force;
end

summary = table(run_id, genotype, ratio, best_error, aic, ...
    k_1, k_2, k_3, k_5_0, k_1_fold, k_3_fold, k_5_0_fold, ...
    model_peak, model_time_to_peak, model_relax_half_time, ...
    srx_rest_total, srx_peak_total, boundary_parameters);
writetable(summary, fullfile(out_dir, 'fit_summary.csv'));

plot_fit_overlays(cases, plot_data, out_dir);
plot_experimental_traces(out_dir);
end

function m = model_metrics(t, force, sim, onset_idx)
active = onset_idx:numel(force);
[m.peak, rel_peak] = max(force(active));
peak_idx = active(rel_peak);
m.time_to_peak = t(peak_idx) - t(onset_idx);
half_idx = find(force(peak_idx:end) <= 0.5*m.peak, 1, 'first');
if isempty(half_idx)
    m.relax_half_time = NaN;
else
    m.relax_half_time = t(peak_idx + half_idx - 1) - t(peak_idx);
end
m.srx_rest_total = sim.M1(onset_idx-1,1) + sim.M6(onset_idx-1,1);
m.srx_peak_total = sim.M1(peak_idx,1) + sim.M6(peak_idx,1);
end

function s = boundary_string(parameters)
hits = strings(0);
for i = 1:numel(parameters)
    p = parameters{i}.p_value;
    if p <= 0.01
        hits(end+1) = string(parameters{i}.name) + " low"; %#ok<AGROW>
    elseif p >= 0.99
        hits(end+1) = string(parameters{i}.name) + " high"; %#ok<AGROW>
    end
end
if isempty(hits), s = "none"; else, s = strjoin(hits, '; '); end
end

function plot_fit_overlays(cases, data, out_dir)
fig = figure('Visible','off','Color','w','Position',[40 40 1100 760]);
for g = 1:2
    ax = subplot(2,1,g); hold(ax,'on');
    idx = find(strcmp({cases.genotype}, cases(2*g-1).genotype));
    plot(ax, data(idx(1)).t, data(idx(1)).target, 'k-', 'LineWidth', 2.2, ...
        'DisplayName', 'acute data');
    plot(ax, data(idx(1)).t, data(idx(1)).force, '-', 'LineWidth', 1.5, ...
        'Color', [0.12 0.47 0.71], 'DisplayName', 'fit: k_2=10k_1');
    plot(ax, data(idx(2)).t, data(idx(2)).force, '--', 'LineWidth', 1.7, ...
        'Color', [0.84 0.15 0.16], 'DisplayName', 'fit: k_2=20k_1');
    title(ax, [cases(idx(1)).genotype ' acute mavacamten']);
    xlabel(ax, 'time (s)'); ylabel(ax, 'force (N m^{-2})');
    grid(ax,'on'); box(ax,'off'); legend(ax,'Location','northeast');
end
sgtitle('Three-parameter mavacamten fits: k_1, k_3, k_{5,0}');
saveas(fig, fullfile(out_dir, 'mava_fit_overlays.png'));
close(fig);
end

function plot_experimental_traces(out_dir)
fig = figure('Visible','off','Color','w','Position',[40 40 1100 700]);
groups = {{'ctrl_before','ctrl_acute','ctrl_24h'}, ...
          {'hcm_before','hcm_acute','hcm_24h'}};
titles = {'Control','H251N'};
labels = {'Before','Acute mavacamten','24 h'};
colors = [0.12 0.47 0.71; 0.84 0.15 0.16; 0.20 0.63 0.17];
for g = 1:2
    ax = subplot(1,2,g); hold(ax,'on');
    for j = 1:3
        id = groups{g}{j};
        target = load(fullfile(out_dir, 'data', [id '_target.txt']));
        protocol = readtable(fullfile(out_dir, 'data', [id '_protocol.txt']), ...
            'FileType','text','Delimiter','\t');
        t = cumsum(protocol.dt) - protocol.dt(1);
        plot(ax, t, target, 'LineWidth', 1.8, 'Color', colors(j,:), ...
            'DisplayName', labels{j});
    end
    title(ax, titles{g}); xlabel(ax,'time (s)'); ylabel(ax,'force (N m^{-2})');
    grid(ax,'on'); box(ax,'off'); legend(ax,'Location','northeast');
end
sgtitle('Mavacamten traces (common scale within genotype; next beat removed)');
saveas(fig, fullfile(out_dir, 'mava_experimental_traces.png'));
close(fig);
end
