% example.m
% =========================================================================
% TUTORIAL: Bad-Channel Detection and Review using markSusChs.m
%
% This script demonstrates how to:
%   (1) Load example EEG data,
%   (2) Configure the Bad Channel Toolbox options (INFO.badChs),
%   (3) Run markSusChs.m to score and cluster channels,
%   (4) Interactively review suspicious channels in the UI,
%   (5) Optionally perform extra manual inspection and overrides.
%
% The goal is to provide a *guided* example that you can adapt to your own
% datasets (different folders, file names, and parameters).
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PREREQUISITES AND DEPENDENCIES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SAMPLE DATA (EXAMPLE FILES):
%    - Download the example .mat files (e.g., data1.mat, data2.mat, data3.mat)
%      and place them in a folder of your choice.
%    - Each file should contain, at minimum:
%        • Filtered Data: "xAll_129" in our examples ([129 x N] EEG (EGI-style)
%        • fs           : sampling rate (Hz)
%        • EOG          : EOG or aux channels used by markSusChs. Or define
%                         them on the script
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% 1. SETUP: PATHS, FILES, AND BASIC OPTIONS
% -------------------------------------------------------------------------
% IMPORTANT:
%   (a) Update "dataFolder" to point to the folder where you saved data#.mat
%   (b) Choose which example file to load by changing "fileName".
%   (c) Update "INFO.preprocFigDir" to where you want figures saved.
% -------------------------------------------------------------------------
clear; clc;

%%% Download Data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Folder containing example data#.mat files
dataFolder = 'ExampleData\'; % <-- Optional, EDIT WITH DESIRED FOLDER PATH
getExampleData_badChannel(dataFolder); % Downloading example data to desired folder

% Choose one example file:
%   'data1.mat' : Example dataset 1
%   'data2.mat' : Example dataset 2
%   'data3.mat' : Example dataset 3
fileName = 'data3.mat'; % <-- EDIT THIS

%%% FIGURE OUTPUT FOLDER %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Folder where tutorial figures (clusters, score plots, UI screenshots) are saved
INFO.preprocFigDir = 'Figures\'; % <-- Optional, EDIT WITH DESIRED FOLDER PATH

% Toggle saving of figures (1 = save, 0 = only show on screen)
saveFigs = 1; % <-- EDIT THIS

% Short prefix used in figure filenames
thisFnOut = ['Example_' fileName];  

filepath = fullfile(dataFolder,fileName);
% load(filepath,'xAll_129', 'fs','INFO','EOG');
load(filepath);

% Remove reference channel (assumes the 129th channel is reference)
xAll_128 = xAll_129(1:128,:); clear xAll_129;


%% 2. CONFIGURE markSusChs OPTIONS (INFO.badChs)
% -------------------------------------------------------------------------
% This section sets all key parameters used by markSusChs.m
% Adjust these for your own datasets as needed.
% -------------------------------------------------------------------------

% Initialize bad-channel list (empty for first run)
INFO.badCh = []; % Will be populated by markSusChs + manual decisions

%%% WINDOWING PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Time window in seconds for time-dependent features (max, corr, variance)
INFO.badChs.winSec = 10; % e.g., 10 s windows
INFO.badChs.hopSec = INFO.badChs.winSec; % hop size (no overlap here)

%%% CLUSTERING PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Window length (seconds) for max-pooled features before clustering
INFO.badChs.win_sec = 0.200; % e.g., 200 ms

% Distance matrix clustering threshold (eps for clustering)
% Higher eps -> channels are more easily grouped together -> fewer clusters.
INFO.badChs.eps = 0.8;

%%% UI PLOT SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Clusters with at most this many channels are shown in the UI figure one-by-one.
% Example: if a cluster has 4 channels and minClusterUI = 7 -> it will be plotted.
INFO.badChs.minClusterUI = 7; % 

INFO.badChs.alpha = .25; % plot transparency for overlays
INFO.badChs.nCols = 2;   % number of columns in UI plotting layout
INFO.badChs.ref = 36;    % Ref channel for visual comparison (not EEG reference).

%%% THRESHOLDS FOR BAD CHANNELS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Hard amplitude cutoff: any channel with samples exceeding this magnitude
% (in microvolts) is flagged as bad.
INFO.badChs.chMax = 1000; % e.g., ±1000 µV

% NEIGHBOR DISSIMILARITY THRESHOLD (time-dependent suspecious channel).
% Channels with median neighbor dissimilarity >= this value will be flagged.
INFO.badChs.neighborDissThresh = 0.3; 


%% 3. RUN markSusChs AND INTERACTIVE REVIEW
% -------------------------------------------------------------------------
% markSusChs performs:
%   (a) Feature computation and scoring of suspicious channels,
%   (b) Clustering of channels based on time-dependent similarity,
%   (c) Identification of an "eye cluster" (EOG-like channels),
%   (d) Rendering of cluster graph/heatmap and score plots,
%   (e) A UI for human validation of suspicious channels.
%
%%% UI INSTRUCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1 - Run this code block.
% 2 - markSusChs will compute bad-channel scores and open an interactive UI:
%       • Channels are colored: Green (keep), Yellow (suspicious), Red (bad).
%       • Click on channels to cycle their status (e.g., Yellow -> Red).
% 3 - Use the panels to inspect:
%       • Cluster-level patterns (channels sharing similar artifacts),
%       • Time courses and summary features.
% 4 - When you are satisfied with the selections:
%       • Click the "Done (return)" button inside the UI.
%       • The function will then finalize the list of bad channels.
% 5 - If saveFigs = 1:
%       • The UI figure will temporarily freeze while saving.
%       • The horizontal scroll bar may disappear and reappear once saving
%         is complete. Only then interact with the figure again.
% 6 - The command window will report:
%       • Cluster memberships, and
%       • The current list of bad channels.
% -------------------------------------------------------------------------

[susMask, badChList, plotStruct] = markSusChs(xAll_128, fs, ...
    INFO, EOG, saveFigs, INFO.preprocFigDir, thisFnOut);

% Show channel clusters in Command Window
for thisi = 1:numel(plotStruct.clusters)
    fprintf('\tCluster %d: [%s]\n', thisi, ...
        sprintf('%d ', plotStruct.clusters{thisi}.'));
end


%% 4. OPTIONAL: EXTRA MANUAL INSPECTION (NO CHANGE TO badChList)
% -------------------------------------------------------------------------
% Use this section if you want to visually compare specific channels to a
% reference channel before deciding whether to add/remove them as bad.
%
% STEPS:
%   1) Set manual.inspectCh to a list of channels (e.g., [12 37 88])
%   2) Optionally set manual.samplesToShow to [t0 t1] in samples
%      (leave [] to see the full recording).
%   3) Run this block to open a multi-panel figure.
%   4) Use what you see here to inform manual.addBadCh / manual.neverRemove
%      in the next section.
% -------------------------------------------------------------------------

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


