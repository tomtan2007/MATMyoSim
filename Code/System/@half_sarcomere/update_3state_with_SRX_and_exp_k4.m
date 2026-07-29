function update_3state_with_SRX_and_exp_k4(obj,time_step);
% 3-state SRX model (Campbell et al, 2018) with exponential detachment
% Called every timestep to move motors between states
%
% STATES:
%   M1 = SRX (asleep, unavailable)
%   M2 = DRX (awake, available)
%   M3 = Attached (generating force) — array across x-positions
%   N_off/N_on = thin filament calcium switch

y = obj.myofilaments.y;
N_overlap = return_f_overlap(obj);

% Rates (speed limits for transitions between states)

% r1: M1->M2 (wake up). Force-dependent — key HCM parameter
r1 = min([obj.parameters.max_rate ...
            obj.parameters.k_1 * ...
                (1+(obj.parameters.k_force * max([0 obj.hs_force])))]);

% r2: M2->M1 (go back to sleep). Constant — this is k_2 from your fitting demo
r2 = min([obj.parameters.max_rate obj.parameters.k_2]);

% r3: M2->M3 (attach). Position-dependent bell curve — fastest at x=0
r3 = obj.parameters.k_3 * ...
            exp(-obj.parameters.k_cb * (obj.myofilaments.x).^2 / ...
                (2 * 1e18 * obj.parameters.k_boltzmann * ...
                    obj.parameters.temperature));
r3(r3>obj.parameters.max_rate)=obj.parameters.max_rate;

% r4: M3->M2 (detach). EXPONENTIAL — key difference from basic 3-state
% r4 = k_4_0 * exp(-k_4_1 * x) gives more realistic twitch shape
r4 = obj.parameters.k_4_0 * exp(-obj.parameters.k_4_1 * obj.myofilaments.x);
% Safety clamps for extreme x values (numerical guardrails, don't worry about these)
    r4(r4>(obj.parameters.k_4_0 * exp(obj.parameters.k_4_1*7.95))) = ...
        obj.parameters.k_4_0 * exp(-obj.parameters.k_4_1 * obj.myofilaments.x(obj.myofilaments.x<-7.95))-...
        (obj.myofilaments.x(obj.myofilaments.x<-7.95)+7.95)*obj.parameters.max_rate;
    r4(r4<(obj.parameters.k_4_0 * exp(-obj.parameters.k_4_1*7.95))) = ...
        obj.parameters.k_4_0 * exp(-obj.parameters.k_4_1 * obj.myofilaments.x(obj.myofilaments.x>7.95))+...
        (obj.myofilaments.x(obj.myofilaments.x>7.95)-7.95)*obj.parameters.max_rate;
r4(r4>obj.parameters.max_rate)=obj.parameters.max_rate;

% Solve ODEs for one timestep, get new motor positions
[t,y_new] = ode23(@derivs,[0 time_step],y,[]);

% Save updated state
obj.myofilaments.y = y_new(end,:)';
obj.f_overlap = N_overlap;
obj.f_on = obj.myofilaments.y(end);
obj.f_bound = sum(obj.myofilaments.y(2+(1:obj.myofilaments.no_of_x_bins)));

obj.rate_structure.r1 = r1;
obj.rate_structure.r2 = r2;
obj.rate_structure.r3 = r3;
obj.rate_structure.r4 = r4;

    function dy = derivs(time_step,y)

        dy = zeros(numel(y),1);

        % Unpack states
        M1 = y(1);
        M2 = y(2);
        M3 = y(2+(1:obj.myofilaments.no_of_x_bins));
        N_off = y(end-1);
        N_on = y(end);
        N_bound = sum(M3);

        % Fluxes: flux = rate x motors available to move
        J1 = r1 * M1;                  % SRX -> DRX
        J2 = r2 * M2;                  % DRX -> SRX
        J3 = r3 .* obj.myofilaments.bin_width * M2 * (N_on - N_bound); % DRX -> Attached
        J4 = r4 .* M3';                % Attached -> DRX
        J_on  = obj.parameters.k_on * obj.Ca * (N_overlap - N_on) * ...
                (1 + obj.parameters.k_coop * (N_on/N_overlap));         % Ca binds
        J_off = obj.parameters.k_off * (N_on - N_bound) * ...
                (1 + obj.parameters.k_coop * ((N_overlap - N_on)/N_overlap)); % Ca unbinds

        % ODEs: leaving a state = minus, arriving = plus
        dy(1) = -J1 + J2;                          % dM1/dt
        dy(2) = (J1 + sum(J4)) - (J2 + sum(J3));   % dM2/dt
        for i=1:obj.myofilaments.no_of_x_bins
            dy(2+i) = J3(i) - J4(i);               % dM3/dt at each x
        end
        dy(end-1) = -J_on + J_off;                 % dN_off/dt
        dy(end)   =  J_on - J_off;                 % dN_on/dt
    end
end
