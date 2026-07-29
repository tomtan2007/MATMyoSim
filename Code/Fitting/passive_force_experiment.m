function passive_force_experiment()
% PASSIVE_FORCE_EXPERIMENT  Linear vs exponential passive force on the twitch.
%
% Uses the 6-state control best-fit model. Writes scratch model JSONs to
% temp/scratch/ (never touches temp/best/model_best.json). Runs the twitch
% under a matrix of passive settings and reports, for each:
%   passive baseline force, peak force, and relaxation half-time.
%
% Two slack conditions are tested:
%   (A) slack = 1265 nm  (= operating hs_length; passive ~engaged only via
%                          series compliance during shortening)
%   (B) slack = 1200 nm  (operating length 65 nm ABOVE slack; passive
%                          element pre-stretched so the linear-vs-exp shape
%                          difference is actually exercised = "rubber band")
%
% Canonical exponential params from original MATMyoSim ramp_2 demo:
%   passive_sigma = 100 N/m^2, passive_L = 25 nm.

script_dir = fileparts(mfilename('fullpath'));
repo_root  = fullfile(script_dir, '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));   % beat worktree shadow

demo_dir = fullfile(script_dir, 'twitch_6state_control');
cd(demo_dir);

base_model    = loadjson(fullfile('temp', 'best', 'model_best.json'));
opt           = loadjson(fullfile('sim_input', 'optimization.json'));
job           = opt.MyoSim_optimization.job{1};
protocol_file = job.protocol_file_string;
options_file  = job.options_file_string;

scratch = fullfile('temp', 'scratch');
if ~isfolder(scratch), mkdir(scratch); end

% scenario matrix: {label, mode, slack, k_linear, sigma, L}
S = {
 'linear   slack=1265 (baseline)', 'linear',       1265, 14, NaN, NaN
 'exp      slack=1265 s=100 L=25', 'exponential',  1265, NaN, 100, 25
 'linear   slack=1200 (stretch)',  'linear',       1200, 14, NaN, NaN
 'exp      slack=1200 s=100 L=25', 'exponential',  1200, NaN, 100, 25
 'exp      slack=1200 s=100 L=10', 'exponential',  1200, NaN, 100, 10
 'exp      slack=1200 s=50  L=25', 'exponential',  1200, NaN, 50,  25
 'exp      slack=1200 s=200 L=25', 'exponential',  1200, NaN, 200, 25
};

fprintf('\n%-34s %10s %10s %10s %10s\n', ...
        'scenario', 'baseline', 'peak', 'net_peak', 'relax_half');
fprintf('%s\n', repmat('-', 1, 80));

rows = {};
for i = 1:size(S,1)
    m = base_model;
    P = m.MyoSim_model.hs_props.parameters;
    P.passive_force_mode  = S{i,2};
    P.passive_hsl_slack   = S{i,3};
    if strcmp(S{i,2}, 'linear')
        P.passive_k_linear = S{i,4};
    else
        P.passive_sigma = S{i,5};
        P.passive_L     = S{i,6};
    end
    m.MyoSim_model.hs_props.parameters = P;

    f = fullfile(scratch, sprintf('passive_scn_%d.json', i));
    savejson('', m, f);
    r = run_twitch(f, protocol_file, options_file);

    fprintf('%-34s %10.1f %10.1f %10.1f %10.4f\n', ...
            S{i,1}, r.baseline, r.peak, r.peak - r.baseline, r.t_half);
    rows(end+1,:) = {S{i,1}, r.baseline, r.peak, r.peak - r.baseline, r.t_half}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', ...
    {'scenario','baseline','peak','net_peak','relax_half'});
csv = fullfile(scratch, 'passive_experiment.csv');
writetable(T, csv);
fprintf('\nSaved %s\n', csv);
disp('PASSIVE_DONE');
end

% ---------------------------------------------------------------------------
function r = run_twitch(model_file, protocol_file, options_file)
try
    s = simulation_driver( ...
        'model_json_file_string',          model_file, ...
        'simulation_protocol_file_string', protocol_file, ...
        'options_json_file_string',        options_file);
    f = s.muscle_force(:);
    t = s.time_s(:);
    n_pre    = min(300, numel(f));
    baseline = mean(f(1:n_pre));
    [pk, pidx] = max(f);
    half = baseline + 0.5 * (pk - baseline);
    ridx = find(f(pidx:end) <= half, 1, 'first');
    if isempty(ridx), t_half = NaN; else, t_half = t(pidx+ridx-1) - t(pidx); end
    r.baseline = baseline; r.peak = pk; r.t_half = t_half;
catch e
    fprintf('   (sim failed: %s)\n', e.message);
    r.baseline = NaN; r.peak = NaN; r.t_half = NaN;
end
end
