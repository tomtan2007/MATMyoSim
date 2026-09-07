function summary = prepare_mava_data(workbook_file, out_dir, scale_mode, alignment_policy)
% Convert the six averaged mavacamten traces to model-ready targets.
% One scale factor per genotype anchors its Before trace to the canonical
% target while preserving acute and 24 h force ratios within that genotype.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fullfile(script_dir, '..', '..', '..');
system_dir = fullfile(repo_root, 'Code', 'System');

if nargin < 1 || isempty(workbook_file)
    workbook_file = fullfile(system_dir, 'experimental_data', 'Mava data.xlsx');
end
if nargin < 3 || isempty(scale_mode), scale_mode = 'peak'; end
if nargin < 4 || isempty(alignment_policy)
    alignment_policy = 'shared_by_genotype';
end
valid_modes = {'peak','p95','least_squares'};
if ~ismember(scale_mode, valid_modes)
    error('prepare_mava_data:badScaleMode', 'Unknown scaling mode: %s', scale_mode);
end
if ~isfile(workbook_file)
    error('prepare_mava_data:missingWorkbook', 'Workbook not found: %s', workbook_file);
end
if ~isfolder(out_dir), mkdir(out_dir); end

raw = readmatrix(workbook_file);
if size(raw, 2) < 7
    error('prepare_mava_data:badShape', 'Expected time plus six trace columns.');
end

t_obs = raw(:, 1);
traces = raw(:, 2:7);
ids = {'ctrl_before','ctrl_acute','ctrl_24h', ...
       'hcm_before','hcm_acute','hcm_24h'};
conditions = {'Control Before','Control Mava acute','Control Mava 24 h', ...
              'H251N Before','H251N Mava acute','H251N Mava 24 h'};
genotypes = {'Control','Control','Control','H251N','H251N','H251N'};

canonical_protocol = readtable(fullfile(system_dir, 'protocols', 'protocol_1s.txt'), ...
    'FileType', 'text', 'Delimiter', '\t');
sim_t = cumsum(canonical_protocol.dt) - canonical_protocol.dt(1);
onset_idx = find(canonical_protocol.pCa < 6.70, 1, 'first');
onset_time = sim_t(onset_idx);
ctrl_ref = baseline_zero(load(fullfile(system_dir, 'target_data', 'Con_target.txt')));
hcm_ref = baseline_zero(load(fullfile(system_dir, 'target_data', 'H251N_target.txt')));

clean = cell(1, 6);
source_trough_time = nan(6,1);
source_force_rise_time = nan(6,1);
baseline_value = nan(6,1);
for i = 1:6
    valid = isfinite(t_obs) & isfinite(traces(:, i));
    ti = t_obs(valid);
    yi = traces(valid, i);
    landmarks = detect_mava_trace_landmarks(ti, yi);
    source_trough_time(i) = landmarks.trough_time;
    source_force_rise_time(i) = landmarks.rise_time;
    baseline_value(i) = landmarks.baseline_value;
    yi = yi - landmarks.baseline_value;
    relaxation_indices = find(ti >= landmarks.peak_time + 0.15);
    [~, local_min] = min(yi(relaxation_indices));
    cutoff_idx = relaxation_indices(local_min);
    ti = ti(landmarks.trough_index:cutoff_idx);
    yi = yi(landmarks.trough_index:cutoff_idx);
    clean{i} = [ti, yi];
end

applied_time_shift = mava_alignment_shifts(source_trough_time, ...
    genotypes, onset_time, alignment_policy);
for i = 1:6
    clean{i}(:,1) = clean{i}(:,1) + applied_time_shift(i);
end

scale_ctrl = scaling_factor(clean{1}, ctrl_ref, sim_t, scale_mode);
scale_hcm = scaling_factor(clean{4}, hcm_ref, sim_t, scale_mode);
scales = [repmat(scale_ctrl, 1, 3), repmat(scale_hcm, 1, 3)];

peak_force = nan(6,1);
time_to_peak = nan(6,1);
relax_half_time = nan(6,1);
fwhm = nan(6,1);
scale_factor = scales(:);
end_time = nan(6,1);
n_points = nan(6,1);
aligned_force_rise_time = nan(6,1);
calcium_to_force_lag = nan(6,1);

