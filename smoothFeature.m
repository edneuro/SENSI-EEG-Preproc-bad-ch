function Xs = smoothFeature(X, smoothWin)
% X : [C x W] feature (R or Z)
% Xs: smoothed along windows via moving median; winsorized per channel
    if nargin<2||isempty(smoothWin), smoothWin=5; end
    Xs = movmedian(X, smoothWin, 2, 'omitnan');
    for c=1:size(Xs,1)
        x = Xs(c,:); q = quantile(x(~isnan(x)), [0.01 0.99]);
        if ~isempty(q), Xs(c,:) = min(max(x,q(1)), q(2)); end
    end
end
