function rate_structure = update_4state_with_SRX_and_exp_k7(obj,time_step)
% 4-state SRX model: M1(SRX) <-> M2(DRX) -> M3(Attached1) -> M4(Attached2)
% M4 has exponential detachment (exp k7). M2 can also attach directly to M4.

y = obj.myofilaments.y;

% M3 and M4 are arrays across x-bins (attached motors at each position)
M3_indices = 2+(1:obj.myofilaments.no_of_x_bins);
M4_indices = (2+obj.myofilaments.no_of_x_bins)+(1:obj.myofilaments.no_of_x_bins);

N_overlap = return_f_overlap(obj);

% --- RATES ---

% M1->M2, force-dependent
r1 = min([obj.parameters.max_rate obj.parameters.k_1*(1+(obj.parameters.k_force*max([0 obj.hs_force])))]);

% M2->M1, constant
r2 = min([obj.parameters.max_rate obj.parameters.k_2]);

% M2->M3, bell curve fastest at x=0
r3 = obj.parameters.k_3 * ...
        exp(-obj.parameters.k_cb * (obj.myofilaments.x).^2 / ...
            (2 * 1e18 * obj.parameters.k_boltzmann * obj.parameters.temperature));
r3(r3>obj.parameters.max_rate)=obj.parameters.max_rate;

% M3->M2, polynomial
r4 = obj.parameters.k_4_0 + obj.parameters.k_4_1*(obj.myofilaments.x.^4);
r4(r4>obj.parameters.max_rate)=obj.parameters.max_rate;

% M3->M4, sigmoid
r5 = obj.parameters.k_5_0 ./ (1+exp(obj.parameters.k_5_1*(obj.myofilaments.x+obj.parameters.x_ps/2)));
r5(r5>obj.parameters.max_rate) = obj.parameters.max_rate;

% M4->M3, polynomial
r6 = (obj.parameters.k_6_0*ones(numel(obj.myofilaments.x),1)) + ...
        (obj.parameters.k_6_1.*(obj.myofilaments.x'+(obj.parameters.x_ps/2)).^4);
r6(r6>obj.parameters.max_rate) = obj.parameters.max_rate;

% M4->M2, exponential detachment (the "exp k7")
r7 = obj.parameters.k_7_0 * ...
            exp(-(obj.parameters.k_cb*obj.myofilaments.x*obj.parameters.k_7_1)./ ...
            (1e18*obj.parameters.k_boltzmann*obj.parameters.temperature));
% Sigmoid clamps at extreme x values (numerical guardrails, only if parameters exist)
if (isfield(obj.parameters,'k_7_2'))
    r7 = r7 + obj.parameters.max_rate*(1./(1+exp(-obj.parameters.k_7_2*(obj.myofilaments.x-obj.parameters.k_7_3))));
    r7 = r7 + obj.parameters.max_rate*(1./(1+exp(obj.parameters.k_7_2*(obj.myofilaments.x+obj.parameters.k_7_3))));
end
r7(r7>obj.parameters.max_rate) = obj.parameters.max_rate;
r7(r7<0) = 0;

% M2->M4 direct attach (skipping M3), constant
r8 = obj.parameters.k_8*ones(numel(obj.myofilaments.x),1);

[t,y_new] = ode23(@derivs,[0 time_step],y,[]);

obj.myofilaments.y = y_new(end,:)';
obj.f_overlap = N_overlap;
obj.f_on = obj.myofilaments.y(end);
% f_bound = total attached motors (M3 + M4)
obj.f_bound = sum(obj.myofilaments.y(M3_indices))+sum(obj.myofilaments.y(M4_indices));

obj.rate_structure.r1=r1; obj.rate_structure.r2=r2; obj.rate_structure.r3=r3;
obj.rate_structure.r4=r4; obj.rate_structure.r5=r5; obj.rate_structure.r6=r6;
obj.rate_structure.r7=r7; obj.rate_structure.r8=r8;

    function dy = derivs(time_step,y)
        dy = zeros(numel(y),1);

        M1=y(1); M2=y(2); M3=y(M3_indices); M4=y(M4_indices);
        N_off=y(end-1); N_on=y(end);
        N_bound = sum(M3)+sum(M4);

        % Fluxes
        J1 = r1*M1;
        % M1->M2
        J2 = r2*M2;
        % M2->M1
        J3 = r3.*obj.myofilaments.bin_width*M2*(N_on-N_bound);
        % M2->M3
        J4 = r4.*M3';
        % M3->M2
        J5 = r5.*M3';
        % M3->M4
        J6 = r6.*M4';
        % M4->M3
        J7 = r7.*M4';
        % M4->M2 (exponential)
        J8 = r8*M2;
        % M2->M4 direct
        J_on  = obj.parameters.k_on*obj.Ca*(N_overlap-N_on)*(1+obj.parameters.k_coop*(N_on/N_overlap));
        % Ca binds
        J_off = obj.parameters.k_off*(N_on-N_bound)*(1+obj.parameters.k_coop*((N_overlap-N_on)/N_overlap));
        % Ca unbinds

        % ODEs: leaving = minus, arriving = plus
        dy(1) = -J1+J2;
        dy(2) = (J1+sum(J4)+sum(J7)) - (J2+sum(J3)+sum(J8));
        for i=1:obj.myofilaments.no_of_x_bins
            dy(M3_indices(i)) = J3(i)-J4(i)-J5(i)+J6(i);
            dy(M4_indices(i)) = J5(i)-J6(i)-J7(i)+J8(i);
        end
        dy(end-1) = -J_on+J_off;
        dy(end)   =  J_on-J_off;
    end
end
