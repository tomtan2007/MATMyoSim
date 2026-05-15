function update_6state_with_SRX_and_titin(obj, time_step)
% 6-state titin-coupled model, built from 4-state template
%
%   M1(SRXD) --R1--> M2(DRXD) --R3--> M3(AD)
%   ^R11/vR12        ^R13/vR14       ^R6/vR5
%   M6(SRXT) <--R9-- M5(DRXT) --R8--> M4(AT)
%            --R10->          <--R7--
%
% Predominant flow is clockwise: M1->M2->M3->M4->M5->M6->M1
% Cycle M2->M3->M4->M5->M2 closes via R13 (M5->M2), which is optimized.
% R3..R8 use the same functional forms as r3..r8 in update_4state_with_SRX_and_exp_k7.

y    = obj.myofilaments.y;
no_x = obj.myofilaments.no_of_x_bins;
x    = obj.myofilaments.x;

M3_indices = 2 + (1:no_x);
M4_indices = (2 + no_x) + (1:no_x);
M5_index   = 2 + 2*no_x + 1;
M6_index   = 2 + 2*no_x + 2;

N_overlap = return_f_overlap(obj);

% --- R1: M1->M2, force-dependent ---
r1 = min([obj.parameters.max_rate ...
            obj.parameters.k_1 * (1 + obj.parameters.k_force * obj.hs_force)]);

% --- R2: M2->M1, constant ---
r2 = min([obj.parameters.max_rate obj.parameters.k_2]);

% --- R3: M2->M3, bell-curve attachment ---
r3 = obj.parameters.k_3 * ...
        exp(-obj.parameters.k_cb * (x).^2 / ...
            (2 * 1e18 * obj.parameters.k_boltzmann * obj.parameters.temperature));
r3(r3 > obj.parameters.max_rate) = obj.parameters.max_rate;

% --- R4: M3->M2, polynomial detachment ---
r4 = obj.parameters.k_4_0 + obj.parameters.k_4_1 * (x.^4);
r4(r4 > obj.parameters.max_rate) = obj.parameters.max_rate;

% --- R5: M3->M4, sigmoid power stroke ---
r5 = obj.parameters.k_5_0 ./ ...
        (1 + exp(obj.parameters.k_5_1 * (x + obj.parameters.x_ps/2)));
r5(r5 > obj.parameters.max_rate) = obj.parameters.max_rate;

% --- R6: M4->M3, polynomial reverse power stroke ---
r6 = (obj.parameters.k_6_0 * ones(numel(x), 1)) + ...
        (obj.parameters.k_6_1 .* (x' + (obj.parameters.x_ps/2)).^4);
r6(r6 > obj.parameters.max_rate) = obj.parameters.max_rate;

% --- R7: M4->M5, exponential detachment ---
r7 = obj.parameters.k_7_0 * ...
        exp(-(obj.parameters.k_cb * x * obj.parameters.k_7_1) ./ ...
            (1e18 * obj.parameters.k_boltzmann * obj.parameters.temperature));
if isfield(obj.parameters, 'k_7_2')
    r7 = r7 + obj.parameters.max_rate * ...
            (1 ./ (1 + exp(-obj.parameters.k_7_2 * (x - obj.parameters.k_7_3))));
    r7 = r7 + obj.parameters.max_rate * ...
            (1 ./ (1 + exp(obj.parameters.k_7_2 * (x + obj.parameters.k_7_3))));
end
r7(r7 > obj.parameters.max_rate) = obj.parameters.max_rate;
r7(r7 < 0) = 0;

% --- R8: M5->M4, constant direct attach (default k_8=0 -> no flux) ---
r8 = obj.parameters.k_8 * ones(numel(x), 1);

% --- R9..R14: bottom row + vertical, scalar constants ---
r9  = min([obj.parameters.max_rate obj.parameters.k_9]);   % M5->M6
r10 = min([obj.parameters.max_rate obj.parameters.k_10]);  % M6->M5
r11 = min([obj.parameters.max_rate obj.parameters.k_11]);  % M6->M1
r12 = min([obj.parameters.max_rate obj.parameters.k_12]);  % M1->M6
r13 = min([obj.parameters.max_rate obj.parameters.k_13]);  % M5->M2
r14 = min([obj.parameters.max_rate obj.parameters.k_14]);  % M2->M5

[~, y_new] = ode23(@derivs, [0 time_step], y, []);

obj.myofilaments.y = y_new(end, :)';
obj.f_overlap = N_overlap;
obj.f_on      = obj.myofilaments.y(end);
obj.f_bound   = sum(obj.myofilaments.y(M3_indices)) + ...
                sum(obj.myofilaments.y(M4_indices));

obj.rate_structure.r1  = r1;  obj.rate_structure.r2  = r2;
obj.rate_structure.r3  = r3;  obj.rate_structure.r4  = r4;
obj.rate_structure.r5  = r5;  obj.rate_structure.r6  = r6;
obj.rate_structure.r7  = r7;  obj.rate_structure.r8  = r8;
obj.rate_structure.r9  = r9;  obj.rate_structure.r10 = r10;
obj.rate_structure.r11 = r11; obj.rate_structure.r12 = r12;
obj.rate_structure.r13 = r13; obj.rate_structure.r14 = r14;

    function dy = derivs(~, y)
        dy = zeros(numel(y), 1);

        M1 = y(1);  M2 = y(2);
        M3 = y(M3_indices);
        M4 = y(M4_indices);
        M5 = y(M5_index);  M6 = y(M6_index);
        N_off = y(end-1);  N_on = y(end);
        N_bound = sum(M3) + sum(M4);

        % Top-row horizontal fluxes
        J1 = r1 * M1;
        J2 = r2 * M2;
        J3 = r3 .* obj.myofilaments.bin_width * M2 * (N_on - N_bound);
        J4 = r4 .* M3';

        % Power-stroke fluxes (M3 <-> M4)
        J5 = r5 .* M3';
        J6 = r6 .* M4';

        % Bottom-row horizontal fluxes
        J7  = r7 .* M4';   % M4->M5 (detachment into titin-coupled pathway)
        J8  = r8 .* M5;
        J9  = r9  * M5;
        J10 = r10 * M6;

        % Vertical (titin coupling) fluxes
        J11 = r11 * M6;
        J12 = r12 * M1;
        J13 = r13 * M5;
        J14 = r14 * M2;

        % Ca activation
        J_on  = obj.parameters.k_on  * obj.Ca * (N_overlap - N_on) * ...
                    (1 + obj.parameters.k_coop * (N_on / N_overlap));
        J_off = obj.parameters.k_off * (N_on - N_bound) * ...
                    (1 + obj.parameters.k_coop * ((N_overlap - N_on) / N_overlap));

        % ODEs
        dy(1) = (-J1 + J2) + (J11 - J12);
        dy(2) = (J1 - J2) + (sum(J4) - sum(J3)) + (J13 - J14);
        for i = 1:no_x
            dy(M3_indices(i)) = J3(i) - J4(i) - J5(i) + J6(i);
            dy(M4_indices(i)) = J5(i) - J6(i) - J7(i) + J8(i);
        end
        dy(M5_index) = (sum(J7) - sum(J8)) + (-J9 + J10) + (-J13 + J14);
        dy(M6_index) = (J9 - J10) + (-J11 + J12);
        dy(end-1) = -J_on + J_off;
        dy(end)   =  J_on - J_off;
    end
end
