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
