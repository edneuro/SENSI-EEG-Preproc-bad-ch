function [xOut, win] = makeWindowsFromX(xIn, fs, winSec, hopSec)
% makeWindowsFromX  Slice xIn into overlapping, fixed-length windows.
% Inputs:
%   xIn    : [C x T] EEG (channels x samples)
%   fs     : sampling rate (Hz)
%   winSec : window length in seconds (e.g., 1.0)
%   hopSec : hop length in seconds (e.g., 0.5 for 50% overlap)
% Output (struct):
%   xOut       : [C x L x W] windows (L = winLen samples, W windows)
%   win.len    : window length in samples
%   win.hop    : hop in samples
%   win.starts : 1 x W start indices (1-based)
%   win.ends   : 1 x W end indices (inclusive)
%   win.W      : number of windows
%
% Notes:
% - The final window is forced to end at the last sample (no padding).
% - NaNs in xIn are preserved in xOut.
% - Memory: C*L*W doubles; if that's large for your session, we can switch
%   this to return just starts/ends and iterate in downstream functions.

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

    [C, T] = size(xIn);
    win.len = max(1, round(fs * winSec));
    win.hop = max(1, round(fs * hopSec));

    if T < win.len
        win.starts = 1;
        win.ends   = T;
    else
        lastStart = T - win.len + 1;
        win.starts = 1:win.hop:lastStart;
        if win.starts(end) ~= lastStart
            win.starts(end+1) = lastStart; % ensure last window ends at T
        end
        win.ends = win.starts + win.len - 1;
    end
    win.W = numel(win.starts);

    % Build [C x L x W] cube
    L = win.len; W = win.W;
    xOut = zeros(C, L, W, 'like', xIn);
    for w = 1:W
        idx = win.starts(w):win.ends(w);
        xOut(:, :, w) = xIn(:, idx);
    end


end
