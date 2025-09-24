% preproc_2_specifyBadChEOG.m
% -----------------------------------
% Creator: Blair Kaneshiro, Oct 2024
% Maintainer: Blair Kaneshiro / Amilcar Malave
%
% This script identifies and removes bad EEG channels from MatRawEpoched data.
% Channels are first flagged automatically using the markSusChs() function, which
% computes multiple features (neighbor dissimilarity, max amplitude, variability)
% and clusters high-Z events. Eye channels are forced to be at most suspicious.
% A review UI is presented where the operator can confirm or override channel
% status (Green = Good, Yellow = Suspicious, Red = Bad). Only Red channels are
% removed. 
%
% Optional manual inspection is available to view specific channels against a
% reference without altering the automated bad channel list.
%
% After review, channels are cropped to electrodes 1:124, bad channels are removed,
% and a before/after comparison figure is generated. Candidate EOG channels are
% also plotted for possible override. 
%
% Outputs:
% - xRaw (124-channel matrix with bad channels removed)
% - INFO.badCh (final bad channel indices, relative to 1:124 data)
% - Figures: cluster overview, channel scores, UI before/after confirmation,
%   before/after comparison, candidate EOG
% - MatICAReady .mat file containing EOG, fs, INFO, Onsets, T, Triggers, xRaw

% Script history
% - 10/8/2024: Adapted from WTISC_preproc_1_preICA.m (previous pipeline)
%   and preproc_1_loadFilterEpoch.m (current pipeline)
% - 09/15/2025: Reworked by Amilcar Malave - Some automation

%% Set current run specifications, index files, print info about run

%%% Code block 1 of 8: Instructions
% 1 - Ensure items in 'one-time specifications' and 'per-run 
%     user-specified fields' sections are up to date.
% 2 - Run the code block.
% 3 - Confirm that command window output is as expected (file loaded).

clear all; close all; clc

disp('~ * ~ * Initiating ISC data cleaning (2 - MatRawEpoched) * ~ * ~')

%%%%%%%%%%%%%%%%%%% Begin one-time specifications %%%%%%%%%%%%%%%%%%%%%%%%

% Items in this section are set and then rarely or never updated. 

%%% Specify input directory
% Full path of MatRawEpoched (MRE) input directory
tempInDir = 'D:\Stanford\Data\ICS\MatRawEpoched';
% tempInDir = '/Volumes/LaPuffin/EdNeuroData/v2WTISCPreproc_2024/MatRawEpoched_devKnownBadRecordings20250318';

%%% Specify analyzer's initials
tempAnalyzer = 'AM';

%%%%%%%%%%%%%%%%%%%%% End one-time specifications %%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%% Begin per-run user-specified fields %%%%%%%%%%%%%%%%%%%

% User specifies items in this section for every file set. 

%%% Specify input MRE filename
% No '.mat' extension, e.g., 'WTISC_ENI_139_b1234'
tempInFn = 'WTISC_ENI_139_b1234'; 

%%% Whether to save figures
saveFigs = 1;

%%%%%%%%%%%%%%%%%%% End per-run user-specified fields %%%%%%%%%%%%%%%%%%%%

% Load the main file. This overrides the loaded INFO and EOG structs
load([tempInDir filesep tempInFn])

% Add current analyzer, input filename to INFO
INFO.preproc2_MRE_fNameLoaded = [tempInFn '.mat'];
INFO.preproc2_analyzer = tempAnalyzer;

% Print some messages
disp([newline 'Loaded input file ' INFO.preproc2_MRE_fNameLoaded '.'])

% Update MRE directory in INFO if curr specification is different. For
% example, if data are being analyzed on a different computer from the
% previous stage. 
if ~ strcmp(tempInDir, INFO.matRawEpochedDir)
    disp(['New input directory! Updating INFO.matRawEpochedDir.'])
    INFO.matRawEpochedDir = tempInDir;
end

clear temp*

disp([newline '\ * \ Code section complete (no figures) / * /'])


%% Starting Bad Channel Detection Algorithm

%%% Code block 2 of 8: Instructions
% 1 - Ensure INFO.badChs fields are defined in the config file.
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

% Updating INFO struct fields (just in case)
tempINFO = runConfig2Struct(INFO.configFn);
INFO.preprocFigDir = tempINFO.INFO.preprocFigDir; % Update Figure Folder
INFO.matICAReadyDir = tempINFO.INFO.matICAReadyDir;
INFO.badCh = tempINFO.INFO.badCh;
INFO.badChs = tempINFO.INFO.badChs;
thisFnOut = [INFO.fSaveStr INFO.sStr '_' INFO.blkStrUse];

% Removing Reference Electrode
xAll_128 = xAll_129(1:128,:); clear xAll_129;

