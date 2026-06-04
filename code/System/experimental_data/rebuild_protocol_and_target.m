function rebuild_protocol_and_target
% Rebuild the Ca protocol and P710R target with PI's feedback:
%   1. Use smooth experimental Ca transient (NOT square wave)
%   2. Prepend 0.5 s passive phase (pCa=8) so force starts flat at 0
%   3. Baseline-subtract the experimental force so it starts at 0
%
% Outputs:
%   - sim_input/ca_protocol.txt for each of {3,4,6}-state HCM demos
%   - target/P710R_target.txt for each of {3,4,6}-state HCM demos

cd(fileparts(mfilename('fullpath')));

% ---- Load experimental P710R force trace + time axis ----
d_time = load('cell_time_trace.mat');
fn = fieldnames(d_time); t_exp = d_time.(fn{1});  % e.g. 34 points spanning ~1.0 s

d_force = load('P710R_c32_force.mat');
fn2 = fieldnames(d_force); f_exp = d_force.(fn2{1});

% Baseline-subtract so the trace starts at 0
f_baseline = mean(f_exp(1:3));
f_exp = f_exp - f_baseline;
fprintf('Subtracted baseline = %.2f N/m^2 from P710R force\n', f_baseline);
fprintf('P710R force after baseline-sub: min=%.1f max=%.1f\n', min(f_exp), max(f_exp));

% ---- Load smooth experimental Ca transient ----
ca_tbl = readtable('../protocols/protocol_exp_P710R.txt');
ca_dt   = ca_tbl.dt;
ca_pCa  = ca_tbl.pCa;
ca_dhsl = ca_tbl.dhsl;
ca_mode = ca_tbl.Mode;
n_ca_rows = numel(ca_dt);
dt_val = ca_dt(1);  % uniform
fprintf('Loaded experimental Ca transient: %d rows, dt=%.5f s, total=%.4f s\n', ...
        n_ca_rows, dt_val, n_ca_rows*dt_val);

% ---- Build hybrid protocol ----
% Passive: 0.5 s of pCa=8 (no Ca) before the smooth Ca transient
t_passive = 0.5;
n_passive = round(t_passive / dt_val);  % at dt=0.0005 -> 1000 rows

passive_dt   = dt_val * ones(n_passive, 1);
passive_pCa  = 8.0 * ones(n_passive, 1);
passive_dhsl = zeros(n_passive, 1);
passive_mode = -2 * ones(n_passive, 1);

full_dt   = [passive_dt;   ca_dt];
full_pCa  = [passive_pCa;  ca_pCa];
full_dhsl = [passive_dhsl; ca_dhsl];
full_mode = [passive_mode; ca_mode];
n_total = numel(full_dt);

fprintf('Hybrid protocol: %d total rows = %d passive + %d Ca transient\n', ...
        n_total, n_passive, n_ca_rows);
fprintf('Total duration: %.4f s\n', n_total * dt_val);

% ---- Build matching target ----
% Passive section: zeros (PI: "start at 0 force")
target_passive = zeros(n_passive, 1);

% Ca transient section: interpolate baseline-subtracted force onto Ca timeline
t_ca = (1:n_ca_rows)' * dt_val;  % time relative to Ca onset
f_interp = interp1(t_exp, f_exp, t_ca, 'pchip', 'extrap');
f_interp(t_ca < t_exp(1))   = f_exp(1);
f_interp(t_ca > t_exp(end)) = f_exp(end);

target = [target_passive; f_interp];
fprintf('Target: %d total = %d zeros + %d force values\n', ...
        numel(target), n_passive, numel(f_interp));
fprintf('Target force: min=%.1f max=%.1f\n', min(target), max(target));

% ---- Write to all three HCM demo folders ----
demos = {'twitch_3state_HCM', 'twitch_4state_HCM', 'twitch_6state_HCM'};
base  = '/Users/tomtan/Research/MATMyoSim/code/demos/fitting';

for i = 1:numel(demos)
    sim_in = fullfile(base, demos{i}, 'sim_input');
    tgt_dir = fullfile(base, demos{i}, 'target');
    if ~isfolder(sim_in), mkdir(sim_in); end
    if ~isfolder(tgt_dir), mkdir(tgt_dir); end

    % Protocol file (column order: dt, pCa, dhsl, Mode — same as old ca_protocol.txt)
    proto_path = fullfile(sim_in, 'ca_protocol.txt');
    fid = fopen(proto_path, 'w');
    fprintf(fid, 'dt\tpCa\tdhsl\tMode\n');
    for r = 1:n_total
        fprintf(fid, '%.6f\t%.5f\t%d\t%d\n', full_dt(r), full_pCa(r), full_dhsl(r), full_mode(r));
    end
    fclose(fid);
    fprintf('Wrote: %s\n', proto_path);

    % Target file
    tgt_path = fullfile(tgt_dir, 'P710R_target.txt');
    fid = fopen(tgt_path, 'w');
    fprintf(fid, '%f\n', target);
    fclose(fid);
    fprintf('Wrote: %s\n', tgt_path);
end

fprintf('\nDONE\n');
end
