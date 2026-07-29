function inspect_P710R
cd(fileparts(mfilename('fullpath')));

d = load('cell_time_trace.mat');
t = d.cell_time_trace;
fprintf('Time vector: %d points, min=%.4f max=%.4f\n', numel(t), min(t), max(t));
fprintf('dt=%.4f\n', t(2)-t(1));

d2 = load('Control_c4_force.mat');
fn = fieldnames(d2); f = d2.(fn{1});
fprintf('Control_c4: %d points\n', numel(f));

d3 = load('P710R_c32_force.mat');
fn3 = fieldnames(d3); f3 = d3.(fn3{1});
fprintf('P710R_c32: %d points\n', numel(f3));

% Check control target
ctrl = load('/Users/tomtan/Research/MATMyoSim/code/demos/fitting/twitch_3state_control/sim_input/ca_protocol.txt');
fprintf('ca_protocol: %d rows x %d cols\n', size(ctrl,1), size(ctrl,2));
fprintf('ca_protocol first time: %.4f, last time: %.4f\n', ctrl(1,1), ctrl(end,1));
end
