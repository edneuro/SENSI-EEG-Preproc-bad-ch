function fig2 = plotBefore(plotStruct)

% plotBefore  Overview of per-channel quality metrics prior to manual review.
%
%   plotBefore(PLOTSTRUCT) visualizes the automated bad-channel features
%   (neighbor dissimilarity, max amplitude, and variance metrics) for all
%   channels, using the current status labels in PLOTSTRUCT. Eye-related
%   channels are highlighted for reference. This figure provides diagnostic
%   context for why channels were flagged before user interaction.

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

nDissVal = plotStruct.nDissVal;
nDissValb = plotStruct.nDissValb;

z_maxes = plotStruct.z_maxes;
z_maxesb = plotStruct.z_maxesb;
channel_max = plotStruct.z_max_thres;

z_var = plotStruct.z_var;
z_varb = plotStruct.z_varb;

z_var2 = plotStruct.z_var2;
z_var2b = plotStruct.z_var2b;

nCh = plotStruct.nCh;

% eyeIdx = plotStruct.eyeIdx;
% allIdx = plotStruct.allIdx;

status = plotStruct.status; % status from susMask (0=good, 1=suspicious, 2=bad)

isEye    = plotStruct.isEye;
isNonEye = ~isEye;



% colors
colGood = [0.13 0.69 0.30];   % green
colSus  = [0.98 0.78 0.19];   % yellow
colBad  = [0.89 0.10 0.11];   % red



fig2 = figure('Name','Channel Flags (fig2)','Color','w','Position',[100 100 1200 600]);


% [ch1,nSamples] = size(xIn);
% t = 1:nSamples;

% % 1st Plot - Bad Channel Overlay
% subplot(3,2,1);
% plot(t,xIn); hold on;
% title(sprintf('%s-Channel data overlay',ch1))
% ylabel('μV');
% xlabel('Time (Samples)')
% 
% 
% % 2nd Plot - Good Channel Overlay
% subplot(3,2,2);
% plot(t,xIn); hold on;
% title(sprintf('%s-Channel data overlay',ch2))
% ylabel('μV');
% xlabel('Time (Samples)')
% 
% 
% % 3rd Plot - Bad Channel Imagesc
% subplot(5,2,3);
% imagesc(abs(xIn));
% title(sprintf('%s-Channel data image (abs)',ch1))
% ylabel('Electrodes');
% xlabel('Time (Samples)')
% tempH = colorbar;
% tempH.Location = 'southoutside';
% tempH.Label.String = 'abs(\muV)';
% 
% 
% % 4th Plot - Good Channel Imagesc
% subplot(5,2,4);
% imagesc(abs(xGood));
% title(sprintf('%s-Channel data image (abs)',ch1))
% ylabel('Electrodes');
% xlabel('Time (Samples)')
% tempH = colorbar;
% tempH.Location = 'southoutside';
% tempH.Label.String = 'abs(\muV)';


% ---------- (1) Neighbor dissimilarity (time-aggregated) ----------


tiledlayout(3,2,'TileSpacing','compact','Padding','compact');


nexttile(1); hold on;
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

% ---------- (2) Max amplitude (z-score of log |x|); red = max ≥ channel_max µV ----------

nexttile(3); hold on;

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

title(['Max amplitude - Red marks channels with max ≥', num2str(channel_max), 'μV']);
ylabel('z-score of log |x|');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (3) Variability: overall & temporal (shared x, no shift) ----------
% z_var  = z-score of log(variance) across the full recording (overall variability)
% z_var2 = z-score of log(range of windowed variance) (temporal variability)

nexttile(5); hold on;


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

title('Variance (circles) & Windowed-variance range (squares)');
ylabel('z-score'); xlabel('Channel #');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;




% ---------- (1) Neighbor dissimilarity (time-aggregated) ----------

nexttile(2); hold on;

y = nDissVal;

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

title('Neighbor dissimilarity (time-aggregated) - Threshold for Sus Channels');
ylabel('dissimilarity');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (2) Max amplitude (z-score of log |x|); red = max ≥ 1000 µV ----------

nexttile(4); hold on;

y = z_maxes;   % dimensionless z-score

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

title('Max amplitude - Threshold z>2');
ylabel('z-score of log |x|');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;

% ---------- (3) Variability: overall & temporal (shared x, no shift) ----------
% z_var  = z-score of log(variance) across the full recording (overall variability)
% z_var2 = z-score of log(range of windowed variance) (temporal variability)

nexttile(6); hold on;


% z_var (overall) — circles
y = z_var;
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
y = z_var2;
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

title('Variance (circles) -2.5>z>2 & Windowed-variance range (squares) |z|>2');
ylabel('z-score'); xlabel('Channel #');
xlim([0.5 nCh+0.5]); xticks(5:5:nCh); grid on;




sgtitle('Sus Channel flags — Eye cluster shown with open markers');