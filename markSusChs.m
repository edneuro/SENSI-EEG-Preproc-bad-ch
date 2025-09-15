function Out1 = markSusChs(xIn, fs, INFO, EOG, safeFigs)



% Windowing Varaibles
winSec = 10; % Time window (sec) - Max, Corr, and Var
hopSec = winSec; % Time skip per window (sec)

% Clustering variables
win_sec = 0.200; % Maxpool window in sec
eps = 0.7; % Distance Matrix Clustering Thresshold

% Plot Settings
alpha = .25;
nCols = 2;
ref = 30;



% === Creating Output folder ===
% Image saving
if safeFigs
    figure_folder = [INFO.preprocFigDir, filesep, 'BadChannels'];
    if exist(figure_folder, 'dir') == 0 
        mkdir(figure_folder)
    end
    
    subject = [INFO.fSaveStr, INFO.sStr, '_', INFO.blkStrUse];
    INFO.figure_folder = figure_folder;
    INFO.subject = subject;
end

Z = zScoreRobust(xIn); % robust Z-score



% === General Chekcs (Time Dependent) ====

% 1) Neightbor Dissimilarity 
[xWin, ~] = makeWindowsFromX(xIn, fs, winSec, hopSec);

[nCorr, ~] = neighborCorrFromWindows(xWin);
nDiss = 1 - abs(nCorr);

smoothWin = 10;
nDissMov = smoothFeature(nDiss, smoothWin);

% nDissThres = nDissMov > 0.4;
nDissThres = nDissMov;
nDissThres(nDissThres<0.3) = 0;

nDissVal = mean(nDissThres,2); % for suspecious score


% 2) Max Absolute Values
nMax = max(abs(xIn),[],2);

z_maxes = zscore(log(nMax));
% z_maxes(z_maxes < 0) = 0; 
z_maxes(z_maxes < 2) = 0; % for suspecious score

bad_max = nMax >= 1000; % This marks the Channel as bad


% 3) Variability

nVar = var(xIn, [], 2);
z_var = zscore(log(nVar));
z_var(z_var >= -2.5 & z_var <= 2) = 0;
z_var = abs(z_var);

[xWin, ~] = makeWindowsFromX(Z, fs, winSec, hopSec);
nVar = squeeze(var(xWin, 0, 2, 'omitnan'));   % → [nCh x nWin]
smoothWin = 10;
nVarMov = smoothFeature(nVar, smoothWin);
nVars = var(nVarMov,[],2);
nVars = max(nVarMov,[],2) - min(nVarMov,[],2);
z_var2 = abs(zscore(log(nVars)));
z_var2(z_var2 < 2) = 0;




% === Clustering via Z-Score Robust Dissimilarity ====
Z = zScoreRobust(xIn); % robust Z-score

zFilt = abs(Z);
zFilt(zFilt <= 14) = 0; % Only tag high Z-score

columns_check = sum(zFilt,1); % Remove columns without bad Z-scores
zFilt2 = zFilt(:,logical(columns_check)); 


win = round(win_sec*fs);

% Max pooling
[nCh, nSamp] = size(zFilt2);
nBlocks = floor(nSamp / win);         % drop the tail if not divisible
Xtrim = zFilt2(:, 1:nBlocks*win);
Xb = reshape(Xtrim, nCh, win, nBlocks);   % [ch × win × blocks]
Xmax_blocks = squeeze(max(Xb, [], 2));    % [ch × blocks]

Xlogical = logical(Xmax_blocks);

% Distance of robust z-score between channels
[D,~,~,~] = jaccardDistanceChannels(Xlogical);

% Clustering Distance Matrix
[idx, info] = clusterByThreshold(D, eps);   % link channels with distance <= 0.3

disp(info.nComp);                          % number of clusters
disp(info.compSizes);                      % sizes of clusters

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
plotClustersGraphAndHeatmapV2(D, eps, idx);



% === Define Bad and Suspecious Channels ====
susMask = sum([nDissVal, z_maxes, z_var, z_var2],2);
susMask = double(logical(susMask));
susMask(bad_max == 1) = 2;

% Make sure EOG channels are not Bad
if isstruct(EOG)
    EOG = struct2cell(EOG);
    EOG = cat(2,EOG{:});
end
susMask(EOG(susMask(EOG) == 2)) = 1; % Change EOG Bad to Suspecious

susChs = find(susMask~=0);

%%

% === Initializing Clustering analysis ====
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

susIds = {};
susLabs = {};
for c = 1:K
    susId = suspectIds{c};
    susMember = ismember(susId,susChs);
    if sum(susMember) > 0
        susIds{end+1} = susId(susMember);
        susLabs{end+1} = susLabels{c};
    end
end

%%



[susMask, badChList] = reviewBadChsUI(xIn,[],susMask,susIds,...
    susLabs,INFO,nCols,ref,alpha,0);













end
