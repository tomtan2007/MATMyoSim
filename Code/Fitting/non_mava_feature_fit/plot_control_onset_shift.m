function plot_control_onset_shift()
% Separate timing-alignment sensitivity check; no parameter refitting.
here = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(fileparts(here)));
addpath(genpath(fullfile(repo,'Code')));
addpath(genpath(fullfile(repo,'Code','System')));
source = fullfile(here,'output','core_k1_k3_k50_r4');
out = fullfile(here,'output','control_onset_shift_20260921');
if ~isfolder(out), mkdir(out); end
data = fullfile(source,'s01','data');
sim = simulation_driver('model_json_file_string', ...
    fullfile(source,'s01','results','joint_feature_fit','control_best.json'), ...
    'simulation_protocol_file_string',fullfile(data,'protocol_1s.txt'), ...
    'options_json_file_string',fullfile(repo,'Code','Fitting', ...
    'twitch_6state_control','sim_input','sim_options.json'));
target = load(fullfile(data,'control_target.txt')); target = target(:);
n = numel(target); t = sim.time_s(end-n+1:end); t = t(:);
idx = 481;
[~,~,details,tm,mm] = evaluate_mava_feature_fit(sim,target,'fit_start_index',idx);
model = align_time_fit_baseline(sim.muscle_force(end-n+1:end),target,idx);
shift = tm.force_onset_time-mm.force_onset_time;
shifted_time = t-shift;
raw = readtable(fullfile(data,'control_raw_source.csv'));
audit = readtable(fullfile(data,'data_source_audit.csv'));
raw_force = raw.force_N_per_m2-audit.baseline_force_N_per_m2(1);
writetable(table(t,shifted_time,target,model,'VariableNames', ...
    {'original_time_s','shifted_target_time_s','target_force_Pa','model_force_Pa'}), ...
    fullfile(out,'control_alignment.csv'));
writetable(details,fullfile(out,'original_features_current_model.csv'));
f = figure('Visible','off','Color','w','Position',[50 50 1250 550]);
for panel = 1:2
    subplot(1,2,panel); hold on;
    offset = (panel-1)*shift;
    plot(t-offset,target,'k-','LineWidth',2,'DisplayName','Control data');
    plot(raw.time_s-offset,raw_force,'ko','MarkerSize',4,'HandleVisibility','off');
    plot(t,model,'Color',[0.12 0.45 0.75],'LineWidth',2,'DisplayName','Fitted model');
    xline(t(idx),':','Ca reference','HandleVisibility','off');
    yline(0,':','HandleVisibility','off');
    xlim([0.4 1.35]); ylim([-200 4800]); grid on; box off;
    xlabel('Time (s)'); ylabel('Baseline-subtracted force (Pa)');
    if panel==1, title('Original timing');
    else, title(sprintf('Data shifted %.1f ms earlier',1000*shift)); end
    legend('Location','northeast');
end
sgtitle('Control onset alignment check | same fitted parameters, no refit');
exportgraphics(f,fullfile(out,'control_onset_shift.png'),'Resolution',180);
exportgraphics(f,fullfile(out,'control_onset_shift.pdf'),'ContentType','vector');
close(f);
fid=fopen(fullfile(out,'README.txt'),'w');
fprintf(fid,['Control timing-alignment sensitivity check, 2026-09-21.\n' ...
    'Source: core_k1_k3_k50_r4, restart 1. Model re-simulated without refitting.\n' ...
    'Experimental data translated earlier by %.9f s to match detected force onset.\n' ...
    'Original onset delay: target %.6f ms; model %.6f ms.\n' ...
    'A constant time translation preserves amplitude and intrinsic twitch durations.\n' ...
    'This is an assumed alignment, not a measurement of cellular calcium onset.\n' ...
    'Original data and fitted model files are unchanged.\n'], ...
    shift,1000*tm.force_onset_delay,1000*mm.force_onset_delay);
fclose(fid);
fprintf('SHIFT_SECONDS=%.9f\nTARGET_DELAY_MS=%.6f\nMODEL_DELAY_MS=%.6f\n', ...
    shift,1000*tm.force_onset_delay,1000*mm.force_onset_delay);
end
