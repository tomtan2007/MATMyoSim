function test_fit_controller_diagnostics
% fit_controller must return and persist convergence plus raw/clamped p values.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

tmp_dir = tempname;
result_dir = fullfile(tmp_dir, 'results');
mkdir(result_dir);
cleanup = onCleanup(@() rmdir(tmp_dir, 's')); %#ok<NASGU>

target_file = fullfile(tmp_dir, 'target.txt');
fid = fopen(target_file, 'w');
assert(fid >= 0, 'Could not create temporary target data.');
fprintf(fid, '0\n1\n');
fclose(fid);

opt = struct;
opt.parameter = { ...
    struct('name', 'first', 'p_value', -0.2), ...
    struct('name', 'second', 'p_value', 1.2)};
opt.job = {struct('target_file_string', target_file)};
opt.best_opt_file_string = fullfile(result_dir, 'best_optimization.json');
opt.figure_optimization_progress = 0;
opt.figure_current_fit = 0;
opt.max_fun_evals = 1;
opt.test_objective = @(p) sum((p - 0.4).^2);

fit_results = fit_controller(opt);
disk_results = loadjson(fullfile(result_dir, 'fit_results.json'));
best_opt = loadjson(opt.best_opt_file_string);

diagnostic_fields = {'exitflag', 'iterations', 'func_count', ...
    'algorithm', 'message'};
for i = 1:numel(diagnostic_fields)
    name = diagnostic_fields{i};
    assert(isfield(fit_results, name), ...
        'Returned fit results are missing %s.', name);
    assert(isfield(disk_results, name), ...
        'Disk fit results are missing %s.', name);
    assert(isequal(fit_results.(name), disk_results.(name)), ...
        'Returned and disk diagnostics disagree for %s.', name);
end

saved_parameters = best_opt.MyoSim_optimization.parameter;
for i = 1:numel(saved_parameters)
    assert(isfield(saved_parameters{i}, 'p_value_raw'), ...
        'Saved parameter %d is missing p_value_raw.', i);
    assert(saved_parameters{i}.p_value >= 0 && ...
        saved_parameters{i}.p_value <= 1, ...
        'Saved parameter %d has an unclamped p_value.', i);
end
assert(any(cellfun(@(x) x.p_value_raw < 0 || x.p_value_raw > 1, ...
    saved_parameters)), ...
    'Fixture must exercise an out-of-bounds raw optimizer coordinate.');

fprintf('PASS: fit_controller convergence and boundary diagnostics\n');
end
