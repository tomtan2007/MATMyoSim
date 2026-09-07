function test_detect_mava_trace_landmarks
repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
t = (0:0.01:1.2)';
y = 7 + 100*exp(-0.5*((t-0.70)/0.10).^2);
y(t < 0.42) = 7;
L = detect_mava_trace_landmarks(t, y);
assert(abs(L.baseline_value - 7) < 0.2);
assert(abs(L.peak_time - 0.70) <= 0.01);
assert(L.trough_time < L.rise_time && L.rise_time < L.peak_time);
fprintf('PASS: Mava trace landmarks\n');
end
