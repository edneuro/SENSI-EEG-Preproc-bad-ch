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
