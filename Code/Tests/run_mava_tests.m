function results = run_mava_tests
% Run the complete active Mava and affected fit-engine regression suite.

test_dir = fileparts(mfilename('fullpath'));
repo_root = fullfile(test_dir, '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root, 'Code', 'System')));
addpath(fullfile(repo_root, 'Code', 'Fitting'));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
addpath(test_dir);

files = dir(fullfile(test_dir, 'test_*.m'));
names = erase(string({files.name}), '.m');
% Workflow tests have "mava" in their names; the explicit exceptions
% exercise fit-engine behavior changed by the Mava workflow.
fit_engine_tests = [ ...
    "test_configurable_k2_ratio", ...
    "test_evaluate_time_fit_start_index", ...
    "test_fit_controller_diagnostics", ...
    "test_independent_k2_model_write"];
selected = contains(names, 'mava') | ismember(names, fit_engine_tests);
names = sort(names(selected));

n = numel(names);
Name = names(:);
Passed = false(n, 1);
Failed = false(n, 1);
Incomplete = false(n, 1);
Duration = zeros(n, 1);
ErrorIdentifier = strings(n, 1);
ErrorMessage = strings(n, 1);
for i = 1:n
    started = tic;
    try
        feval(char(Name(i)));
        Passed(i) = true;
    catch ME
        Failed(i) = true;
        ErrorIdentifier(i) = string(ME.identifier);
        ErrorMessage(i) = string(ME.message);
    end
    Duration(i) = toc(started);
end

results = table(Name, Passed, Failed, Incomplete, Duration, ...
    ErrorIdentifier, ErrorMessage);
assert(all(results.Passed), 'run_mava_tests:failure', ...
    '%d of %d Mava/fit-engine tests failed.', nnz(results.Failed), n);
end
