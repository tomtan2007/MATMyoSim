function result = mava_extended_sensitivity(workbook_file, out_dir, levels, parameter_names, alignment_policy)
% Screen individual kinetic and calcium parameters against Mava waveforms.

script_dir = fileparts(mfilename('fullpath'));
fitting_dir = fileparts(script_dir);
repo_root = fullfile(script_dir, '..', '..', '..');
if nargin < 1 || isempty(workbook_file)
    workbook_file = fullfile(repo_root, 'Code', 'System', ...
        'experimental_data', 'Mava data.xlsx');
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output', 'extended_sensitivity');
end
if nargin < 3 || isempty(levels)
    levels = 10.^linspace(-1, 1, 7);
end
if nargin < 4 || isempty(parameter_names)
    parameter_names = {'k_1','k_3','k_5_0','k_4_0','k_7_1', ...
        'k_7_2','k_7_3','k_force','k_on','k_off','k_coop'};
end
if nargin < 5 || isempty(alignment_policy)
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
        experimental = [experimental; table(genotype, string(scale_modes{s}), ...
            m.peak, m.time_to_peak_centroid, m.relax_half_time, m.fwhm, ...
            'VariableNames', {'genotype','scale_mode','peak','time_to_peak', ...
            'relax_half_time','fwhm'})]; %#ok<AGROW>
    end
end

cases = struct('genotype', {'Control','H251N'}, ...
    'id', {'ctrl_acute','hcm_acute'}, ...
    'demo', {'twitch_6state_control','twitch_6state_HCM'});
ratios = [10 20];
screen = table;
tmp_model = fullfile(out_dir, 'screen_model.json');

for g = 1:numel(cases)
    demo_dir = fullfile(fitting_dir, cases(g).demo);
    base = loadjson(fullfile(demo_dir, 'temp', 'best', 'model_best.json'));
    p0 = base.MyoSim_model.hs_props.parameters;
    options_file = fullfile(demo_dir, 'sim_input', 'sim_options.json');
    protocol_file = fullfile(out_dir, 'data_peak', ...
        [cases(g).id '_protocol.txt']);
    protocol = readtable(protocol_file, 'FileType','text','Delimiter','\t');
    t = cumsum(protocol.dt) - protocol.dt(1);
    onset = find(protocol.pCa < 6.70, 1, 'first');

    for ratio = ratios
        for q = 1:numel(parameter_names)
            name = parameter_names{q};
            if ~isfield(p0, name)
                error('mava_extended_sensitivity:unknownParameter', ...
                    'Parameter %s is absent from %s.', name, cases(g).demo);
            end
            for z = 1:numel(levels)
                model = base;
                p = model.MyoSim_model.hs_props.parameters;
                p.(name) = p0.(name) * levels(z);
                p.k_2 = ratio * p.k_1;
                model.MyoSim_model.hs_props.parameters = p;
                write_model(model, tmp_model);

                valid = true;
                peak = NaN; time_to_peak = NaN; relax_half_time = NaN;
                fwhm = NaN; srx_rest = NaN; srx_peak = NaN;
                try
                    sim = simulation_driver( ...
                        'model_json_file_string', tmp_model, ...
                        'simulation_protocol_file_string', protocol_file, ...
                        'options_json_file_string', options_file);
                    m = mava_waveform_metrics(t, sim.muscle_force, onset, 'model');
                    peak = m.peak;
                    time_to_peak = m.time_to_peak_centroid;
                    relax_half_time = m.relax_half_time;
                    fwhm = m.fwhm;
                    srx_rest = sim.M1(onset-1,1) + sim.M6(onset-1,1);
                    srx_peak = sim.M1(m.peak_index,1) + sim.M6(m.peak_index,1);
                    valid = all(isfinite([peak,time_to_peak,relax_half_time, ...
                        fwhm,srx_rest,srx_peak])) && peak > 0 && ...
                        srx_rest >= 0 && srx_rest <= 1 && ...
                        srx_peak >= 0 && srx_peak <= 1;
                catch
                    valid = false;
                end
                row = table(string(cases(g).genotype), ratio, string(name), ...
                    levels(z), p.(name), valid, peak, time_to_peak, ...
                    relax_half_time, fwhm, srx_rest, srx_peak, ...
                    'VariableNames', {'genotype','ratio','parameter','fold', ...
                    'value','valid','peak','time_to_peak','relax_half_time', ...
                    'fwhm','srx_rest','srx_peak'});
                screen = [screen; row]; %#ok<AGROW>
            end
        end
    end
