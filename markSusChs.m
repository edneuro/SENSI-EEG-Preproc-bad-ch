function [susMask, badChList, plotStruct] = markSusChs(xIn, fs, INFO, EOG, saveFigs, saveFolder, saveName)


%MARKSUSCHS  Automated suspicious/bad channel detection with interactive review.
%   [SUSMASK, BADCHLIST, PLOTSTRUCT] = MARKSUSCHS(XIN, FS, INFO, EOG, SAVEFIGS, SAVEFOLDER, SAVENAME)
%
%   This function computes automated bad-channel scores from multi-feature
%   analysis, clusters channels by high-Z events, tags the eye cluster, and
%   produces figures. An interactive UI then lets the user confirm or override
%   suspicious/bad channels. Only channels marked red (=bad) in the UI are
%   returned in BADCHLIST.
%
%   INPUTS
%     XIN         [nCh × nSamp] data matrix (channels × time). Assumed filtered
%                 and mean-centered. Units in µV.
%     FS          Scalar sampling rate (Hz).
%     INFO        Struct with configuration and file info. Required fields:
%                 INFO.badChs.winSec, hopSec, win_sec, eps, alpha, nCols, nRows, ref,
%                 chMax, minClusterUI. Also INFO.figure_folder and INFO.subject
%                 if saving figures.
%     EOG         Vector of EOG channel indices, or struct with index fields.
%                 Used to define the “eye cluster,” which is forced ≤ suspicious.
%     SAVEFIGS    Logical. If true, figures are saved to SAVEFOLDER.
%     SAVEFOLDER  Path for saving figures (created if missing). If empty and
%                 SAVEFIGS=true, current folder is used.
%     SAVENAME    Base filename/prefix for saved figures. If empty and
%                 SAVEFIGS=true, 'BadChannelFig' is used.
%
%   OUTPUTS
%     SUSMASK     [nCh × 1] integer flags per channel:
%                   0 = good, 1 = suspicious, 2 = bad
%                 (EOG channels forced down to ≤1).
%     BADCHLIST   Vector of channel indices marked red in the review UI.
%     PLOTSTRUCT  Struct containing feature values, cluster assignments, EOG
%                 mask, final status, and saving info, for downstream plotting.
%
%   METHOD
%     1) Neighbor dissimilarity:
%          - XIN windowed (winSec, hopSec).
%          - Correlations with neighbors → dissimilarity = 1 - |corr|.
%          - Smoothed, thresholded. nDissVal = fraction of windows above threshold.
%
%     2) Max amplitude:
%          - nMax = max(|XIN|) per channel.
%          - z_maxes = z-score of log(nMax).
%          - Channels with nMax ≥ chMax (µV) are forced bad.
%
%     3) Variability:
%          - z_var  = z-score of log(var(XIN)) over entire recording.
%          - z_var2 = z-score of the range of smoothed windowed variance.
%
%     4) Suspicious mask:
%          - susMask = logical combination of nDissVal, z_maxes, z_var, z_var2.
%          - Channels exceeding chMax forced to 2 (bad).
%          - EOG channels forced down to ≤1.
%
%     5) Clustering:
%          - Robust Z-scores (abs(Z) > zRoboustThreshold), pooled in win_sec*FS blocks.
%          - Jaccard distance matrix → cluster assignment (eps threshold).
%          - Eye cluster = cluster with most EOG indices.
%
%   FIGURES
%     fig1: Cluster graph + reordered distance heatmap
%     fig2: Channel score overview (neighbor dissimilarity, max amplitude,
%           variance features; open markers = eye cluster)
%     fig3: UI for channel review (saved before/after if SAVEFIGS=true)
%
%   DEPENDENCIES
%     zScoreRobust, makeWindowsFromX, neighborCorrFromWindows, smoothFeature,
%     jaccardDistanceChannels, clusterByThreshold, plotClustersGraphAndHeatmapV2,
%     plotBefore, reviewBadChsPaged
%
%
%   NOTES
%     • Data must be channels × time. Transpose if needed.
%     • Eye cluster is auto-forced ≤ suspicious but can be set to bad manually.
%     • If SAVEFIGS=true, UI will freeze temporarily while saving. Wait until
%       the scroll bar reappears, then continue review. Click "Save" in the UI
%       to finalize status updates.
%     • Thresholds are heuristic and may require tuning by dataset.

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

