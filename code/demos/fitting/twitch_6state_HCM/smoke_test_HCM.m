function smoke_test_HCM
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', '..')));
cd(fileparts(mfilename('fullpath')));

opt_file = 'optimization.json';
opt = loadjson(opt_file);
opt_s = opt.MyoSim_optimization;

if ~isfolder('temp'), mkdir('temp'); end
if ~isfolder('temp/best'), mkdir('temp/best'); end

opt_s.model_working_file_string = opt_s.job{1}.model_file_string;
opt_s.best_model_file_string    = 'temp/best/model_best.json';

[e, ~, ~, ~, ~] = fit_worker([0.5 0.5 0.5 0.5 0.5 0.5 0.33 0.5 0.5], opt_s);
fprintf('Smoke test PASSED. e = %.6f\n', e);
end
