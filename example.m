

%% Load Data

clear; clc;

dataFolder = 'C:\Users\amilcar\Documents\Stanford\Data\BadChExample';
fileName = 'data.mat';
filepath = fullfile(dataFolder,fileName);
% load(filepath,'xAll_129', 'fs','INFO','EOG');
load(filepath);

%% Define Input variables for markSusChs


% Define output folder and name for figures
INFO.preprocFigDir = 'D:\Stanford\Figures\ISC'; % Folder so safe Figures
thisFnOut = ['Test' '1']; % Figure prefix

% Some Placeholders
INFO.badCh = [];  % Leave empty when initializing this file

% Windowing Varaibles
INFO.badChs.winSec = 10; % Time window (sec) - Max, Corr, and Var
INFO.badChs.hopSec = INFO.badChs.winSec; % Time skip per window (sec)

% Clustering variables
INFO.badChs.win_sec = 0.200; % Maxpool window in sec

% Distance Matrix Clustering Thresshold
INFO.badChs.eps = 0.8; % % This defines the number of clusters during bad
                      % channel detection. Higher eps lead to less clusters

% UI Plot Settings
INFO.badChs.minClusterUI = 7; % If > #Chs in cluster. Plot cluster in UI figure (e.g cluster #ch = 4, plot cluster)  
INFO.badChs.alpha = .25; % plot transparency 
INFO.badChs.nCols = 2;   % number of columns
INFO.badChs.ref = 36;    % reference channel

% Some Thresholds
INFO.badChs.chMax = 1000; % Channels with samples that reach this value will be declared as bad
INFO.badChs.neighborDissThresh = 0.6; % Channels w/ Neightbor Dissimilarity (time dependent)
                                     % >= to this value will be flagged

% Vertical Lines for plotBeforeAfter
tempRecOnsets = [];
% The example can use the following
tempRecOnsets = T.SampStart(T.TrialN == 1); 

% Save Figures
saveFigs = 1;

% Removing Reference Channel                                    
xAll_128 = xAll_129(1:128,:);

%% Main Function

%%% Code block 2 of 8: Instructions
% 1 - Ensure INFO.badChs fields are defined
% 2 - Run this block. markSusChs will automatically:
%     (a) compute suspicious/bad scores per channel,
%     (b) cluster channels and tag the eye cluster,
%     (c) render figures: cluster graph/heatmap and score plots,
%     (d) open a UI to review channel status (Green/Yellow/Red).
% 3 - In the UI, click channels to toggle status. Only Red channels
%     are finalized as bad. Close the UI when finished.
% 4 - If saveFigs = 1:
%       • The UI figure will temporarily freeze while saving.
%       • The horizontal scroll bar will disappear during this step.
%       • Once the scroll bar reappears, the figure is active again and
%         channel colors can be changed.
%       • The operator must click the "Done (return)" button in the UI to 
%         finalize changes. Only after saving will suspicious and bad 
%         channel lists be updated.
% 5 - Before and after confirmation figures are saved automatically if
%     saveFigs = 1.
% 6 - Command window will print cluster sizes and the current list of bad
%     channels.

[susMask, badChList, plotStruct] = markSusChs(xAll_128, fs, ...
    INFO, EOG, saveFigs, INFO.preprocFigDir, thisFnOut);

