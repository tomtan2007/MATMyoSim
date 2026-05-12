function smoke_test_6state
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

sim = simulation('sim_input/model_template.json', 'sim_input/ca_protocol.txt', 'sim_input/sim_options.json');
sim.implement_protocol();

fprintf('Smoke test PASSED. Final force = %g\n', sim.sim_output.muscle_force(end));
fprintf('Final pops: M1=%g M2=%g M3=%g M4=%g M5=%g M6=%g\n', ...
    sim.sim_output.M1(end), sim.sim_output.M2(end), sim.sim_output.M3(end), ...
    sim.sim_output.M4(end), sim.sim_output.M5(end), sim.sim_output.M6(end));
total = sim.sim_output.M1(end)+sim.sim_output.M2(end)+sim.sim_output.M3(end)+ ...
        sim.sim_output.M4(end)+sim.sim_output.M5(end)+sim.sim_output.M6(end);
fprintf('Conservation: sum = %g\n', total);
end
