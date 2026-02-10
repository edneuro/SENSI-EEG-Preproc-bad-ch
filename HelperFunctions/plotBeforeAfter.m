function fig = plotBeforeAfter(xIn, xGood, plotStruct)

% plotBeforeAfter  Comparison of channel status before and after manual review.
%
%   plotBeforeAfter(PLOTSTRUCT_BEFORE, PLOTSTRUCT_AFTER) contrasts the
%   automated channel flags with the final user-confirmed labels, highlighting
%   channels whose status changed during review. This figure documents the
%   effect of human intervention in the bad-channel decision process.

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

%% === Loading Plotting Variables ===

% nDissVal = plotStruct.nDissVal;
nDissValb = plotStruct.nDissValb;

% z_maxes = plotStruct.z_maxes;
z_maxesb = plotStruct.z_maxesb;

% z_var = plotStruct.z_var;
z_varb = plotStruct.z_varb;

% z_var2 = plotStruct.z_var2;
z_var2b = plotStruct.z_var2b;

nCh = plotStruct.nCh;

status = plotStruct.status; % status from susMask (0=good, 1=suspicious, 2=bad)

saveFigs = plotStruct.saveFigs;
INFO = plotStruct.INFO;

isEye    = plotStruct.isEye;
isNonEye = ~isEye;

% colors
colGood = [0.13 0.69 0.30];   % green
colSus  = [0.98 0.78 0.19];   % yellow
colBad  = [0.89 0.10 0.11];   % red

tempRecOnsets = plotStruct.tempRecOnsets;

%% === Good channels flags ===

winSec = plotStruct.winSec;
hopSec = plotStruct.hopSec;
badChList = plotStruct.badChList;
fs = plotStruct.fs;

% Keep good channels
isGood = 1:size(xGood,1);


Z2 = zScoreRobust(xGood); % robust Z-score


% === General Chekcs (Time Dependent) after Fix ====
% 1) Neightbor Dissimilarity 
[xWin, ~] = makeWindowsFromX(xGood, fs, winSec, hopSec);

[nCorr, ~] = neighborCorrFromWindows(xWin);
nDiss = 1 - abs(nCorr);

smoothWin = 10;
nDissMov = smoothFeature(nDiss, smoothWin);

nDissVala = mean(nDissMov,2); % plotting before fix



% 2) Max Absolute Values
nMax = max(abs(xGood),[],2);

z_maxes = zscore(log(nMax));
% z_maxes(z_maxes < 0) = 0; 
z_maxesa = z_maxes; % Plotting before fix

% 3) Variability
nVar = var(xGood, [], 2);
z_var = zscore(log(nVar));
z_vara = abs(z_var); % plotting before fix

[xWin, ~] = makeWindowsFromX(Z2, fs, winSec, hopSec);
nVar = squeeze(var(xWin, 0, 2, 'omitnan'));   % → [nCh x nWin]
smoothWin = 10;
nVarMov = smoothFeature(nVar, smoothWin);
% nVars = var(nVarMov,[],2);
nVars = max(nVarMov,[],2) - min(nVarMov,[],2);
z_var2 = abs(zscore(log(nVars)));
z_var2a = z_var2; % plotting before fix




%% === Plotting Section ===



% fig2 = figure('Name','Channel Flags (fig2)','Color','w','Position',[100 100 1200 600]);
fig = figure('Name','Before and After','Position',[350 0 950 950]);

% tiledlayout(5,2,'TileSpacing','tight','Padding','tight');


[ch1,~] = size(xIn);
[ch2,~] = size(xGood);
% t = 1:nSamples;


% 1st Plot - Bad Channel Overlay
% nexttile;
subplot(6,2,1);
% plot(t,xIn); hold on;
plotEEGOverlay(xIn, tempRecOnsets(2:end))
title(sprintf('%d-Channel data overlay',ch1))
ylabel('μV');
xlabel('Time (Samples)')


% 2nd Plot - Good Channel Overlay
% nexttile;
subplot(6,2,2);
% plot(t,xGood); hold on;
plotEEGOverlay(xGood, tempRecOnsets(2:end))
title(sprintf('%d-Channel data overlay',ch2))
ylabel('μV');
xlabel('Time (Samples)')


% 3rd Plot - Bad Channel Imagesc
% nexttile;
subplot(6,2,[3 5]);
imagesc(abs(xIn)); box off
pbaspect([2.5 1 1]);
title(sprintf('%d-Channel data image (abs)',ch1))
ylabel('Electrodes');
xlabel('Time (Samples)')
tempH = colorbar;
tempH.Location = 'southoutside';
tempH.Label.String = 'abs(\muV)';


% 4th Plot - Good Channel Imagesc
% nexttile;
subplot(6,2,[4 6]);
imagesc(abs(xGood)); box off
pbaspect([2.5 1 1]);
title(sprintf('%d-Channel data image (abs)',ch1))
ylabel('Electrodes');
xlabel('Time (Samples)')
tempH = colorbar;
tempH.Location = 'southoutside';
tempH.Label.String = 'abs(\muV)';