end
writetable(screen, fullfile(out_dir, 'extended_screen.csv'));

comparison = table;
for i = 1:height(screen)
    E = experimental(experimental.genotype == screen.genotype(i),:);
    for j = 1:height(E)
        if screen.valid(i)
            peak_error = (screen.peak(i)-E.peak(j))/E.peak(j);
            tpeak_error = (screen.time_to_peak(i)-E.time_to_peak(j))/E.time_to_peak(j);
            relax_error = (screen.relax_half_time(i)-E.relax_half_time(j))/E.relax_half_time(j);
            total_score = peak_error^2 + tpeak_error^2 + relax_error^2;
        else
            peak_error = NaN; tpeak_error = NaN; relax_error = NaN;
            total_score = Inf;
        end
        comparison = [comparison; [screen(i,:), table(E.scale_mode(j), ...
            E.peak(j), E.time_to_peak(j), E.relax_half_time(j), ...
            peak_error, tpeak_error, relax_error, total_score, ...
            'VariableNames', {'scale_mode','target_peak','target_time_to_peak', ...
            'target_relax_half_time','peak_error','tpeak_error', ...
            'relax_error','total_score'})]]; %#ok<AGROW>
    end
end
writetable(comparison, fullfile(out_dir, 'extended_comparison.csv'));

effects = summarize_effects(screen, experimental);
writetable(effects, fullfile(out_dir, 'parameter_effects.csv'));
result.screen = screen;
result.experimental = experimental;
result.comparison = comparison;
result.effects = effects;
end

function effects = summarize_effects(screen, experimental)
effects = table;
groups = unique(screen(:,{'genotype','ratio','parameter'}),'rows');
for i = 1:height(groups)
    idx = screen.genotype == groups.genotype(i) & ...
        screen.ratio == groups.ratio(i) & ...
        screen.parameter == groups.parameter(i) & screen.valid;
    D = screen(idx,:);
    E = experimental(experimental.genotype == groups.genotype(i) & ...
        experimental.scale_mode == "peak",:);
    if isempty(D)
        peak_span = NaN; tpeak_span = NaN; relax_span = NaN;
        srx_span = NaN; best_score = Inf; best_fold = NaN;
    else
        peak_span = (max(D.peak)-min(D.peak))/E.peak;
        tpeak_span = (max(D.time_to_peak)-min(D.time_to_peak))/E.time_to_peak;
        relax_span = (max(D.relax_half_time)-min(D.relax_half_time))/E.relax_half_time;
        srx_span = max(D.srx_peak)-min(D.srx_peak);
        scores = ((D.peak-E.peak)/E.peak).^2 + ...
            ((D.time_to_peak-E.time_to_peak)/E.time_to_peak).^2 + ...
            ((D.relax_half_time-E.relax_half_time)/E.relax_half_time).^2;
        [best_score, b] = min(scores);
        best_fold = D.fold(b);
    end
    effects = [effects; table(groups.genotype(i), groups.ratio(i), ...
        groups.parameter(i), height(D), peak_span, tpeak_span, relax_span, ...
        srx_span, best_score, best_fold, ...
        'VariableNames', {'genotype','ratio','parameter','valid_count', ...
        'peak_span','tpeak_span','relax_span','srx_span', ...
        'best_score','best_fold'})]; %#ok<AGROW>
end
effects = sortrows(effects, {'genotype','ratio','best_score'});
end

function write_model(model, file)
fid = fopen(file, 'w');
if fid < 0, error('Could not write model: %s', file); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', savejson('MyoSim_model', model.MyoSim_model));
end
