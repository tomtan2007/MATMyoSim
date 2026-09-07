function test_mava_alignment_policies
repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
trough = [0.16; 0.35; 0.21; 0.29; 0.22; 0.19];
codes = ["Control"; "Control"; "Control"; "H251N"; "H251N"; "H251N"];
shared = mava_alignment_shifts(trough, codes, 0.480, 'shared_by_genotype');
independent = mava_alignment_shifts(trough, codes, 0.480, 'independent_trace');
assert(max(abs(shared(1:3) - (0.480 - 0.16))) < 1e-12);
assert(max(abs(shared(4:6) - (0.480 - 0.29))) < 1e-12);
assert(max(abs(trough + independent - 0.480)) < 1e-12);
fprintf('PASS: Mava alignment policies\n');
end
