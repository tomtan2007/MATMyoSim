function test_mava_onset_alignment
% Prepared traces must be locally zeroed and aligned to protocol activation.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
out_dir = tempname;
mkdir(out_dir);
cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>

source = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');
T = prepare_mava_data(source, out_dir, 'peak', 'shared_by_genotype');
required = {'source_trough_time','source_force_rise_time', ...
    'applied_time_shift','aligned_force_rise_time', ...
    'calcium_to_force_lag','alignment_policy','baseline_value'};
assert(all(ismember(required,T.Properties.VariableNames)), ...
    'Alignment diagnostics must be recorded in the summary.');
assert(max(abs(T.applied_time_shift(1:3)-T.applied_time_shift(1))) < 1e-12, ...
    'Control traces must use one shared time shift.');
assert(max(abs(T.applied_time_shift(4:6)-T.applied_time_shift(4))) < 1e-12, ...
    'H251N traces must use one shared time shift.');
assert(max(abs(T.calcium_to_force_lag(1:3) - [0.063; 0.208; 0.133])) < 0.004, ...
    'Control force-rise lags must match the verified trace landmarks.');
assert(all(strcmp(T.alignment_policy, 'shared_by_genotype')), ...
    'Summary must record the selected alignment policy.');

for i = 1:height(T)
    target = load(fullfile(out_dir,[T.id{i} '_target.txt']));
    protocol = readtable(fullfile(out_dir,[T.id{i} '_protocol.txt']), ...
        'FileType','text','Delimiter','\t');
    onset = find(protocol.pCa < 6.70,1,'first');
    pre = max(1,onset-50):(onset-1);
    assert(abs(mean(target(pre))) < 0.05*max(target), ...
        'Immediate pre-onset baseline exceeds 5%% of peak for %s.',T.id{i});
    [~, peak_idx] = max(target);
    threshold = 0.05 * target(peak_idx);
    rise_idx = find(target(1:peak_idx-1) >= threshold & ...
        target(2:peak_idx) >= threshold, 1, 'first');
    aligned_time = sum(protocol.dt(1:rise_idx)) - protocol.dt(1);
    assert(abs(T.aligned_force_rise_time(i) - aligned_time) < 1e-12, ...
        'Aligned rise time must be measured on the final target for %s.', T.id{i});
end

fprintf('PASS: Mava onset alignment\n');
end
