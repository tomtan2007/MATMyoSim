function result = mava_amplitude_timing_analysis(workbook_file, out_dir, levels, alignment_policy)
% Bounded k_1/k_3/k_5_0 grid scored against three scaling assumptions.

script_dir = fileparts(mfilename('fullpath'));
fitting_dir = fileparts(script_dir);
repo_root = fullfile(script_dir, '..', '..', '..');
if nargin < 1 || isempty(workbook_file)
    workbook_file = fullfile(repo_root, 'Code', 'System', ...
        'experimental_data', 'Mava data.xlsx');
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output', 'amplitude_timing');
end
if nargin < 3 || isempty(levels)
    levels = 10.^linspace(-1, 1, 5);
end
if nargin < 4 || isempty(alignment_policy)
    alignment_policy = 'shared_by_genotype';
end
if ~isfolder(out_dir), mkdir(out_dir); end

addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

scale_modes = {'peak','p95','least_squares'};
experimental = table;
for s = 1:numel(scale_modes)
    data_dir = fullfile(out_dir, ['data_' scale_modes{s}]);
    prepare_mava_data(workbook_file, data_dir, scale_modes{s}, alignment_policy);
    for g = 1:2
        if g == 1, genotype = "Control"; id = 'ctrl_acute';
        else, genotype = "H251N"; id = 'hcm_acute'; end
        target = load(fullfile(data_dir, [id '_target.txt']));
        protocol = readtable(fullfile(data_dir, [id '_protocol.txt']), ...
            'FileType','text','Delimiter','\t');
        t = cumsum(protocol.dt) - protocol.dt(1);
        onset = find(protocol.pCa < 6.70, 1, 'first');
        m = mava_waveform_metrics(t, target, onset, 'prezeroed');
        row = table(genotype, string(scale_modes{s}), m.peak, ...
            m.time_to_peak_centroid, m.relax_half_time, m.fwhm, ...
            'VariableNames', {'genotype','scale_mode','peak','time_to_peak', ...
            'relax_half_time','fwhm'});
        experimental = [experimental; row]; %#ok<AGROW>
    end
end
writetable(experimental, fullfile(out_dir, 'experimental_scaling_metrics.csv'));

cases = struct( ...
    'genotype', {'Control','H251N'}, ...
    'id', {'ctrl_acute','hcm_acute'}, ...
    'demo', {'twitch_6state_control','twitch_6state_HCM'});
ratios = [10 20];
grid = table;
tmp_model = fullfile(out_dir, 'grid_model.json');

for g = 1:numel(cases)
    demo_dir = fullfile(fitting_dir, cases(g).demo);
    base_file = fullfile(demo_dir, 'temp', 'best', 'model_best.json');
    options_file = fullfile(demo_dir, 'sim_input', 'sim_options.json');
    base = loadjson(base_file);
    p0 = base.MyoSim_model.hs_props.parameters;
    protocol_file = fullfile(out_dir, 'data_peak', ...
        [cases(g).id '_protocol.txt']);
    protocol = readtable(protocol_file, 'FileType','text','Delimiter','\t');
    t = cumsum(protocol.dt) - protocol.dt(1);
    onset = find(protocol.pCa < 6.70, 1, 'first');

    for ratio = ratios
        for a = 1:numel(levels)
            for b = 1:numel(levels)
                for c = 1:numel(levels)
                    model = base;
                    p = model.MyoSim_model.hs_props.parameters;
                    p.k_1 = p0.k_1 * levels(a);
                    p.k_2 = ratio * p.k_1;
                    p.k_3 = p0.k_3 * levels(b);
                    p.k_5_0 = p0.k_5_0 * levels(c);
                    model.MyoSim_model.hs_props.parameters = p;
                    write_model(model, tmp_model);
                    sim = simulation_driver( ...
                        'model_json_file_string', tmp_model, ...
                        'simulation_protocol_file_string', protocol_file, ...
                        'options_json_file_string', options_file);
                    m = mava_waveform_metrics(t, sim.muscle_force, onset, 'model');
                    srx_rest = sim.M1(onset-1,1) + sim.M6(onset-1,1);
                    srx_peak = sim.M1(m.peak_index,1) + sim.M6(m.peak_index,1);
                    row = table(string(cases(g).genotype), ratio, ...
                        levels(a), levels(b), levels(c), p.k_1, p.k_2, ...
                        p.k_3, p.k_5_0, m.peak, m.time_to_peak_centroid, ...
                        m.relax_half_time, srx_rest, srx_peak, ...
                        'VariableNames', {'genotype','ratio','k_1_fold', ...
                        'k_3_fold','k_5_0_fold','k_1','k_2','k_3','k_5_0', ...
                        'peak','time_to_peak','relax_half_time','srx_rest','srx_peak'});
                    grid = [grid; row]; %#ok<AGROW>
                end
            end
        end
    end
