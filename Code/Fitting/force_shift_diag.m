% force_shift_diag.m
% Diagnostic: does shifting simulated FORCE earlier relative to the Ca
% transient improve the twitch fit? Runs the current 6-state best-fit models
% (control + HCM) through protocol_1s.txt, then sweeps an integer row shift of
% the force trace and recomputes the SAME normalized active-window SSE used by
% evaluate_time_fit.m. Positive shift = force leads Ca (force moved earlier).
% Nothing canonical is modified.

repo_root = fileparts(mfilename('fullpath'));           % Code/Fitting
code_root = fileparts(repo_root);                        % Code
addpath(genpath(code_root));
addpath(genpath(fullfile(code_root, 'System')));

proto   = fullfile(code_root, 'System', 'protocols', 'protocol_1s.txt');
options = fullfile(repo_root, 'twitch_6state_control', 'sim_input', 'sim_options.json');

cases = struct( ...
    'name',   {'Control', 'HCM'}, ...
    'model',  {fullfile(repo_root,'twitch_6state_control','temp','best','model_best.json'), ...
               fullfile(repo_root,'twitch_6state_HCM','temp','best','model_best.json')}, ...
    'target', {fullfile(code_root,'System','target_data','Con_target.txt'), ...
               fullfile(code_root,'System','target_data','H251N_target.txt')});

dt_ms      = 1;                 % protocol dt = 0.001 s
shifts_ms  = -50:2:40;          % rows; +ve = force earlier (leads Ca), -ve = force later (more lag)
results    = struct();

fig = figure('Name','Force shift diagnostic','Position',[40 40 1200 500],'Color','w');

for c = 1:numel(cases)
    tgt = load(cases(c).target);
    tgt = tgt(:);
    n   = numel(tgt);

    cd(fullfile(repo_root, ['twitch_6state_' lower(strrep(cases(c).name,'Control','control'))]));
    sim = simulation_driver('model_json_file_string', cases(c).model, ...
        'simulation_protocol_file_string', proto, ...
        'options_json_file_string', options);
    f_all = sim.muscle_force(:);

    % Aligned window (length n), same as evaluate_time_fit
    f_win = f_all(end-n+1:end);

    errs = nan(size(shifts_ms));
    for k = 1:numel(shifts_ms)
        s = shifts_ms(k);        % rows to move force earlier (force leads Ca)
        if s >= 0
            y = f_win(1+s:n);  t = tgt(1:n-s);      % force sampled s rows later, matched to earlier target
        else
            y = f_win(1:n+s);  t = tgt(1-s:n);
        end
        errs(k) = active_sse(y, t);
    end

    [best_e, bi] = min(errs);
    base_e = errs(shifts_ms==0);
    fprintf('%-8s baseline e=%.5f | best e=%.5f at shift=%+d ms (%.1f%% change)\n', ...
        cases(c).name, base_e, best_e, shifts_ms(bi), 100*(best_e-base_e)/base_e);

    results.(matlab.lang.makeValidName(cases(c).name)) = ...
        struct('shifts',shifts_ms,'errs',errs,'best_shift',shifts_ms(bi), ...
               'best_e',best_e,'base_e',base_e);

    subplot(1,2,c); hold on; box off; grid on;
    plot(shifts_ms, errs, '-o', 'LineWidth', 1.8, 'Color', [0.0 0.45 0.85]);
    plot(0, base_e, 'ks', 'MarkerFaceColor','k', 'MarkerSize',8);
    plot(shifts_ms(bi), best_e, 'rp', 'MarkerFaceColor','r', 'MarkerSize',12);
    xlabel('Force shift earlier re Ca (ms)'); ylabel('Normalized active SSE');
    title(sprintf('%s: best %+d ms', cases(c).name, shifts_ms(bi)));
end

saveas(fig, fullfile(repo_root, 'force_shift_diag.png'));
fprintf('Saved: Code/Fitting/force_shift_diag.png\n');

% --- same metric as evaluate_time_fit.m, given an already-windowed sim trace ---
function e = active_sse(y_window, target_data)
    tmin = min(target_data); tmax = max(target_data);
    baseline_range = tmin + 0.05*(tmax - tmin);
    first_active = find(target_data > baseline_range, 1, 'first');
    if isempty(first_active) || first_active < 2
        first_active = 1;
        baseline_y = y_window(1); baseline_t = target_data(1);
    else
        passive_idx = 1:(first_active-1);
        if numel(passive_idx) > 5
            lp = passive_idx(round(0.5*end):end);
            baseline_y = mean(y_window(lp)); baseline_t = mean(target_data(lp));
        else
            baseline_y = mean(y_window(passive_idx)); baseline_t = mean(target_data(passive_idx));
        end
    end
    y_bs = y_window - baseline_y + baseline_t;
    ai = first_active:numel(target_data);
    e = sum(((y_bs(ai)-target_data(ai))./(tmax-tmin)).^2) / numel(ai);
end
