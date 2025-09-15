function [R, Rcell] = neighborCorrFromWindows(Xwin, forceNNeighbors, mode, neighborDir)
% neighborCorrFromWindows  Neighbor similarity per channel × window.
%
% Xwin            : [C x L x W] (channels × samples × windows)
% forceNNeighbors : (optional) integer; if provided, uses neighbors for 1:###
% mode            : 'medianRef' (default) or 'meanOfPairs'
% neighborDir     : (optional) folder containing neighboringElectrodes###.mat
%
% Outputs:
%   R     : [Cused x W] mean neighbor correlation per window
%   Rcell : {Cused x 1} (only for 'meanOfPairs'), each cell [Nnei x W]
%
% Notes:
% - Per window: de-mean each channel with nanmedian (omit NaNs).
% - Correlations use 'rows','pairwise' (NaN-safe).
% - 'medianRef': corr(channel, median(neighbors))  ← robust (recommended)
%   'meanOfPairs': mean_j corr(channel, neighbor_j) ← mirrors your original

    if nargin < 2 || isempty(forceNNeighbors), forceNNeighbors = []; end
    if nargin < 3 || isempty(mode), mode = 'medianRef'; end
    if nargin < 4, neighborDir = ''; end

    [C, ~, W] = size(Xwin);
    Cused = C;
    if ~isempty(forceNNeighbors)
        assert(forceNNeighbors <= C, 'forceNNeighbors exceeds #channels.');
        Cused = forceNNeighbors;
    end

    % Load neighbor map
    neiFn = sprintf('neighboringElectrodes%d.mat', Cused);
    if ~isempty(neighborDir)
        neiFn = fullfile(neighborDir, neiFn);
    end
    S = load(neiFn);                     % expects variable 'neighbors'
    neighbors = S.neighbors;

    R = nan(Cused, W);
    if strcmpi(mode, 'meanOfPairs'), Rcell = cell(Cused,1); else, Rcell = []; end

    for w = 1:W
        Xw = Xwin(1:Cused, :, w);               % [Cused x L]
        Xw = Xw - nanmedian(Xw, 2);            % de-mean per channel

        switch lower(mode)
            case 'medianref'
                for c = 1:Cused
                    nei = neighbors{c};
                    nei = nei(nei>=1 & nei<=Cused & nei~=c);
                    if isempty(nei), R(c,w) = NaN; continue; end
                    ref = nanmedian(Xw(nei, :), 1);
                    R(c,w) = corr(Xw(c,:).', ref(:), 'rows', 'pairwise');
                end

            case 'meanofpairs'
                for c = 1:Cused
                    nei = neighbors{c};
                    nei = nei(nei>=1 & nei<=Cused & nei~=c);
                    if isempty(nei), R(c,w) = NaN; continue; end
                    rlist = nan(numel(nei),1);
                    for j = 1:numel(nei)
                        rlist(j) = corr(Xw(c,:).', Xw(nei(j),:).', 'rows','pairwise');
                    end
                    R(c,w) = mean(rlist, 'omitnan');
                    Rcell{c}(:, w) = rlist;
                end

            otherwise
                error('Unknown mode: %s (use ''medianRef'' or ''meanOfPairs'')', mode);
        end
    end
end