end
writetable(grid, fullfile(out_dir, 'grid_metrics.csv'));

comparison = table;
for i = 1:height(grid)
    eidx = experimental.genotype == grid.genotype(i);
    E = experimental(eidx,:);
    for j = 1:height(E)
        peak_error = (grid.peak(i) - E.peak(j)) / E.peak(j);
        tpeak_error = (grid.time_to_peak(i) - E.time_to_peak(j)) / E.time_to_peak(j);
        relax_error = (grid.relax_half_time(i) - E.relax_half_time(j)) / E.relax_half_time(j);
        total_score = peak_error^2 + tpeak_error^2 + relax_error^2;
        row = [grid(i,:), table(E.scale_mode(j), E.peak(j), ...
            E.time_to_peak(j), E.relax_half_time(j), peak_error, ...
            tpeak_error, relax_error, total_score, ...
            'VariableNames', {'scale_mode','target_peak','target_time_to_peak', ...
            'target_relax_half_time','peak_error','tpeak_error', ...
            'relax_error','total_score'})];
        comparison = [comparison; row]; %#ok<AGROW>
    end
end
writetable(comparison, fullfile(out_dir, 'grid_comparison.csv'));

if numel(levels) > 1
    plot_tradeoffs(comparison, out_dir);
    plot_scaling(experimental, out_dir);
end
result.grid = grid;
result.experimental = experimental;
result.comparison = comparison;
end

function write_model(model, file)
fid = fopen(file, 'w');
if fid < 0, error('Could not write model: %s', file); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('MyoSim_model', model.MyoSim_model));
end

function plot_tradeoffs(C, out_dir)
fig = figure('Visible','off','Color','w','Position',[30 30 1150 850]);
genotypes = {'Control','H251N'}; ratios = [10 20];
for g = 1:2
    for r = 1:2
        ax = subplot(2,2,(g-1)*2+r); hold(ax,'on');
        idx = C.genotype == genotypes{g} & C.ratio == ratios(r) & ...
            C.scale_mode == "peak";
        D = C(idx,:);
        scatter(ax, 100*D.peak_error, 1000*(D.relax_half_time-D.target_relax_half_time), ...
            28, 1000*(D.time_to_peak-D.target_time_to_peak), 'filled');
        [~, best] = min(D.total_score);
        plot(ax, 100*D.peak_error(best), ...
            1000*(D.relax_half_time(best)-D.target_relax_half_time(best)), ...
            'kp','MarkerSize',13,'MarkerFaceColor','y');
        xline(ax,0,':k'); yline(ax,0,':k'); grid(ax,'on'); box(ax,'off');
        xlabel(ax,'peak-force error (%)'); ylabel(ax,'relaxation error (ms)');
        title(ax,sprintf('%s, k_2=%dk_1',genotypes{g},ratios(r)));
        cb = colorbar(ax); ylabel(cb,'time-to-peak error (ms)');
    end
end
sgtitle('Bounded k_1/k_3/k_{5,0} grid: amplitude versus timing');
saveas(fig, fullfile(out_dir, 'amplitude_timing_tradeoff.png'));
close(fig);
end

function plot_scaling(E, out_dir)
fig = figure('Visible','off','Color','w','Position',[30 30 1050 650]);
genotypes = {'Control','H251N'};
for g = 1:2
    D = E(E.genotype == genotypes{g},:);
    subplot(1,2,g);
    yyaxis left; bar(categorical(D.scale_mode), D.peak); ylabel('peak force (N m^{-2})');
    yyaxis right; plot(categorical(D.scale_mode), 1000*D.relax_half_time, ...
        'ko-','LineWidth',1.5); ylabel('relaxation half-time (ms)');
    title(genotypes{g}); grid on; box off;
end
sgtitle('Experimental metrics under alternative scaling assumptions');
saveas(fig, fullfile(out_dir, 'scaling_sensitivity.png'));
close(fig);
end