for i = 1:6
    ti = clean{i}(:,1);
    yi = clean{i}(:,2) * scales(i);
    keep = sim_t <= ti(end) + 1e-12;
    tout = sim_t(keep);
    protocol = canonical_protocol(keep, :);

    % Anchor recording start at the measured pre-activation baseline.
    target = interp1([0; ti], [0; yi], tout, 'linear');
    target = target(:);
    aligned_force_rise_time(i) = sustained_force_rise_time(tout, target);
    calcium_to_force_lag(i) = aligned_force_rise_time(i) - onset_time;

    writematrix(target, fullfile(out_dir, [ids{i} '_target.txt']), ...
        'Delimiter', 'tab');
    writetable(protocol, fullfile(out_dir, [ids{i} '_protocol.txt']), ...
        'FileType', 'text', 'Delimiter', '\t');

    metrics = twitch_metrics(tout, target, onset_time);
    peak_force(i) = metrics.peak;
    time_to_peak(i) = metrics.time_to_peak;
    relax_half_time(i) = metrics.relax_half_time;
    fwhm(i) = metrics.fwhm;
    end_time(i) = tout(end);
    n_points(i) = numel(tout);
end

summary = table(ids(:), conditions(:), genotypes(:), source_trough_time, ...
    source_force_rise_time, applied_time_shift, aligned_force_rise_time, ...
    calcium_to_force_lag, baseline_value, scale_factor, ...
    peak_force, time_to_peak, relax_half_time, fwhm, end_time, n_points, ...
    'VariableNames', {'id','condition','genotype','source_trough_time', ...
    'source_force_rise_time','applied_time_shift','aligned_force_rise_time', ...
    'calcium_to_force_lag','baseline_value','scale_factor', ...
    'peak_force','time_to_peak','relax_half_time','fwhm','end_time','n_points'});
summary = addvars(summary, repmat({scale_mode}, height(summary), 1), ...
    'After', 'genotype', 'NewVariableNames', 'scale_mode');
summary = addvars(summary, repmat({char(string(alignment_policy))}, ...
    height(summary), 1), 'After', 'scale_mode', ...
    'NewVariableNames', 'alignment_policy');
writetable(summary, fullfile(out_dir, 'experimental_metrics.csv'));
end

function rise_time = sustained_force_rise_time(t, y)
[peak, peak_idx] = max(y);
threshold = 0.05 * peak;
rise_idx = find(y(1:peak_idx-1) >= threshold & ...
    y(2:peak_idx) >= threshold, 1, 'first');
if isempty(rise_idx)
    error('prepare_mava_data:noAlignedForceRise', ...
        'Could not detect a sustained 5%% rise in the prepared target.');
end
rise_time = t(rise_idx);
end

function y = baseline_zero(y)
y = y(:);
n = min(300, numel(y));
y = y - mean(y(1:n));
end

function s = scaling_factor(trace, reference, sim_t, mode)
ti = trace(:,1);
yi = trace(:,2);
keep = sim_t <= ti(end) + 1e-12;
yq = interp1([0; ti], [0; yi], sim_t(keep), 'linear');
rq = reference(1:numel(yq));

switch mode
    case 'peak'
        s = max(rq) / max(yq);
    case 'p95'
        s = percentile(rq, 95) / percentile(yq, 95);
    case 'least_squares'
        [~, ix] = max(yq);
        [~, ir] = max(rq);
        shift = ir - ix;
        if shift >= 0
            x = yq(1:end-shift);
            r = rq(1+shift:end);
        else
            x = yq(1-shift:end);
            r = rq(1:end+shift);
        end
        active = (x > 0.05*max(x)) | (r > 0.05*max(r));
        x = x(active); r = r(active);
        s = (x' * r) / (x' * x);
end
end

function q = percentile(x, pct)
x = sort(x(isfinite(x)));
pos = 1 + (numel(x)-1) * pct/100;
lo = floor(pos); hi = ceil(pos);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (pos-lo) * (x(hi)-x(lo));
end
end

function m = twitch_metrics(t, y, onset_time)
active = find(t >= onset_time, 1, 'first'):numel(t);
[m.peak, rel_peak] = max(y(active));
peak_idx = active(rel_peak);
m.time_to_peak = t(peak_idx) - onset_time;

half = 0.5 * m.peak;
after = find(y(peak_idx:end) <= half, 1, 'first');
if isempty(after)
    m.relax_half_time = NaN;
else
    m.relax_half_time = t(peak_idx + after - 1) - t(peak_idx);
end

above = find(y >= half);
if isempty(above)
    m.fwhm = NaN;
else
    m.fwhm = t(above(end)) - t(above(1));
end
end
