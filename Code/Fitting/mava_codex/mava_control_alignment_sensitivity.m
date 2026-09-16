function comparison = mava_control_alignment_sensitivity(workbook_file, out_dir)
% Compare shared and trace-specific Mava timing alignment without altering data.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
if nargin < 1 || isempty(workbook_file)
    workbook_file = fullfile(repo_root, 'Code', 'System', ...
        'experimental_data', 'Mava data.xlsx');
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(script_dir, 'output', ...
        'alignment_sensitivity_20260916');
end
if ~isfolder(out_dir)
    mkdir(out_dir);
end

shared_dir = fullfile(out_dir, 'shared_by_genotype');
independent_dir = fullfile(out_dir, 'independent_trace');
shared = prepare_mava_data(workbook_file, shared_dir, 'peak', ...
    'shared_by_genotype');
independent = prepare_mava_data(workbook_file, independent_dir, 'peak', ...
    'independent_trace');

assert(isequal(shared.id, independent.id), ...
    'mava_control_alignment_sensitivity:idMismatch', ...
    'Alignment policies produced different trace identities.');
comparison = table(string(shared.id), string(shared.condition), ...
    string(shared.genotype), shared.source_trough_time, ...
    shared.applied_time_shift, independent.applied_time_shift, ...
    shared.aligned_force_rise_time, independent.aligned_force_rise_time, ...
    shared.calcium_to_force_lag, independent.calcium_to_force_lag, ...
    shared.calcium_to_force_lag - independent.calcium_to_force_lag, ...
    'VariableNames', {'id','condition','genotype','source_trough_time', ...
    'shared_time_shift','independent_time_shift','shared_rise_time', ...
    'independent_rise_time','shared_force_lag','independent_force_lag', ...
    'lag_removed_by_trace_specific_alignment'});
writetable(comparison, fullfile(out_dir, 'alignment_sensitivity.csv'));
normalize_lf(fullfile(out_dir, 'alignment_sensitivity.csv'));

acute = comparison.id == "ctrl_acute";
assert(nnz(acute) == 1, ...
    'mava_control_alignment_sensitivity:acuteMissing', ...
    'Could not find the Control acute trace.');
if comparison.lag_removed_by_trace_specific_alignment(acute) < 0.15
    warning('mava_control_alignment_sensitivity:unexpectedShift', ...
        'Control acute alignment sensitivity is smaller than expected.');
end

fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [50 50 1060 500]);
layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile(layout, 1);
control = comparison.genotype == "Control";
labels = categorical(comparison.condition(control), ...
    comparison.condition(control), 'Ordinal', true);
bar(labels, 1000*[comparison.shared_force_lag(control), ...
    comparison.independent_force_lag(control)], 'grouped');
ylabel('Force-rise lag after Ca onset (ms)');
legend({'Shared-by-genotype', 'Trace-specific'}, 'Location', 'northwest');
title('Control timing depends on alignment policy');
grid on; box off;

nexttile(layout, 2);
[shared_t, shared_target] = load_trace(shared_dir, 'ctrl_acute');
[independent_t, independent_target] = load_trace(independent_dir, 'ctrl_acute');
peak = max(shared_target);
plot(shared_t, shared_target/peak, 'k-', 'LineWidth', 2); hold on;
plot(independent_t, independent_target/peak, 'Color', [0.15 0.45 0.75], ...
    'LineWidth', 2);
xline(shared_t(find(shared_t >= 0.48, 1, 'first')), ':', 'Ca onset', ...
    'LabelVerticalAlignment', 'bottom');
xlabel('Protocol time (s)');
ylabel('Control acute force / shared peak');
legend({'Shared-by-genotype', 'Trace-specific'}, 'Location', 'best');
title('Same force trace; only the time origin changes');
grid on; box off;

title(layout, ['Alignment sensitivity diagnostic — not a refit and ' ...
    'not a source-data modification'], 'FontWeight', 'bold');
exportgraphics(fig, fullfile(out_dir, 'control_alignment_sensitivity.png'), ...
    'Resolution', 220);
close(fig);
end

function [t, target] = load_trace(data_dir, id)
target = load(fullfile(data_dir, [id '_target.txt']));
protocol = readtable(fullfile(data_dir, [id '_protocol.txt']), ...
    'FileType', 'text', 'Delimiter', '\t');
t = cumsum(protocol.dt) - protocol.dt(1);
end

function normalize_lf(file)
fid = fopen(file, 'rb');
if fid < 0
    error('mava_control_alignment_sensitivity:readFailed', ...
        'Could not read %s.', file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8');
clear cleanup;
cr_indices = find(bytes(1:end-1) == 13 & bytes(2:end) == 10);
bytes(cr_indices) = [];
fid = fopen(file, 'wb');
if fid < 0
    error('mava_control_alignment_sensitivity:writeFailed', ...
        'Could not write %s.', file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, bytes, 'uint8');
end