% Show channel clusters in Command Window
for thisi = 1:numel(plotStruct.clusters)
    fprintf('\tCluster %d: [%s]\n', thisi, ...
        sprintf('%d ', plotStruct.clusters{thisi}.'));
end


%% ===== Optional - Extra Manual inspection (no changes to badChList) =====

% Manually add to and/or remove from bad-channel list
manual.addBadCh    = [];   % user-added bad channels (unordered)
manual.neverRemove = [];   % channels that must be kept

% Manually Inspect Channels
manual.inspectCh      = [];     % e.g., [12 37 88]; leave [] to skip
manual.refCh          = 36;     % or INFO.badChs.ref if you prefer
manual.samplesToShow  = [];     % [] = full length; or [t0 t1] in samples


if isempty(manual.inspectCh)
    % no-op by design
else
    nCh = size(xAll_128,1);
    inspect = unique(manual.inspectCh(:)');
    inspect = inspect(inspect >= 1 & inspect <= nCh);

    t = 1:size(xAll_128,2);
    if isempty(manual.samplesToShow)
        idx = 1:numel(t);
    else
        t0 = max(0, manual.samplesToShow(1));
        t1 = min(t(end), manual.samplesToShow(2));
        idx = find(t >= t0 & t <= t1);
    end

    figure();
    tl = tiledlayout(length(manual.inspectCh), 1, "TileSpacing","compact","Padding","compact");
    title(tl, sprintf('Manual inspect vs refCh %d', manual.refCh), "Interpreter","none");

    for k = 1:numel(inspect)
        ax = nexttile(tl);
        plot(t(idx), xAll_128(manual.refCh, idx), 'LineWidth', 0.6, 'Color',[0.85, 0.325, 0.098]); hold on
        plot(t(idx), xAll_128(inspect(k),   idx), 'LineWidth', 0.6, 'Color',[0, 0.447, 0.741 0.25]);
        grid on; box off
        xlabel('Time (samples)'); ylabel('\muV');
        title(ax, sprintf('Ch %d vs Ref %d', inspect(k), manual.refCh));
        if k == 1
            legend({'Ref','Ch'}, 'Location','northeastoutside');
        end
    end
end


%% ===== Manually add to and/or remove from bad-channel list =====

% ===== Manually add to and/or remove from bad-channel list =====
thisnCh = size(xAll_128,1);
badChsPreCrop = unique(badChList(:)');              % start from auto
badChsPreCrop = union(badChsPreCrop, manual.addBadCh(:)');      % add user
badChsPreCrop = badChsPreCrop(badChsPreCrop >= 1 & badChsPreCrop <= thisnCh); % bounds
badChsPreCrop = setdiff(badChsPreCrop, unique(manual.neverRemove(:)'));   % enforce keepers
badChsPreCrop = unique(sort(badChsPreCrop));       % final (absolute)
fprintf('\n\tBad Channels = [%s]\n', num2str(badChsPreCrop));






%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% The commented code below only works with the SENSI 
%   Continuous Stimuli  Pipeline

% https://github.com/edneuro/SENSI-EEG-Preproc-CS-private

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% %% ===== Crop channels to desired range -> 128 to 124 Channels =====
% 
% keepRange = 1:124;  % choose channels to keep
% keepRange = keepRange(keepRange >= 1 & keepRange <= size(xAll_128,1));
% 
% xAll_124 = xAll_128(keepRange, :);
% 
% [isBadKept, locInKept] = ismember(badChListFinal, keepRange);
% badChListCrop = unique(sort(locInKept(isBadKept))); % indices relative to xAll_128
% 
% INFO.keepRange       = keepRange;
% INFO.badChListFinal  = badChListFinal;  % absolute (pre-crop)
% INFO.badChListCrop   = badChListCrop;   % relative to cropped data
% 
% 
% 
% %% === Plot Before and After Bad Channel Selection
% 
% % 1 - Run this block to visualize the data before and after bad channel removal.
% % 2 - The figure includes overlays, images, and feature plots for comparison.
% % 3 - Bad channels are temporarily imputed for correlation plots.
% 
% fprintf('\n ---- Plotting Before and after Bad Channel Selection ----\n');
% 
% % Temporarily fill bad channel rows with NaNs (for plotting only)
% tempX124 = fillBadChRows(xAll_124, badChsPostCrop);
% tempX124 = imputeAllNaN129(tempX124);
% 
% % Update bad channel after crop for before/after figure
% plotStruct.badChList = badChsPostCrop;
% 
% % Before/After Figure
% plotBeforeAfter(xAll_128, tempX124, plotStruct);
% 
% clear temp*;














%%