fprintf('\n -------- Detecting Bad Channels ---------\n')


%% Loading Variables

zRoboustThreshold = 14;

% Windowing Varaibles
winSec = INFO.badChs.winSec; % Time window (sec) - Max, Corr, and Var. Original = 10
hopSec = INFO.badChs.hopSec; % Time skip per window (sec)

% Clustering variables
win_sec = INFO.badChs.win_sec; % Maxpool window in sec. Original = 0.200
eps = INFO.badChs.eps; % Distance Matrix Clustering Thresshold. Original = 0.7

% UI Plot Settings
alpha = INFO.badChs.alpha;   % plot transparency. Original = .25
nCols = INFO.badChs.nCols;   % number of columns. Original = 2
ref = INFO.badChs.ref;       % reference channel. Original = 36 for EGI

% General Checks
channel_max = INFO.badChs.chMax; % Channels with samples that reach this value will be declared as bad
neighborDissThresh = INFO.badChs.neighborDissThresh; % NEIGHBOR DISSIMILARITY THRESHOLD

% Image saving
if saveFigs
    INFO.figure_folder = saveFolder;
    INFO.subject = saveName;
end


%% === General Chekcs (Time Dependent) ====


Z = zScoreRobust(xIn); % robust Z-score


% === General Chekcs (Time Dependent) ====

% 1) Neighbor Dissimilarity 
[xWin, ~] = makeWindowsFromX(xIn, fs, winSec, hopSec);

[nCorr, ~] = neighborCorrFromWindows(xWin);
nDiss = 1 - abs(nCorr);

smoothWin = 10;
nDissMov = smoothFeature(nDiss, smoothWin);

% nDissThres = nDissMov > 0.4;
nDissThres = nDissMov;
nDissThres(nDissThres<neighborDissThresh) = 0;

nDissVal = mean(nDissThres,2); % for suspecious score
nDissValb = mean(nDissMov,2); % plotting before fix


% 2) Max Absolute Values
nMax = max(abs(xIn),[],2);

z_maxes = zscore(log(nMax));
% z_maxes(z_maxes < 0) = 0; 
z_maxesb = z_maxes; % Plotting before fix
z_maxes(z_maxes < 2) = 0; % for suspecious score

bad_max = nMax >= channel_max; % This marks the Channel as bad


% 3) Variability
nVar = var(xIn, [], 2);
z_var = zscore(log(nVar));
z_varb = abs(z_var); % plotting before fix
z_var(z_var >= -2.5 & z_var <= 2) = 0;
z_var = abs(z_var);

[xWin, ~] = makeWindowsFromX(Z, fs, winSec, hopSec);
nVar = squeeze(var(xWin, 0, 2, 'omitnan'));   % → [nCh x nWin]
smoothWin = 10;
nVarMov = smoothFeature(nVar, smoothWin);
% nVars = var(nVarMov,[],2);
nVars = max(nVarMov,[],2) - min(nVarMov,[],2);
z_var2 = abs(zscore(log(nVars)));
z_var2b = z_var2; % plotting before fix
z_var2(z_var2 < 2) = 0;


%% === Clustering via Z-Score Robust Dissimilarity ====

% Finding high Z values for robust score
zFilt = abs(Z);
zFilt(zFilt <= zRoboustThreshold) = 0; % Only tag high Z-score

% Removed for improved performance
% columns_check = sum(zFilt,1); % Remove columns without bad Z-scores
% zFilt2 = zFilt(:,logical(columns_check)); 

win = round(win_sec*fs);

% Max pooling
[nCh, nSamp] = size(zFilt);
nBlocks = floor(nSamp / win);         % drop the tail if not divisible
Xtrim = zFilt(:, 1:nBlocks*win);
Xb = reshape(Xtrim, nCh, win, nBlocks);   % [ch × win × blocks]
Xmax_blocks = squeeze(max(Xb, [], 2));    % [ch × blocks]

Xlogical = logical(Xmax_blocks);



% Distance of robust z-score between channels
[D,~,~,~] = jaccardDistanceChannels(Xlogical);

% Clustering Distance Matrix
[idx, info] = clusterByThreshold(D, eps);   % link channels with distance <= 0.3