% Running Automated Bad Channel Flagging script
[susMask, badChList, plotStruct] = markSusChs(xAll_128, fs, ...
    INFO, EOG, 1, INFO.preprocFigDir, thisFnOut);

% Show channel clusters in Command Window
for thisi = 1:numel(plotStruct.clusters)
    fprintf('\tCluster %d: [%s]\n', thisi, ...
        sprintf('%d ', plotStruct.clusters{thisi}.'));
end


%% ===== Optional - Extra Manual inspection (no changes to badChList) =====

%%% Code block 3 of 8: Instructions
% 1 - If desired, specify channels in manual.inspectCh to visualize against
%     a reference channel (manual.refCh). This is for visualization only
%     and does not alter the bad channel list.
% 2 - Optionally set manual.samplesToShow = [t0 t1] in samples to restrict
%     the time window.
% 3 - Leave manual.inspectCh empty [] to skip this step.
% 4 - Figures from this block are temporary and not saved.

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
    thisnCh = size(xAll_128,1);
    thisInspect = unique(manual.inspectCh(:)');
    thisInspect = thisInspect(thisInspect >= 1 & thisInspect <= thisnCh);

    thist = 1:size(xAll_128,2);
    if isempty(manual.samplesToShow)
        thisIdx = 1:numel(thist);
    else
        t0 = max(0, manual.samplesToShow(1));
        t1 = min(thist(end), manual.samplesToShow(2));
        thisIdx = find(thist >= t0 & thist <= t1);
    end

    figure();
    temptl = tiledlayout(length(manual.inspectCh), 1, "TileSpacing","compact","Padding","compact");
    title(temptl, sprintf('Manual inspect vs refCh %d', manual.refCh), "Interpreter","none");

    for thisk = 1:numel(thisInspect)
        thisax = nexttile(temptl);
        plot(thist(thisIdx), xAll_128(manual.refCh, thisIdx), 'LineWidth', 0.6, 'Color',[0.85, 0.325, 0.098]); hold on
        plot(thist(thisIdx), xAll_128(thisInspect(thisk),   thisIdx), 'LineWidth', 0.6, 'Color',[0, 0.447, 0.741 0.25]);
        grid on; box off
        xlabel('Time (samples)'); ylabel('\muV');
        title(thisax, sprintf('Ch %d vs Ref %d', thisInspect(thisk), manual.refCh));
        if thisk == 1
            legend({'Ref','Ch'}, 'Location','northeastoutside');
        end
    end
end


%% Update Bad Channels and Crop matrix to desire range - 128 to 124 Channels

%%% Code block 4 of 8: Instructions
% 1 - This block merges automated bad channels with manual.addBadCh,
%     removes any channels listed in manual.neverRemove, and crops the data
%     to electrodes 1:124.
% 2 - Confirm that the command window output lists the intended bad channels
%     before and after cropping.
% 3 - INFO.badCh is updated with the final list relative to the cropped data.
% 4 - Run this block once per file set.

% ===== Manually add to and/or remove from bad-channel list =====
thisnCh = size(xAll_128,1);
badChsPreCrop = unique(badChList(:)');              % start from auto
badChsPreCrop = union(badChsPreCrop, manual.addBadCh(:)');      % add user
badChsPreCrop = badChsPreCrop(badChsPreCrop >= 1 & badChsPreCrop <= thisnCh); % bounds
badChsPreCrop = setdiff(badChsPreCrop, unique(manual.neverRemove(:)'));   % enforce keepers
badChsPreCrop = unique(sort(badChsPreCrop));       % final (absolute)
fprintf('\n\tBad Channels = [%s]\n', num2str(badChsPreCrop));

% ===== Crop channels to desired range -> 128 to 124 Channels =====
keepRange = 1:124;  % choose channels to keep

% Retain electrodes 1:124 for further analysis
xAll_124 = xAll_128(keepRange, :);
fprintf('\n ------- Retaining Desired Electrodes -------');
fprintf('\n\tKeep Electrodes 1:%d',max(keepRange));

% If bad channel no in keeprange -> remove from bad channel list
[thisIsBadKept, thisLocInKept] = ismember(badChsPreCrop, keepRange);
badChsPostCrop = unique(sort(thisLocInKept(thisIsBadKept))); % indices relative to xAll_128
fprintf('\n\tBad Channels (Post Crop) = [%s]\n', num2str(badChsPostCrop));

% Updating INFO struct
INFO.badChs.keepRange       = keepRange;
INFO.badChs.badChsPreCrop  = badChsPreCrop;  % absolute (pre-crop)
INFO.badChs.badChsPostCrop   = badChsPostCrop;   % relative to cropped data
INFO.badCh = badChsPostCrop; % Bad channels in current recording

% Remove rows of bad channels from the data frame entirely
xAll_124(badChsPostCrop, :) = []; 


%% === Plot Before and After Bad Channel Selection

%%% Code block 5 of 8: Instructions
% 1 - Run this block to visualize the data before and after bad channel removal.
% 2 - The figure includes overlays, images, and feature plots for comparison.
% 3 - Bad channels are temporarily imputed for correlation plots.

fprintf('\n ---- Plotting Before and after Bad Channel Selection ----\n');

% Time samples of recording onsets
tempRecOnsets = T.SampStart(T.TrialN == 1);
plotStruct.tempRecOnsets = tempRecOnsets;

% Temporarily fill bad channel rows with NaNs (for plotting only)
tempX124 = fillBadChRows(xAll_124, badChsPostCrop);
tempX124 = imputeAllNaN129(tempX124);

% Update bad channel after crop for before/after figure
plotStruct.badChList = badChsPostCrop;

% Before/After Figure
plotBeforeAfter(xAll_128, tempX124, plotStruct);

clear temp*;

%% Plot and optionally save candidate EOG figure

%%% Code block 6 of 8: Instructions
% 1 - Run the code block.
% 2 - Review the figure to decide whether default EOG need to be
%     overridden. 

close all;

% Plot candidate EOG -- 2nd input excludes cheek electrodes 126 and 127. 
plotCandidateEOG(xAll_128, 0) % Use xAll_129 since we need the 125:128
sgtitle([INFO.sStr '_' INFO.blkStrUse ': Candidate EOG'], 'interpreter', 'none')

% disp([newline '\ * \ Code section complete (rendered 1 figure) / * /'])

%%% [optional] Save the EOG figure

if saveFigs

    % Make the output filename.
    thisFnOut = [INFO.fSaveStr INFO.sStr '_' INFO.blkStrUse ...
        '_04_candidateEOG.png'];

    % Specify save size width and height (will depend on number of files)
    thisFigSize = [14 8];

    % Call the 'saveCurrentFigure' function in the BKan repo. Inputs are
    % (1) output path, (2) output filename w/ extension, (3) figure save size
    % [width height], (4) figure handle (default gcf) (5) whether to print
    % message at the end (default true).
    saveCurrentFigure(INFO.preprocFigDir, thisFnOut, thisFigSize);
    disp([newline '\ * \ Code section complete (rendered and saved 1 figure) / * /'])

    clear this*
else
    disp([newline '\ * \ Code section complete (rendered 1 figure; no figures saved) / * /'])
end


%% Override default EOG if necessary and compute EOG data channels

%%% Code block 7 of 8: Instructions
% 1 - If and only if any EOG defaults need to be overriden, uncomment
%     assignments below and customize as desired. 
% 2 - Run the code block.

% Here are the default values: EOG.chVEOG [8 25]; EOG.chHEOG [1 32 125 128]

% LATER: Update EOG calculation if needed so that the resulting channels 
% are always on the same unit scale as the EEG data. 

%%% EOG ch assignment: Uncomment and edit ONLY if not using above defaults
% Acceptable VEOG specifications: [8 25]. If using just 8 or 25, function
%    call needs a 4th argument of '1' to override default options.
% Acceptable HEOG specifications: [1 32], [125 128], [1 32 125 128]

% EOG.chVEOG = [8 25];
% EOG.chHEOG = [1 32];
% EOG.chHEOG = [125 128];

%%% EOG ch calculation
[EOG.dataVEOG, EOG.dataHEOG] = computeEOG129(xAll_128, EOG.chVEOG, EOG.chHEOG);

close all

disp([newline '\ * \ Code section complete (no figures) / * /'])


%% Assign final raw data variable; clear vars; save

%%% Code block 8 of 8: Instructions
% 1 - Run the code block.

xRaw = xAll_124; % <-- xRaw is the raw data variable later input to ICA

INFO.preproc2_MIR_fNameSaved = INFO.preproc2_MRE_fNameLoaded;
INFO.preproc2_datetime = thisDateTime(1);

%%%%%%%%%%%%%%%%%%%%% Variables to clear %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear refCh saveFigs sus* xAll* xl bad* this* manual plotStruct
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Saving into MatICAReady (MIR) directory.
% 7 variables saved: EOG, fs, INFO, Onsets, T, Triggers, xRaw

save([INFO.matICAReadyDir filesep INFO.preproc2_MIR_fNameSaved])
disp([newline '\ * \ Code section complete (no figures) / * /'])
disp([newline '~ * ~ * MatICAReady file ' INFO.preproc2_MIR_fNameSaved ' was saved * ~ * ~'])