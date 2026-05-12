function implement_time_step(obj,time_step,delta_hsl,Ca_concentration)

% Update Ca
obj.Ca = Ca_concentration;

% Update kinetics
obj.evolve_kinetics(time_step);

% Move distributions
obj.move_cb_distribution(delta_hsl);

% Update forces
obj.update_forces;

% Store pops
flag = 1;

if startsWith(obj.kinetic_scheme, '2state')
    flag = 0;
    obj.state_pops.M1 = obj.myofilaments.y(1);
    obj.state_pops.M2 = ...
        sum(obj.myofilaments.y(1+(1:obj.myofilaments.no_of_x_bins)));
end

if startsWith(obj.kinetic_scheme, '3state_with_SRX')
    flag = 0;
    obj.state_pops.M1 = obj.myofilaments.y(1);
    obj.state_pops.M2 = obj.myofilaments.y(2);
    obj.state_pops.M3 = ...
        sum(obj.myofilaments.y(2+(1:obj.myofilaments.no_of_x_bins)));
end

if startsWith(obj.kinetic_scheme, '4state_with_SRX')
    flag = 0;
    obj.state_pops.M1 = obj.myofilaments.y(1);
    obj.state_pops.M2 = obj.myofilaments.y(2);

    M3_indices = 2+(1:obj.myofilaments.no_of_x_bins);
    M4_indices = (2+obj.myofilaments.no_of_x_bins) + ...
        (1:obj.myofilaments.no_of_x_bins);

    obj.state_pops.M3 = ...
        sum(obj.myofilaments.y(M3_indices));
    obj.state_pops.M4 = ...
        sum(obj.myofilaments.y(M4_indices));
end

if startsWith(obj.kinetic_scheme, 'beard_atp')
    flag = 0;
    obj.state_pops.M1 = obj.myofilaments.y(1);
    obj.state_pops.M2 = obj.myofilaments.y(2);

    M3_indices = 2 + (1:obj.myofilaments.no_of_x_bins);
    M4_indices = (2 + obj.myofilaments.no_of_x_bins) + (1:obj.myofilaments.no_of_x_bins);
    M5_indices = (2 + 2*obj.myofilaments.no_of_x_bins) + (1:obj.myofilaments.no_of_x_bins);
    M6_indices = (2 + 3*obj.myofilaments.no_of_x_bins) + (1:obj.myofilaments.no_of_x_bins);
    M7_ind = M6_indices(end) + 1;

    obj.state_pops.M3 = sum(obj.myofilaments.y(M3_indices));
    obj.state_pops.M4 = sum(obj.myofilaments.y(M4_indices));
    obj.state_pops.M5 = sum(obj.myofilaments.y(M5_indices));
    obj.state_pops.M6 = sum(obj.myofilaments.y(M6_indices));
    obj.state_pops.M7 = obj.myofilaments.y(M7_ind);
end

if startsWith(obj.kinetic_scheme, '6state_with_SRX_and_titin')
    flag = 0;
    no_x = obj.myofilaments.no_of_x_bins;
    M3_indices = 2 + (1:no_x);
    M4_indices = (2 + no_x) + (1:no_x);

    obj.state_pops.M1 = obj.myofilaments.y(1);
    obj.state_pops.M2 = obj.myofilaments.y(2);
    obj.state_pops.M3 = sum(obj.myofilaments.y(M3_indices));
    obj.state_pops.M4 = sum(obj.myofilaments.y(M4_indices));
    obj.state_pops.M5 = obj.myofilaments.y(2 + 2*no_x + 1);
    obj.state_pops.M6 = obj.myofilaments.y(2 + 2*no_x + 2);
end

% Check
if (flag)
    error('half_sarcomere::implement_time_step, kinetic scheme undefined');
end

end
