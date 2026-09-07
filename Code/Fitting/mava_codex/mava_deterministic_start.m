function p = mava_deterministic_start(n, restart, previous_best)
% Return a reproducible normalized start for one stage and restart.

if nargin < 3
    previous_best = [];
end

if restart == 1
    p = 0.5 * ones(1, n);
    if ~isempty(previous_best)
        p(1:numel(previous_best)) = previous_best(:)';
    end
    return;
end

j = 0:n-1;
p = 0.2 + 0.6 * mod((restart-1) * 0.61803398875 + ...
    j * 0.41421356237, 1);
end
