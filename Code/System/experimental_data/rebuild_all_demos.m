function rebuild_all_demos
% Rebuild Ca protocols and force targets for all HCM and control twitch demos.
%
% Data sources:
%   Force: "Updated cell trace data.xlsx"
%     col 1 (Time, Force)        = Control (Con_C4_D96_c48b)
%     col 2 (Time_1, Force_1)    = H251N HCM mutation
%   Ca transient: Ca_transients2.mat
%     col 1 = H251N (mutant)
%     col 2 = Control
%
% Protocol structure per demo:
%   0.5 s passive (pCa=8, dt=0.0005) + smooth Ca transient
%   Force target: 0.5 s of zeros + baseline-subtracted force
%
% Experimental time axis: t_exp = 0.353 to 1.474 s (36 points)
%   We treat t_exp(1) = Ca onset, so t_ca = t_exp - t_exp(1)

cd(fileparts(mfilename('fullpath')));

%% ---- Load force data ----
T = readtable('Updated cell trace data.xlsx');
t_exp    = T.Time;      % 36 pts, 0.353-1.474 s
f_con    = T.Force;     % Control force
f_h251n  = T.Force_1;  % H251N force

% Baseline-subtract (mean of first 3 points)
bl_con   = mean(f_con(1:3));
bl_h251n = mean(f_h251n(1:3));
f_con    = f_con    - bl_con;
f_h251n  = f_h251n - bl_h251n;
fprintf('Control baseline subtracted: %.2f N/m^2  (peak now %.1f)\n', bl_con, max(f_con));
fprintf('H251N   baseline subtracted: %.2f N/m^2  (peak now %.1f)\n', bl_h251n, max(f_h251n));

% Map experimental time to Ca-protocol time (t_exp(1) = Ca onset)
t_ca_exp = t_exp - t_exp(1);   % starts at 0

%% ---- Load Ca transients ----
ca_data = load('Ca_transients2.mat');
fn = fieldnames(ca_data); Ca = ca_data.(fn{1});  % 2056 x 2
pCa_h251n = Ca(:, 1);   % col 1 = H251N (mutant)
pCa_con   = Ca(:, 2);   % col 2 = Control
n_ca      = size(Ca, 1);
dt_val    = 0.0005;
t_ca_sim  = (1:n_ca)' * dt_val;   % 0.0005 to 1.028 s
fprintf('Ca transient: %d pts, dt=%.5f s, total=%.4f s\n', n_ca, dt_val, t_ca_sim(end));

%% ---- Build passive phase ----
n_passive    = 1000;   % 0.5 s at dt=0.0005
t_passive    = 0.5;    % seconds
passive_pCa  = 8.0 * ones(n_passive, 1);
passive_dt   = dt_val  * ones(n_passive, 1);
passive_dhsl = zeros(n_passive, 1);
passive_mode = -2      * ones(n_passive, 1);

%% ---- Interpolate force onto Ca-protocol time axis ----
interp_force = @(f_exp) interp1(t_ca_exp, f_exp, t_ca_sim, 'pchip', 'extrap');
f_con_sim   = interp_force(f_con);
f_h251n_sim = interp_force(f_h251n);

% Clamp extrapolation
f_con_sim(t_ca_sim < t_ca_exp(1))     = f_con(1);
f_con_sim(t_ca_sim > t_ca_exp(end))   = f_con(end);
f_h251n_sim(t_ca_sim < t_ca_exp(1))   = f_h251n(1);
f_h251n_sim(t_ca_sim > t_ca_exp(end)) = f_h251n(end);

target_con   = [zeros(n_passive,1); f_con_sim];
target_h251n = [zeros(n_passive,1); f_h251n_sim];
n_total = n_passive + n_ca;
fprintf('Protocol length: %d rows (passive=%d + Ca=%d)\n', n_total, n_passive, n_ca);
fprintf('Control  target: min=%.1f  max=%.1f\n', min(target_con), max(target_con));
fprintf('H251N    target: min=%.1f  max=%.1f\n', min(target_h251n), max(target_h251n));

%% ---- Write helper ----
    function write_protocol(path, pCa_ca)
        full_pCa  = [passive_pCa;  pCa_ca];
        full_dt   = [passive_dt;   dt_val*ones(n_ca,1)];
        full_dhsl = [passive_dhsl; zeros(n_ca,1)];
        full_mode = [passive_mode; -2*ones(n_ca,1)];
        fid = fopen(path, 'w');
        fprintf(fid, 'dt\tpCa\tdhsl\tMode\n');
        for r = 1:n_total
            fprintf(fid, '%.6f\t%.5f\t%d\t%d\n', ...
                full_dt(r), full_pCa(r), full_dhsl(r), full_mode(r));
        end
        fclose(fid);
    end

    function write_target(path, target)
        fid = fopen(path, 'w');
        fprintf(fid, '%f\n', target);
        fclose(fid);
    end

%% ---- Write to all demo folders ----
base = '/Users/tomtan/Research/MATMyoSim/code/demos/fitting';

demos_hcm = {'twitch_3state_HCM', 'twitch_4state_HCM', 'twitch_6state_HCM'};
demos_con = {'twitch_3state_control', 'twitch_4state_control', 'twitch_6state_control'};

for i = 1:numel(demos_hcm)
    sim_in  = fullfile(base, demos_hcm{i}, 'sim_input');
    tgt_dir = fullfile(base, demos_hcm{i}, 'target');
    if ~isfolder(sim_in),  mkdir(sim_in);  end
    if ~isfolder(tgt_dir), mkdir(tgt_dir); end
    write_protocol(fullfile(sim_in,  'ca_protocol.txt'),   pCa_h251n);
    write_target  (fullfile(tgt_dir, 'H251N_target.txt'),  target_h251n);
    fprintf('HCM   %s: wrote protocol + H251N target\n', demos_hcm{i});
end

for i = 1:numel(demos_con)
    if ~isfolder(fullfile(base, demos_con{i})), continue; end
    sim_in  = fullfile(base, demos_con{i}, 'sim_input');
    tgt_dir = fullfile(base, demos_con{i}, 'target');
    if ~isfolder(sim_in),  mkdir(sim_in);  end
    if ~isfolder(tgt_dir), mkdir(tgt_dir); end
    write_protocol(fullfile(sim_in,  'ca_protocol.txt'),  pCa_con);
    write_target  (fullfile(tgt_dir, 'Con_target.txt'),   target_con);
    fprintf('Ctrl  %s: wrote protocol + control target\n', demos_con{i});
end

fprintf('\nDONE\n');
end
