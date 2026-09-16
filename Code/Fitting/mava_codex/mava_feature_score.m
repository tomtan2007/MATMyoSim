function [score, details] = mava_feature_score(target, model, spec, varargin)
% Score model twitch features as weighted squared standardized residuals.

p = inputParser;
addParameter(p, 'MissingFeaturePenalty', 25);
parse(p, varargin{:});
missing_penalty = p.Results.MissingFeaturePenalty;

if nargin < 3 || isempty(spec)
    spec = mava_default_feature_spec(target);
end
if iscell(spec)
    spec = [spec{:}];
end

n = numel(spec);
feature = strings(n, 1);
target_value = nan(n, 1);
model_value = nan(n, 1);
scale = nan(n, 1);
weight = nan(n, 1);
standardized_residual = nan(n, 1);
contribution = nan(n, 1);
included = false(n, 1);
missing_model_feature = false(n, 1);

for i = 1:n
    feature(i) = string(spec(i).name);
    name = char(feature(i));
    if ~isfield(target, name) || ~isfield(model, name)
        error('mava_feature_score:unknownFeature', ...
            'Feature %s is not present in both metric structures.', name);
    end
    target_value(i) = target.(name);
    model_value(i) = model.(name);
    scale(i) = spec(i).scale;
    weight(i) = spec(i).weight;

    % A target feature absent because the recording ended early is not an
    % observation and therefore is not scored.
    if ~isfinite(target_value(i))
        continue;
    end
    if ~(isfinite(scale(i)) && scale(i) > 0 && ...
            isfinite(weight(i)) && weight(i) >= 0)
        error('mava_feature_score:badSpecification', ...
            'Feature %s requires a positive scale and nonnegative weight.', name);
    end
    included(i) = weight(i) > 0;
    if ~included(i)
        continue;
    end
    if ~isfinite(model_value(i))
        missing_model_feature(i) = true;
        contribution(i) = weight(i)*missing_penalty;
    else
        standardized_residual(i) = ...
            (model_value(i)-target_value(i))/scale(i);
        contribution(i) = weight(i)*standardized_residual(i)^2;
    end
end

if ~any(included)
    error('mava_feature_score:noObservedFeatures', ...
        'No finite, positively weighted target features are available.');
end
score = sum(contribution(included)) / sum(weight(included));
details = table(feature, target_value, model_value, scale, weight, ...
    standardized_residual, contribution, included, missing_model_feature);
end