% ---------- (1) Neighbor dissimilarity (time-aggregated) ----------
% nexttile(5); hold on;
subplot(6,2,7); hold on;
y = nDissValb;

for s = 0:2
    c = find(status==s & isNonEye);  % non-eye (filled)
    if ~isempty(c)
        h = stem(c, y(c), 'o', 'LineWidth', 1); 
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);     % eye (open)
    if ~isempty(e)
        h = stem(e, y(e), 'o', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

title('Neighbor dissimilarity (time-aggregated)');
ylabel('dissimilarity');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (2) Max amplitude (z-score of log |x|); red = max ≥ 1000 µV ----------
% nexttile(7); hold on;
subplot(6,2,9); hold on;
y = z_maxesb;   % dimensionless z-score

for s = 0:2
    c = find(status==s & isNonEye);
    if ~isempty(c)
        h = stem(c, y(c), 'o', 'LineWidth', 1);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);
    if ~isempty(e)
        h = stem(e, y(e), 'o', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

title('Max amplitude (z-score of log |x|)');
ylabel('z-score');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (3) Variability: overall vs. temporal (shared x, no shift) ----------
% z_var  = z-score of log(variance) across the full recording (overall variability)
% z_var2 = z-score of log(range of windowed variance) (temporal variability)

% nexttile(9); hold on;
subplot(6,2,11); hold on;

% z_var (overall) — circles
y = z_varb;
for s = 0:2
    c = find(status==s & isNonEye);
    if ~isempty(c)
        h = stem(c, y(c), 'o', 'LineWidth', 1);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);
    if ~isempty(e)
        h = stem(e, y(e), 'o', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

% z_var2 (temporal) — squares, at the SAME x (no offset)
y = z_var2b;
for s = 0:2
    c = find(status==s & isNonEye);
    if ~isempty(c)
        h = stem(c, y(c), 's', 'LineWidth', 1);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);
    if ~isempty(e)
        h = stem(e, y(e), 's', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

title('Variability (circles) & Windowed-variance range (squares)');
ylabel('z-score'); xlabel('Channel #');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;







status = status(isGood);
isEye = isEye(isGood);
isNonEye = isNonEye(isGood);


% ---------- (1) Neighbor dissimilarity (time-aggregated) ----------
% nexttile(6); hold on;
subplot(6,2,8); hold on;

y = nDissVala;

for s = 0:2
    c = find(status==s & isNonEye);  % non-eye (filled)
    if ~isempty(c)
        h = stem(c, y(c), 'o', 'LineWidth', 1); 
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);     % eye (open)
    if ~isempty(e)
        h = stem(e, y(e), 'o', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

title('Neighbor dissimilarity (time-aggregated)');
ylabel('dissimilarity');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (2) Max amplitude (z-score of log |x|); red = max ≥ 1000 µV ----------
% nexttile(8); hold on;
subplot(6,2,10); hold on;


y = z_maxesa;   % dimensionless z-score

for s = 0:2
    c = find(status==s & isNonEye);
    if ~isempty(c)
        h = stem(c, y(c), 'o', 'LineWidth', 1);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);
    if ~isempty(e)
        h = stem(e, y(e), 'o', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

title('Max amplitude (z-score of log |x|)');
ylabel('z-score');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (3) Variability: overall vs. temporal (shared x, no shift) ----------
% z_var  = z-score of log(variance) across the full recording (overall variability)
% z_var2 = z-score of log(range of windowed variance) (temporal variability)
% nexttile(10); hold on;
subplot(6,2,12); hold on;


% z_var (overall) — circles
y = z_vara;
for s = 0:2
    c = find(status==s & isNonEye);
    if ~isempty(c)
        h = stem(c, y(c), 'o', 'LineWidth', 1);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);
    if ~isempty(e)
        h = stem(e, y(e), 'o', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

% z_var2 (temporal) — squares, at the SAME x (no offset)
y = z_var2a;
for s = 0:2
    c = find(status==s & isNonEye);
    if ~isempty(c)
        h = stem(c, y(c), 's', 'LineWidth', 1);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor',colGood);
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor',colSus);
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor',colBad);
        end
    end
    e = find(status==s & isEye);
    if ~isempty(e)
        h = stem(e, y(e), 's', 'LineWidth', 1.2);
        switch s, case 0, set(h,'Color',colGood,'MarkerFaceColor','none');
                   case 1, set(h,'Color',colSus, 'MarkerFaceColor','none');
                   case 2, set(h,'Color',colBad, 'MarkerFaceColor','none');
        end
    end
end

title('Variability (circles) & Windowed-variance range (squares)');
ylabel('z-score'); xlabel('Channel #');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;


sgtitle('Before and After Bad Channel Selection');



if saveFigs
    saveas(fig, fullfile(INFO.figure_folder, [INFO.subject '_03d_BadChsScores.png']));
end


end