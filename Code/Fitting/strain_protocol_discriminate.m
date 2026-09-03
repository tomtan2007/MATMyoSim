function strain_protocol_discriminate()
% Priority-3 exploratory check: does the length-step/strain protocol
% (protocol_1s_strain.txt, real dhsl trajectory, ~1.8s) produce visibly
% different force-length responses for two near-equal-twitch-error HCM
% parameter sets that disagree on k_1/k_5_0/k_4_0 (the non-identifiable
% basins found by the reduced multistart)?
%
% Candidates taken directly from
% twitch_6state_HCM/temp/multistart_reduced/ms_A.csv (read-only):
%   restart 3: e=0.009926  k_1=100.0   k_5_0=1168.65  k_4_0=7.364
%   restart 9: e=0.006803  k_1=5.873   k_5_0=857.09   k_4_0=5.818
% Both fit the HCM twitch almost equally well but disagree ~17x on k_1.
% If they predict clearly different force-length loops on the strain
% protocol, that protocol could break the degeneracy; if the loops are
% ~identical, this data source does not discriminate between the
% candidate basins either.

repo_root = fileparts(mfilename('fullpath'));
code_root = fileparts(repo_root);
addpath(genpath(code_root));
addpath(genpath(fullfile(code_root, 'System')));

hcm_dir = fullfile(repo_root, 'twitch_6state_HCM');
base_template = loadjson(fullfile(hcm_dir, 'sim_input', 'model_template_reduced.json'));

candidates(1).label = 'basin_A (k1=100)';
candidates(1).k_1 = 100.0;   candidates(1).k_5_0 = 1168.65; candidates(1).k_4_0 = 7.364;
candidates(2).label = 'basin_B (k1=5.87)';
candidates(2).k_1 = 5.873;   candidates(2).k_5_0 = 857.09;  candidates(2).k_4_0 = 5.818;

outdir = fullfile(repo_root, 'temp_strain_discriminate');
if ~isfolder(outdir), mkdir(outdir); end

protocol = fullfile(repo_root, '..', 'System', 'protocols', 'protocol_1s_strain.txt');
options_file = fullfile(hcm_dir, 'sim_input', 'sim_options.json');

sims = cell(1, numel(candidates));
for c = 1:numel(candidates)
    m = base_template;
    m.MyoSim_model.hs_props.parameters.k_1   = candidates(c).k_1;
    m.MyoSim_model.hs_props.parameters.k_2   = 10 * candidates(c).k_1;
    m.MyoSim_model.hs_props.parameters.k_5_0 = candidates(c).k_5_0;
    m.MyoSim_model.hs_props.parameters.k_4_0 = candidates(c).k_4_0;

    model_file = fullfile(outdir, sprintf('model_%d.json', c));
    out_string = strrep(savejson('MyoSim_model', m.MyoSim_model), '\/', '/');
    of = fopen(model_file, 'w'); fprintf(of, '%s', out_string); fclose(of);

    fprintf('Running %s on strain protocol...\n', candidates(c).label);
    sims{c} = simulation_driver('model_json_file_string', model_file, ...
        'simulation_protocol_file_string', protocol, ...
        'options_json_file_string', options_file);
end

fig = figure('Color', 'w', 'Position', [100 100 1000 400]);
subplot(1,2,1); hold on;
for c = 1:numel(candidates)
    plot(sims{c}.time_s, sims{c}.muscle_force, 'DisplayName', candidates(c).label);
end
xlabel('time (s)'); ylabel('muscle force (N/m^2)'); legend; title('Force vs time (strain protocol)');

subplot(1,2,2); hold on;
for c = 1:numel(candidates)
    plot(sims{c}.hs_length, sims{c}.muscle_force, 'DisplayName', candidates(c).label);
end
xlabel('hs length (nm)'); ylabel('muscle force (N/m^2)'); legend; title('Force-length loop');

saveas(fig, fullfile(outdir, 'strain_discriminate.png'));
fprintf('Saved %s\n', fullfile(outdir, 'strain_discriminate.png'));

% Quantify: max abs force difference and RMS difference over common time base
f1 = sims{1}.muscle_force(:); f2 = sims{2}.muscle_force(:);
n = min(numel(f1), numel(f2));
fprintf('Max |force diff| = %.2f N/m^2 (basin_A range %.0f-%.0f)\n', ...
    max(abs(f1(1:n)-f2(1:n))), min(f1), max(f1));
fprintf('RMS force diff   = %.2f N/m^2\n', sqrt(mean((f1(1:n)-f2(1:n)).^2)));
end
