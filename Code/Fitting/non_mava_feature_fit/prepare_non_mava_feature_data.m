function audit = prepare_non_mava_feature_data(output_dir)
% Verify and prepare the raw non-Mava Control/H251N twitch pair.

% The workbook is authoritative for force because it contains the complete
% time axis and all 36 samples. The condition MAT files are verified as
% exact rounded subsets. The established protocol_1s calcium input is used;
% Ca_transients2 is audited but not substituted for that PI-approved input.

if nargin < 1 || isempty(output_dir)
    output_dir = fullfile(fileparts(mfilename('fullpath')), 'output', 'data');
end
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
system_dir = fullfile(repo_root, 'Code', 'System');
source_dir = fullfile(system_dir, 'experimental_data');
if ~isfolder(output_dir), mkdir(output_dir); end

workbook = fullfile(source_dir, 'Updated cell trace data.xlsx');
raw = readmatrix(workbook);
t_control = raw(:, 1); f_control = raw(:, 2);
t_h251n = raw(:, 5); f_h251n = raw(:, 6);
valid_control = isfinite(t_control) & isfinite(f_control);
valid_h251n = isfinite(t_h251n) & isfinite(f_h251n);
t_control = t_control(valid_control); f_control = f_control(valid_control);
t_h251n = t_h251n(valid_h251n); f_h251n = f_h251n(valid_h251n);

control_mat = load(fullfile(source_dir, 'Con_C4_D96_c48b.mat'));
h251n_mat = load(fullfile(source_dir, 'H251N_C3_D96_c63b.mat'));
control_mat = control_mat.Con_C4_D96_c48b(:);
h251n_mat = h251n_mat.H251N_C3_D96_c63b(:);
[control_start, control_max_abs] = subset_match(f_control, control_mat);
[h251n_start, h251n_max_abs] = subset_match(f_h251n, h251n_mat);
if control_max_abs > 1e-5 || h251n_max_abs > 1e-5
    error('prepare_non_mava_feature_data:forceMismatch', ...
        'Workbook force columns do not match the named MAT traces.');
end

time_mat = load(fullfile(source_dir, 'cell_time_trace.mat'));
time_mat = time_mat.cell_time_trace(:);
ca_mat = load(fullfile(source_dir, 'Ca_transients2.mat'));
ca = ca_mat.Ca_2;

protocol_file = fullfile(system_dir, 'protocols', 'protocol_1s.txt');
protocol = readtable(protocol_file, 'FileType', 'text', 'Delimiter', '\t');
sim_time = cumsum(protocol.dt) - protocol.dt(1);
reference_idx = find(protocol.pCa < 6.70, 1, 'first');
reference_time = sim_time(reference_idx);

[target_control, baseline_control] = prepare_target( ...
    t_control, f_control, sim_time, reference_time);
[target_h251n, baseline_h251n] = prepare_target( ...
    t_h251n, f_h251n, sim_time, reference_time);

writetable(protocol, fullfile(output_dir, 'protocol_1s.txt'), ...
    'FileType', 'text', 'Delimiter', '\t');
writematrix(target_control, fullfile(output_dir, 'control_target.txt'), ...
    'Delimiter', 'tab');
writematrix(target_h251n, fullfile(output_dir, 'h251n_target.txt'), ...
    'Delimiter', 'tab');
writetable(table(t_control, f_control, ...
    'VariableNames', {'time_s','force_N_per_m2'}), ...
    fullfile(output_dir, 'control_raw_source.csv'));
writetable(table(t_h251n, f_h251n, ...
    'VariableNames', {'time_s','force_N_per_m2'}), ...
    fullfile(output_dir, 'h251n_raw_source.csv'));

audit = table( ...
    ["Control"; "H251N"], [numel(t_control); numel(t_h251n)], ...
    [control_start; h251n_start], [numel(control_mat); numel(h251n_mat)], ...
    [control_max_abs; h251n_max_abs], ...
    [t_control(1); t_h251n(1)], [t_control(end); t_h251n(end)], ...
    [baseline_control; baseline_h251n], ...
    repmat(reference_time, 2, 1), ...
    'VariableNames', {'condition','workbook_points','mat_subset_start_row', ...
    'mat_points','mat_workbook_max_abs_difference','first_time_s', ...
    'last_time_s','baseline_force_N_per_m2','calcium_reference_time_s'});
writetable(audit, fullfile(output_dir, 'data_source_audit.csv'));

metadata = struct('force_source', workbook, ...
    'protocol_source', protocol_file, ...
    'force_source_reason', ['Workbook contains the complete matching time/' ...
    'force traces; named MAT files are rounded subsets.'], ...
    'cell_time_trace_points', numel(time_mat), ...
    'cell_time_trace_range', [time_mat(1) time_mat(end)], ...
    'ca_transients_shape', size(ca), ...
    'ca_transients_range', [min(ca, [], 1); max(ca, [], 1)], ...
    'ca_transients_used_for_fit', false, ...
    'mava_data_used', false, ...
    'alignment', ['Original workbook timestamps retained; force onset is ' ...
    'detected independently for each condition relative to protocol calcium onset.']);
fid = fopen(fullfile(output_dir, 'data_source_metadata.json'), 'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(metadata, PrettyPrint=true));
end

function [start_index, max_abs_difference] = subset_match(full_trace, subset)
best = inf; start_index = NaN;
for i = 1:(numel(full_trace)-numel(subset)+1)
    difference = max(abs(full_trace(i:i+numel(subset)-1) - subset));
    if difference < best
        best = difference; start_index = i;
    end
end
max_abs_difference = best;
end

function [target, baseline] = prepare_target(t, force, sim_time, reference_time)
baseline_values = force(t <= reference_time);
if numel(baseline_values) < 3
    baseline_values = force(1:min(4, numel(force)));
end
baseline = median(baseline_values);
force_zeroed = force - baseline;
target = interp1(t, force_zeroed, sim_time, 'linear', NaN);
target(sim_time < t(1)) = 0;
target(sim_time > t(end)) = force_zeroed(end);
end
