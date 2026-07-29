function update_beard_atp_revised(obj, time_step)
% Revised Beard ATP model with M4/M7 rewired to interact with M1/M6
%
% Original: M1-M2-M3-M4-M5-M6-M7 linear chain with M7 recycling to M2/M3
% Revised:  M1-M2-M3-M5-M6 main chain (M3 connects directly to M5)
%           M4 side branch: M1 <-> M4 <-> M6
%           M7 recycling:   M6 -> M7 -> M1 (instead of M7 -> M2/M3)
%
% ASSUMPTIONS (verify with PI):
%   1. M3->M5 direct connection added (to maintain main pathway)
%   2. M1->M4 uses bell curve attachment (like M2->M3, new param k_15)
%   3. M4->M1 uses constant rate (k_6_0)
%   4. M4<->M6 uses same rates as old M4<->M5 (k_7_0 exponential, k_8_0 constant)
%   5. M7->M1 is constant rate (k__12), M1->M7 is constant rate (k__14)

y = obj.myofilaments.y;

% State indices (same layout as original beard_atp)
M1_ind = 1;
M2_ind = 2;
M3_ind = 2 + (1:obj.myofilaments.no_of_x_bins);
M4_ind = (2 + obj.myofilaments.no_of_x_bins) + (1:obj.myofilaments.no_of_x_bins);
M5_ind = (2 + 2*obj.myofilaments.no_of_x_bins) + (1:obj.myofilaments.no_of_x_bins);
M6_ind = (2 + 3*obj.myofilaments.no_of_x_bins) + (1:obj.myofilaments.no_of_x_bins);
M7_ind = M6_ind(end) + 1;

N_overlap = return_f_overlap(obj);

% --- RATES ---

% r1: M1->M2, force-dependent (unchanged)
r1 = obj.parameters.k_1 * (1 + obj.parameters.k_force * max([0 obj.hs_force]));

% r2: M2->M1, constant (unchanged)
r2 = min([obj.parameters.max_rate obj.parameters.k_2]);

% r3: M2->M3, bell curve attachment (unchanged)
r3 = obj.parameters.k_3 * ...
    exp(-0.5 * obj.parameters.k_cb * (obj.myofilaments.x.^2) / ...
        (1e18 * obj.parameters.k_boltzmann * obj.parameters.temperature));
r3(r3 > obj.parameters.max_rate) = obj.parameters.max_rate;

% r4: M3->M2, double sigmoid detachment (unchanged)
r4 = obj.parameters.k_4_0 + ...
    obj.parameters.max_rate * (1./(1 + exp(-obj.parameters.k_4_1 * (obj.myofilaments.x - obj.parameters.k_4_2)))) + ...
    obj.parameters.max_rate * (1./(1 + exp( obj.parameters.k_4_1 * (obj.myofilaments.x + obj.parameters.k_4_2))));
r4(r4 > obj.parameters.max_rate) = obj.parameters.max_rate;
r4(r4 < 0) = 0;

% r5: M3->M5 (REWIRED, was M3->M4), constant
r5 = obj.parameters.k_5_0 * ones(1, numel(obj.myofilaments.x));
r5(r5 > obj.parameters.max_rate) = obj.parameters.max_rate;
r5(r5 < 0) = 0;

% r6: M4->M1 (REWIRED, was M4->M3), constant
r6 = obj.parameters.k_6_0 * ones(1, numel(obj.myofilaments.x));
r6(r6 > obj.parameters.max_rate) = obj.parameters.max_rate;
r6(r6 < 0) = 0;

% r7: M4->M6 (REWIRED, was M4->M5), exponential
r7 = obj.parameters.k_7_0 * ...
    exp(-obj.parameters.k_cb * obj.parameters.k_7_1 * obj.myofilaments.x ./ ...
        (1e18 * obj.parameters.k_boltzmann * obj.parameters.temperature));
if isfield(obj.parameters, 'k_7_2') && isfield(obj.parameters, 'k_7_3')
    r7 = r7 + obj.parameters.max_rate * ...
        (1./(1 + exp(-obj.parameters.k_7_2 * (obj.myofilaments.x - obj.parameters.k_7_3))));
end
r7(r7 > obj.parameters.max_rate) = obj.parameters.max_rate;
r7(r7 < 0) = 0;

% r8: M6->M4 (REWIRED, was M5->M4), constant
r8 = obj.parameters.k_8_0 * ones(1, numel(obj.myofilaments.x));
r8(r8 > obj.parameters.max_rate) = obj.parameters.max_rate;
r8(r8 < 0) = 0;

% r9: M5->M6, constant (unchanged)
r9 = obj.parameters.k_9_0 * ones(1, numel(obj.myofilaments.x));
r9(r9 > obj.parameters.max_rate) = obj.parameters.max_rate;
r9(r9 < 0) = 0;

% r10: M6->M5, constant (unchanged)
r10 = r9 * obj.parameters.k__10_mult;
r10(r10 > obj.parameters.max_rate) = obj.parameters.max_rate;
r10(r10 < 0) = 0;

% r11: M6->M7, double sigmoid (unchanged)
r11 = obj.parameters.k__11_0 + ...
    obj.parameters.max_rate * (1./(1 + exp(-obj.parameters.k__11_1 * (obj.myofilaments.x - obj.parameters.k__11_2)))) + ...
    obj.parameters.max_rate * (1./(1 + exp( obj.parameters.k__11_1 * (obj.myofilaments.x + obj.parameters.k__11_2))));
