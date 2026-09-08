function test_run_mava_sequential_path
% The sequential runner must expose Code/simulation_driver.m itself.

test_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(test_dir));
script_dir = fullfile(repo_root, 'Code', 'Fitting', 'mava_codex');
saved_path = path;
path_cleanup = onCleanup(@() path(saved_path));
output_root = tempname;
mkdir(output_root);
output_cleanup = onCleanup(@() remove_if_present(output_root));

restoredefaultpath;
addpath(script_dir);
run_mava_sequential_analysis('path_fixture', 'dry_run', ...
    'output_root', output_root, 'restarts', 1, 'max_fun_evals', 1);

expected = fullfile(repo_root, 'Code', 'simulation_driver.m');
assert(strcmp(which('simulation_driver'), expected), ...
    'The sequential runner must add the repository Code directory itself.');
end

function remove_if_present(path)
if isfolder(path), rmdir(path, 's'); end
end
