function Z = zScoreRobust(X)
% zScoreRobust  Robust z-scoring per channel using median & MAD.
%
%   Z = zScoreRobust(X)
%
%   Input:
%     X : [nChannels x nSamples] data matrix
%
%   Output:
%     Z : same size as X, each channel robustly z-scored
%
%   Formula:
%     z = (x - median(x)) / (1.4826 * MAD)
%
%   Notes:
%     - MAD = median(|x - median(x)|).
%     - 1.4826 scales MAD to be comparable to std for Gaussian data.
%     - Operates row-wise (per channel).
%     - Handles flat channels (MAD = 0) by returning zeros.
%     - Ignores NaNs in median and MAD.

    % Per-channel median
    med = median(X, 2, 'omitnan');     % [nCh x 1]

    % Median absolute deviation (about the median)
    madv = mad(X, 1, 2);               % [nCh x 1]

    % Robust scale estimate
    robStd = 1.4826 * madv;

    % Create output
    Z = (X - med) ./ robStd;

    % Handle flat channels (MAD == 0 → robStd == 0)
    flatIdx = (robStd == 0);
    if any(flatIdx)
        Z(flatIdx, :) = 0;
    end
end