r11(r11 > obj.parameters.max_rate) = obj.parameters.max_rate;
r11(r11 < 0) = 0;

% r12: M7->M1, constant (REWIRED, was M7->M3 bell curve)
r12 = obj.parameters.k__12;

% r14: M1->M7, constant (REWIRED, was M2->M7)
r14 = obj.parameters.k__14;

% r15: M1->M4, bell curve attachment (NEW — direct SRX to attached via titin)
r15 = obj.parameters.k_15 * ...
    exp(-0.5 * obj.parameters.k_cb * (obj.myofilaments.x.^2) / ...
        (1e18 * obj.parameters.k_boltzmann * obj.parameters.temperature));
r15(r15 > obj.parameters.max_rate) = obj.parameters.max_rate;

% Calcium switch rates
r_on = obj.parameters.k_on * obj.Ca;
r_off = obj.parameters.k_off;
if (r_off < 0), r_off = 0; end

% Solve ODEs
[~, y_new] = ode23(@derivs, [0 time_step], y, []);

obj.myofilaments.y = y_new(end,:)';

% Conservation — correct numerical drift
zi = find(obj.myofilaments.y < 0);
obj.myofilaments.y(zi) = 0;
cb = sum(obj.myofilaments.y(1:(end-2)));
obj.myofilaments.y(1) = obj.myofilaments.y(1) + (1 - cb);
ac = obj.myofilaments.y(end-1) + obj.myofilaments.y(end);
obj.myofilaments.y(end-1) = obj.myofilaments.y(end-1) + (1 - ac);

obj.f_overlap = N_overlap;
obj.f_on = obj.myofilaments.y(end);
obj.f_bound = sum(obj.myofilaments.y(M3_ind)) + sum(obj.myofilaments.y(M4_ind)) + ...
              sum(obj.myofilaments.y(M5_ind)) + sum(obj.myofilaments.y(M6_ind));

    function dy = derivs(~, y)
        dy = zeros(numel(y), 1);

        M1 = y(M1_ind); M2 = y(M2_ind);
        M3 = y(M3_ind); M4 = y(M4_ind); M5 = y(M5_ind); M6 = y(M6_ind);
        M7 = y(M7_ind);
        N_off = y(end-1); N_on = y(end);
        N_bound = sum(M3) + sum(M4) + sum(M5) + sum(M6);

        % Fluxes — REWIRED topology
        J1  = r1 * M1;                                                  % M1->M2 (unchanged)
        J2  = r2 * M2;                                                  % M2->M1 (unchanged)
        J3  = r3 .* obj.myofilaments.bin_width * M2 * (N_on - N_bound); % M2->M3 (unchanged)
        J4  = r4 .* M3';                                                % M3->M2 (unchanged)
        J5  = r5 .* M3';                                                % M3->M5 (REWIRED, was M3->M4)
        J6  = r6 .* M4';                                                % M4->M1 (REWIRED, was M4->M3)
        J7  = r7 .* M4';                                                % M4->M6 (REWIRED, was M4->M5)
        J8  = r8 .* M6';                                                % M6->M4 (REWIRED, was M5->M4)
        J9  = r9 .* M5';                                                % M5->M6 (unchanged)
        J10 = r10 .* M6';                                               % M6->M5 (unchanged)
        J11 = r11 .* M6';                                               % M6->M7 (unchanged)
        J12 = r12 * M7;                                                 % M7->M1 (REWIRED, was M7->M3)
        J14 = r14 * M1;                                                 % M1->M7 (REWIRED, was M2->M7)
        J15 = r15 .* obj.myofilaments.bin_width * M1 * (N_on - N_bound); % M1->M4 (NEW)

        if (N_overlap > 0)
            J_on  = r_on * (N_overlap - N_on) * (1 + obj.parameters.k_coop * (N_on / N_overlap));
            J_off = r_off * (N_on - N_bound) * (1 + obj.parameters.k_coop * ((N_overlap - N_on) / N_overlap));
        else
            J_on  = 0;
            J_off = obj.parameters.k_off * (N_on - N_bound);
        end

        % ODEs
        % M1: gains from M2(J2), M4(sum J6), M7(J12)
        %     loses to M2(J1), M4(sum J15), M7(J14)
        dy(M1_ind) = -J1 + J2 + sum(J6) + J12 - sum(J15) - J14;

        % M2: gains from M1(J1), M3(sum J4)
        %     loses to M1(J2), M3(sum J3)
        %     NOTE: M2 no longer connects to M7
        dy(M2_ind) = J1 + sum(J4) - J2 - sum(J3);

        for i = 1:obj.myofilaments.no_of_x_bins
            % M3: gains from M2(J3), loses to M2(J4), M5(J5)
            dy(M3_ind(i)) = J3(i) - J4(i) - J5(i);

            % M4: gains from M1(J15), M6(J8), loses to M1(J6), M6(J7)
            dy(M4_ind(i)) = J15(i) + J8(i) - J6(i) - J7(i);

            % M5: gains from M3(J5), M6(J10), loses to M6(J9)
            dy(M5_ind(i)) = J5(i) + J10(i) - J9(i);

            % M6: gains from M4(J7), M5(J9), loses to M4(J8), M5(J10), M7(J11)
            dy(M6_ind(i)) = J7(i) + J9(i) - J8(i) - J10(i) - J11(i);
        end

        % M7: gains from M6(sum J11), M1(J14), loses to M1(J12)
        dy(M7_ind) = sum(J11) + J14 - J12;

        dy(end-1) = -J_on + J_off;
        dy(end)   =  J_on - J_off;
    end
end
