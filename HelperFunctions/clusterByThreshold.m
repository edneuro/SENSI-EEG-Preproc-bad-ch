function [idx, info] = clusterByThreshold(D, eps)
%CLUSTERBYTHRESHOLD  Cluster channels by distance threshold.
%   [idx, info] = clusterByThreshold(D, eps)
%
% Inputs
%   D   : [n x n] symmetric distance matrix (finite, diag=0)
%   eps : threshold. Pairs with distance <= eps are linked.
%
% Outputs
%   idx : [n x 1] cluster ids (1..nComp)
%   info: struct with fields:
%         .A         : adjacency matrix (logical)
%         .eps       : threshold used
%         .nComp     : number of clusters
%         .compSizes : size of each cluster
%
% Notes
% - If eps is small, you get many tiny clusters (strict).
% - If eps is large, you get fewer, bigger clusters (loose).
% - This is equivalent to DBSCAN with minPts=1.

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

    n = size(D,1);
    if size(D,2) ~= n, error('D must be square'); end
    if any(~isfinite(D(:))), error('D contains non-finite values'); end

    % Build adjacency: edge if distance <= eps (excluding self)
    A = (D <= eps);
    A(1:n+1:end) = false;   % remove diagonal
    A = A & A.';            % symmetrize

    % Connected components = clusters
    G = graph(A);
    comp = conncomp(G).';
    idx = comp(:);

    % Info
    info.A = A;
    info.eps = eps;
    info.nComp = max(idx);
    info.compSizes = accumarray(idx,1);
end
