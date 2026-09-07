function test_mava_scaling_modes
% All supported scaling methods must preserve one scale per genotype.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
source = fullfile(repo_root, 'Code', 'System', 'experimental_data', ...
    'Mava data.xlsx');

modes = {'peak','p95','least_squares'};
factors = nan(numel(modes), 2);
for i = 1:numel(modes)
    out_dir = tempname;
    mkdir(out_dir);
    cleanup = onCleanup(@() rmdir(out_dir, 's')); %#ok<NASGU>
    T = prepare_mava_data(source, out_dir, modes{i}, 'shared_by_genotype');
    assert(all(strcmp(T.scale_mode, modes{i})), 'Scale mode not recorded.');
    assert(numel(unique(T.scale_factor(1:3))) == 1, ...
        'Control conditions must share one scale factor.');
    assert(numel(unique(T.scale_factor(4:6))) == 1, ...
        'H251N conditions must share one scale factor.');
    assert(all(isfinite(T.scale_factor) & T.scale_factor > 0.01), ...
        'Scale factors must be positive, finite, and non-collapsed.');
    assert(all(T.peak_force > 1), 'Scaling collapsed a target waveform.');
    factors(i,:) = [T.scale_factor(1), T.scale_factor(4)];
    clear cleanup;
end
assert(numel(unique(round(factors(:,1), 3, 'significant'))) > 1, ...
    'Control scaling modes should not collapse to the same factor.');
assert(numel(unique(round(factors(:,2), 3, 'significant'))) > 1, ...
    'H251N scaling modes should not collapse to the same factor.');

fprintf('PASS: mavacamten scaling modes\n');
end
