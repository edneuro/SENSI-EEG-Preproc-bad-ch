function [D, S, O, n] = jaccardDistanceChannels(X, opts)
%JACCARDDISTANCECHANNELS Jaccard distance with well-defined zero-event cases.
%   [D, S, O, n] = jaccardDistanceChannels_fixed(X, opts)
%
% Inputs
%   X    : [nCh x nSamp] data. If logical (0/1), used as-is; if numeric, thresholded.
%   opts.threshold : scalar or [nCh x 1] per-channel threshold (default 0 for numeric X)
%
% Outputs
%   D : [nCh x nCh] symmetric distance, in [0,1], diag=0
%   S : [nCh x nCh] Jaccard similarity, in [0,1], diag=1
%   O : [nCh x nCh] intersections (sum of AND)
%   n : [nCh x 1]   per-channel event counts (sum of ones)
%
% Rules enforced:
%   - If one channel has zero events and the other >0: D = 1 (S = 0)
%   - If both channels have zero events:               D = 0 (S = 1)
%   - Else: Jaccard: S = O / (n_i + n_j - O), D = 1 - S

    if nargin < 2, opts = struct; end
    if ~isfield(opts,'threshold'), opts.threshold = []; end

    % ---- Binarize ----
    if islogical(X)
        B = X;
    else
        thr = opts.threshold;
        if isempty(thr), thr = 0; end
        if isscalar(thr)
            B = X > thr;
        else
            thr = thr(:);
            assert(numel(thr)==size(X,1), 'threshold must be scalar or length nChannels');
            B = X > thr;  % implicit expansion row-wise
        end
    end
    B = logical(B);

    % ---- Intersections and counts ----
    O = double(B) * double(B.');   % O(i,j) = sum_t (bi & bj)
    n = sum(B,2);                  % n_i per channel  [nCh x 1]

    % ---- Unions ----
    nRow = n;              % [nCh x 1]
    nCol = n.';            % [1 x nCh]
    U = nRow + nCol - O;   % union counts

    % ---- Similarity (handle zero-union explicitly) ----
    S = O ./ U;            % standard Jaccard where U>0
    bothZero = (U==0);     % happens iff n_i==0 AND n_j==0
    S(bothZero) = 1;       % both empty → identical by convention

    % ---- Distance ----
    D = 1 - S;

    % Clean numerics & enforce symmetry/diagonals
    D = max(0, min(1, (D + D.')/2));
    S = max(0, min(1, (S + S.')/2));
    D(1:size(D,1)+1:end) = 0;
    S(1:size(S,1)+1:end) = 1;
end
