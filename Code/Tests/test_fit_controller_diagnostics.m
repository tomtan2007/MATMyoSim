function test_fit_controller_diagnostics
% fit_controller must return and persist convergence plus raw/clamped p values.

repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(repo_root, 'Code', 'System')));

tmp_dir = tempname;
result_dir = fullfile(tmp_dir, 'results');
mkdir(result_dir);
cleanup = onCleanup(@() rmdir(tmp_dir, 's'));

target_file = fullfile(tmp_dir, 'target.txt');
fid = fopen(target_file, 'w');
assert(fid >= 0, 'Could not create temporary target data.');
fprintf(fid, '%g\n', 0:499);
fclose(fid);

opt = struct;
opt.parameter = { ...
    struct('name', 'first', 'p_value', -0.2), ...
    struct('name', 'second', 'p_value', 1.2)};
opt.job = {struct('target_file_string', target_file, ...
    'fit_start_index', 480.6)};
opt.best_opt_file_string = fullfile(result_dir, 'best_optimization.json');
opt.figure_optimization_progress = 0;
opt.figure_current_fit = 0;
opt.max_fun_evals = 1;
opt.tol_fun = 3e-5;
opt.tol_x = 7e-4;
opt.test_objective = @(p) sum((p - 0.4).^2);

fit_results = fit_controller(opt);
disk_results = loadjson(fullfile(result_dir, 'fit_results.json'));
best_opt = loadjson(opt.best_opt_file_string);

assert(abs(fit_results.best_error - 0.52) < 1e-12, ...
    'best_error must be the unpenalized error at the winning clamped point.');
assert(isfield(fit_results, 'best_objective') && ...
    abs(fit_results.best_objective - 800.52) < 1e-10 && ...
    fit_results.best_objective > fit_results.best_error, ...
    'best_objective must retain the 800.52 penalized minimizer objective.');
assert(fit_results.n_active_points == 20, ...
    'AIC point count must begin at the configured row 481.');
assert(abs(fit_results.aic - (-9.078530)) < 1e-5, ...
    'AIC must use 20 scored points and the unpenalized error.');
assert(abs(fit_results.tol_fun - 3e-5) < 1e-15 && ...
    abs(fit_results.tol_x - 7e-4) < 1e-15, ...
    'Returned diagnostics must expose the configured fminsearch tolerances.');
assert(abs(disk_results.best_error - fit_results.best_error) < 1e-5 && ...
    abs(disk_results.best_objective - fit_results.best_objective) < 1e-5 && ...
    abs(disk_results.aic - fit_results.aic) < 1e-5, ...
    'Returned and disk objective/error/AIC fields must agree.');

diagnostic_fields = {'exitflag', 'iterations', 'func_count', ...
    'algorithm', 'message', 'tol_fun', 'tol_x'};
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

multiplier_opt = opt;
multiplier_opt.best_opt_file_string = fullfile(tmp_dir, ...
    'multiplier_results', 'best_optimization.json');
mkdir(fileparts(multiplier_opt.best_opt_file_string));
multiplier_opt.constraint = {struct('job_number', 1, ...
    'parameter_multiplier', {{struct('name', 'scale', 'p_value', 0.4)}})};
multiplier_results = fit_controller(multiplier_opt);
multiplier_best = loadjson(multiplier_opt.best_opt_file_string);
multiplier = multiplier_best.MyoSim_optimization.constraint{1}. ...
    parameter_multiplier{1};

assert(numel(multiplier_best.MyoSim_optimization.parameter) == 2, ...
    'A multiplier coordinate must not create an extra ordinary parameter.');
assert(abs(multiplier_results.best_error - 0.52) < 1e-12, ...
    'The in-bounds multiplier coordinate must not change fit error.');
assert(abs(multiplier_results.aic - (-7.078530)) < 1e-5, ...
    'AIC must count two ordinary parameters plus one multiplier.');
assert(abs(multiplier.p_value_raw - 0.4) < 1e-12, ...
    'Raw multiplier coordinate was not saved on the multiplier entry.');
assert(abs(multiplier.p_value - 0.4) < 1e-12, ...
    'Clamped multiplier coordinate was not saved on the multiplier entry.');

auto_opt = opt;
auto_opt.job{1}.fit_start_index = [];
auto_opt.best_opt_file_string = fullfile(result_dir, 'auto_optimization.json');
auto_results = fit_controller(auto_opt);
assert(auto_results.n_active_points == 475, ...
    'An empty fit start must use the same threshold detection as fitting.');

fprintf('PASS: fit_controller convergence and boundary diagnostics\n');
end
