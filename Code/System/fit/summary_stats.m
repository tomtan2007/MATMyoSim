function s = summary_stats(x)
% Returns basic statistics of vector x used by evaluate_time_fit
s.n   = numel(x);
s.min = min(x);
s.max = max(x);
s.mean = mean(x);
