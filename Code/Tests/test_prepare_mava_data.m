function test_prepare_mava_data
% Mavacamten workbook must become six finite, time-aligned targets.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
fitting_dir = fullfile(repo_root, 'Code', 'Fitting');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(fitting_dir, 'mava_codex'));

source = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');
assert(isfile(source), 'Test workbook not found: %s', source);

out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

summary = prepare_mava_data([], out_dir);
assert(height(summary) == 6, 'Expected six experimental conditions.');
assert(all(isfinite(summary.peak_force)), 'All peaks must be finite.');
required = {'source_trough_time','source_force_rise_time', ...
    'applied_time_shift','aligned_force_rise_time', ...
    'calcium_to_force_lag','alignment_policy'};
assert(all(ismember(required, summary.Properties.VariableNames)), ...
    'Landmark and alignment diagnostics must be recorded in the summary.');
assert(all(strcmp(summary.alignment_policy, 'shared_by_genotype')), ...
    'Default alignment policy must be shared_by_genotype.');

ids = {'ctrl_before','ctrl_acute','ctrl_24h','hcm_before','hcm_acute','hcm_24h'};
for i = 1:numel(ids)
    target = load(fullfile(out_dir, [ids{i} '_target.txt']));
    protocol = readtable(fullfile(out_dir, [ids{i} '_protocol.txt']), ...
        'FileType', 'text', 'Delimiter', '\t');
    assert(numel(target) == height(protocol), ...
        'Target/protocol length mismatch for %s.', ids{i});
    assert(all(isfinite(target)), 'Target contains non-finite values for %s.', ids{i});
    [~, peak_idx] = max(target);
    assert(target(end) <= min(target(peak_idx:end)) + 0.01 * max(target), ...
        'Target %s retains a rising portion of the next contraction.', ids{i});
    assert(all(abs(protocol.dt - 0.001) < 1e-12), ...
        'Protocol must retain the canonical 1 ms time step.');
end

ctrl_before = summary.peak_force(strcmp(summary.id, 'ctrl_before'));
hcm_before = summary.peak_force(strcmp(summary.id, 'hcm_before'));
ctrl_ref = load(fullfile(repo_root, 'Code', 'System', 'target_data', 'Con_target.txt'));
hcm_ref = load(fullfile(repo_root, 'Code', 'System', 'target_data', 'H251N_target.txt'));
assert(abs(ctrl_before / trace_amplitude(ctrl_ref) - 1) < 1e-6, ...
    'Control before peak must anchor to the canonical control amplitude.');
assert(abs(hcm_before / trace_amplitude(hcm_ref) - 1) < 1e-6, ...
    'H251N before peak must anchor to the canonical H251N amplitude.');
ctrl_acute = summary.peak_force(strcmp(summary.id, 'ctrl_acute'));
hcm_acute = summary.peak_force(strcmp(summary.id, 'hcm_acute'));
assert(abs(ctrl_acute / ctrl_before - 0.35) < 0.02, ...
    'Control acute peak ratio must preserve the workbook response.');
assert(abs(hcm_acute / hcm_before - 0.33) < 0.02, ...
    'H251N acute peak ratio must preserve the workbook response.');

fprintf('PASS: mavacamten data preparation\n');
end

function a = trace_amplitude(y)
n = min(300, numel(y));
a = max(y - mean(y(1:n)));
end