fprintf('\t# Clusters = %d\n', info.nComp)  % number of clusters
fprintf('\t# Channels per cluster = %s\n', num2str(info.compSizes.')) % sizes of clusters                    

% Grouping by Cluster
K = max(idx);                  % number of clusters
xClusters = cell(1,K);         % preallocate cell array
chClusters = cell(1,K);         % preallocate cell array

for c = 1:K
    xClusters{c} = xIn(idx==c, :);
    chClusters{c} = find(idx==c);
end

% Graph “constellation view”
% plotClustersGraphAndHeatmapV2(D, eps, idx, {'eye related','good','terrible'});
fig1 = plotClustersGraphAndHeatmapV2(D, eps, idx);

if saveFigs
    saveas(fig1, fullfile(INFO.figure_folder, [INFO.subject '_03a_BadChsClusters.png']));
end


%% === Define Bad and Suspecious Channels ====
susMask = sum([nDissVal, z_maxes, z_var, z_var2],2);
susMask = double(logical(susMask));
susMask(bad_max == 1) = 2;


%% Make sure EOG channels are not Bad
if isstruct(EOG)
    EOG = struct2cell(EOG);
    EOG = cat(2,EOG{:});
end
INFO.EOG = EOG;

susMask(EOG(susMask(EOG) == 2)) = 1; % Change EOG Bad to Suspecious

susChs = find(susMask~=0);


%% === Channels to Plot ====

suspectIds = cell(K,1);
susLabels = suspectIds;
eyeCheck = zeros(K,1);

for c = 1:K
    clusters = find(idx==c);
    suspectIds{c} = clusters;
    susLabels{c} = sprintf('Cluster %d', c);
    eyeCheck(c) = sum(ismember(EOG, clusters));
end

% Selecting Eye Channel Cluster
[~, eyeChCluster] = max(eyeCheck);
susLabels{eyeChCluster} = [susLabels{eyeChCluster}, ' - Eye Chs'];




% --- NEW: force eye-cluster channels to be at most "suspicious" (≤1) ---
eyeIdx = suspectIds{eyeChCluster};   % eye channels = whole eye cluster
isEyeBad = (susMask(eyeIdx) == 2);
susMask(eyeIdx(isEyeBad)) = 1;
% ----------------------------------------------------------------------

% Getting channels to plot (susIds)
susIds = {};
susLabs = {};
for c = 1:K
    susId = suspectIds{c};
    % susMember = ismember(susId,susChs);
    susMembers = intersect(susId,susChs);
    if length(susId) < INFO.badChs.minClusterUI
        susMembers = susId;
    end
    if sum(susMembers) > 0
        susIds{end+1} = susMembers;
        susLabs{end+1} = susLabels{c};
    end
end


%% === Suspecious Channel Flags Figure ===

plotStruct.nDissVal = nDissVal;
plotStruct.nDissValb = nDissValb;

plotStruct.z_maxes = z_maxes;
plotStruct.z_maxesb = z_maxesb;
plotStruct.z_max_thres = channel_max;

plotStruct.z_var = z_var;
plotStruct.z_varb = z_varb;

plotStruct.z_var2 = z_var2;
plotStruct.z_var2b = z_var2b;

plotStruct.nCh    = size(xIn,1);

eyeIdx = suspectIds{eyeChCluster};   % eye channels = whole eye cluster
plotStruct.nCh    = size(xIn,1);
allIdx = (1:nCh).';

plotStruct.isEye = ismember(allIdx, eyeIdx);
plotStruct.status = susMask; % status from susMask (0=good, 1=suspicious, 2=bad)



fig2 = plotBefore(plotStruct);

if saveFigs
    saveas(fig2, fullfile(INFO.figure_folder, [INFO.subject '_03b_BadChsScores.png']));
end


%% === UI Bad Channel Check ===

[susMask, badChList] = reviewBadChsPaged(xIn,[],susMask,susIds,...
    susLabs,INFO,1);

% Updaing Plotting Struct
plotStruct.status = susMask;
plotStruct.badChList = badChList;
plotStruct.winSec = winSec;
plotStruct.hopSec = hopSec;
plotStruct.saveFigs = saveFigs;
plotStruct.INFO = INFO;
plotStruct.fs = fs;
plotStruct.clusters = chClusters;

end