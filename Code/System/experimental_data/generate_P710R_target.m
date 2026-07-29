function generate_P710R_target
% Generate P710R target file for 6-state HCM fitting.
% Interpolates 34-point experimental data to match the ca_protocol timeline.

cd(fileparts(mfilename('fullpath')));

% Load experimental data
d_time = load('cell_time_trace.mat');
fn = fieldnames(d_time); t_exp = d_time.(fn{1});  % 34 points, 0.029-1.0s

d_force = load('P710R_c32_force.mat');
fn2 = fieldnames(d_force); f_exp = d_force.(fn2{1});  % 34 points

% Load ca_protocol to build cumulative simulation time vector (has header row)
ca_proto = importdata('/Users/tomtan/Research/MATMyoSim/code/demos/fitting/twitch_6state_control/sim_input/ca_protocol.txt');
dt_col = ca_proto.data(:, 1);   % dt per step (3056 rows)
t_sim  = cumsum(dt_col);        % absolute time (cumulative)
n_ca   = numel(t_sim);

fprintf('Experimental: %d points, t=[%.4f, %.4f] s\n', numel(t_exp), t_exp(1), t_exp(end));
fprintf('Ca protocol:  %d points, t=[%.4f, %.4f] s\n', n_ca, t_sim(1), t_sim(end));
fprintf('P710R force:  min=%.1f  max=%.1f  N/m2\n', min(f_exp), max(f_exp));

% Passive force = mean of first few experimental points (before Ca arrives)
passive_force = mean(f_exp(1:3));
fprintf('Using passive force = %.4f N/m2\n', passive_force);

% Protocol: 1000 equilibration rows then 2056 Ca transient rows = 3056 total.
% Ca transient duration = 2056 * dt = ~1.0 s, matching experimental span.
n_passive = 1000;
n_transient = n_ca - n_passive;  % 2056

% Build time axis for the transient section (relative to Ca onset)
dt_val = dt_col(1);
t_transient = (1:n_transient)' * dt_val;  % [dt, 2*dt, ..., 2056*dt] s

% Interpolate experimental data onto transient time axis
% Clamp before t_exp(1) and after t_exp(end) to boundary values
f_interp = interp1(t_exp, f_exp, t_transient, 'pchip', 'extrap');
f_interp(t_transient < t_exp(1))   = f_exp(1);
f_interp(t_transient > t_exp(end)) = f_exp(end);

target = [repmat(passive_force, n_passive, 1); f_interp];

fprintf('Target length: %d  (passive=%d + transient=%d)\n', numel(target), n_passive, n_transient);

% Write output
out_dir = '/Users/tomtan/Research/MATMyoSim/code/demos/fitting/twitch_6state_HCM/target';
if ~isfolder(out_dir), mkdir(out_dir); end
out_file = fullfile(out_dir, 'P710R_target.txt');
fid = fopen(out_file, 'w');
fprintf(fid, '%f\n', target);
fclose(fid);
fprintf('Wrote: %s\n', out_file);
end
