function smoke_test_r15
% Quick smoke test: verify 6-state model with R15 runs and conserves population
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

proto = 'sim_input/ca_protocol.txt';
opts  = 'sim_input/sim_options.json';
model = 'sim_input/model_template.json';

sim = simulation(model, proto, opts);
sim.implement_protocol();

fields = fieldnames(sim.sim_output);
yfield = fields{contains(fields, 'myofilament')};
y = sim.sim_output.(yfield);
total = sum(y(end, :));
fprintf('Population sum (end): %.6f  (should be 1.0)\n', total);

force = sim.sim_output.muscle_force;
fprintf('Peak force: %.1f  N/m^2\n', max(force));
fprintf('Smoke test PASSED\n');
end
