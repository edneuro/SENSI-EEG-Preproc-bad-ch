function [R, Rcell] = neighborCorrFromWindows(Xwin, forceNNeighbors, mode, neighborDir)
% neighborCorrFromWindows  Neighbor similarity per channel × window.
%
% Xwin            : [C x L x W] (channels × samples × windows)
% forceNNeighbors : (optional) integer; if provided, uses neighbors for 1:###
% mode            : 'medianOfPairs' (default) or 'medianRef'
% neighborDir     : (optional) folder containing neighboringElectrodes###.mat
%
% Outputs:
%   R     : [Cused x W] median neighbor correlation per window
%   Rcell : {Cused x 1} (only for 'medianOfPairs'), each cell [Nnei x W]
%
% Notes:
% - Per window: de-mean each channel with nanmedian (omit NaNs).
% - Correlations use 'rows','pairwise' (NaN-safe).
% - 'medianOfPairs': median_j corr(channel, neighbor_j) ← (recommended)
%   'medianRef': corr(channel, median(neighbors))   

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Reference (please cite):
%
% Module Citation:
%
% Malave, A. J., & Kaneshiro, B. (2025). Bad-Channel Detection Module (v1.1): A MATLAB
% framework for semi-automated EEG bad-channel detection and review. Stanford Uni-
% versity. https://github.com/edneuro/SENSI-EEG-Preproc-bad-ch
%
% Preprint Citation
%
% Amilcar J Malave and Blair Kaneshiro. “EEG Bad-Channel Detection Using Multi-
% Feature Thresholding and Co-occurrence of High-Amplitude Transients”. In: bioRxiv
% (2026). DOI: 10.64898/2026.02.04.703874

% MIT License
% 
% Copyright (c) 2025 Amilcar J. Malave, and Blair Kaneshiro.
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if nargin < 2 || isempty(forceNNeighbors), forceNNeighbors = []; end
    if nargin < 3 || isempty(mode), mode = 'medianOfPairs'; end
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
    if strcmpi(mode, 'medianOfPairs'), Rcell = cell(Cused,1); else, Rcell = []; end

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

            case 'medianofpairs'
                for c = 1:Cused
                    nei = neighbors{c};
                    nei = nei(nei>=1 & nei<=Cused & nei~=c);
                    if isempty(nei), R(c,w) = NaN; continue; end
                    rlist = nan(numel(nei),1);
                    for j = 1:numel(nei)
                        rlist(j) = corr(Xw(c,:).', Xw(nei(j),:).', 'rows','pairwise');
                    end
                    R(c,w) = median(rlist, 'omitnan');
                    Rcell{c}(:, w) = rlist;
                end

            otherwise
                error('Unknown mode: %s (use ''medianRef'' or ''medianOfPairs'')', mode);
        end
    end
end