%% 5. OPTIONAL: ADDING MANUAL OVERRIDES OF BAD-CHANNEL LIST
% -------------------------------------------------------------------------
% This step creates a *final* bad-channel list that combines:
%   - Automatic decisions from markSusChs (badChList),
%   - Any channels added manually (manual.addBadCh),
%   - Channels that must never be removed (manual.neverRemove).
%
% The result, badChsPreCrop, is the final bad-channel list relative to the
% current data matrix xAll_128.
% -------------------------------------------------------------------------

% ===== Manually add to and/or remove from bad-channel list =====
thisnCh = size(xAll_128,1);
badChsPreCrop = unique(badChList(:)');              % start from auto
badChsPreCrop = union(badChsPreCrop, manual.addBadCh(:)');      % add user
badChsPreCrop = badChsPreCrop(badChsPreCrop >= 1 & badChsPreCrop <= thisnCh); % bounds
badChsPreCrop = setdiff(badChsPreCrop, unique(manual.neverRemove(:)'));   % enforce keepers
badChsPreCrop = unique(sort(badChsPreCrop));       % final (absolute)
fprintf('\n\tBad Channels = [%s]\n', num2str(badChsPreCrop));


%% 6. QUICK VISUAL CHECK: BEFORE vs AFTER BAD-CHANNEL REMOVAL
% -------------------------------------------------------------------------
% This section provides a simple visualization of the effect of bad-channel
% removal:
%
%  - Top subplot  : overlay of ALL channels (xAll_128)
%  - Bottom subplot: overlay of ONLY the "good" channels
% -------------------------------------------------------------------------

% Logical mask of good channels (relative to xAll_128)
goodChMask = true(thisnCh,1);
goodChMask(badChsPreCrop) = false;

% Before = all channels, After = only good channels
xBefore = xAll_128;              % [128 x N]
xAfter  = xAll_128(goodChMask,:);% [Ngood x N]

% Time vector (seconds)
nSamples = size(xBefore,2);
t = (0:nSamples-1) / fs;

figure('Name','Bad Channel Removal: Before vs After','Color','w');
tiledlayout(2,1,"TileSpacing","compact","Padding","compact");

% ---------- TOP: BEFORE (all channels) ----------
ax1 = nexttile;
plot(t, xBefore);
box off;
xlabel('Time (s)');
ylabel('\muV');
title(sprintf('Before bad-channel removal (%d channels)', size(xBefore,1)), ...
    'Interpreter','none');

% ---------- BOTTOM: AFTER (good channels only) ----------
ax2 = nexttile;
plot(t, xAfter);
box off;
xlabel('Time (s)');
ylabel('\muV');
title(sprintf('After bad-channel removal (%d channels kept)', size(xAfter,1)), ...
    'Interpreter','none');

linkaxes([ax1 ax2],'x');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This Module was created for SENSI Continuous Stimuli  Pipeline
% https://github.com/edneuro/SENSI-EEG-Preproc-CS-private

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%















