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
