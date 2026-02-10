function [maskOut,badList] = reviewBadChsPaged(X,t,maskIn,groups,titles,INFO,saveFigs)
% reviewBadChsPaged  Paged UI for reviewing bad channels
%
% [maskOut,badList] = reviewBadChsPaged(X,t,maskIn,groups,titles,INFO,saveFigs)
%
% Inputs:
%   X        : [nCh x nT] data
%   t        : [1 x nT] time (default = 1:nT)
%   maskIn   : [nCh x 1] tri-state mask {0=good,1=suspicious,2=bad}
%   groups   : 1×S cell of channel-index vectors (clusters)
%   titles   : 1×S cell of cluster names
%   INFO.badChs.ref    : [] | scalar | 1×nT reference trace
%   INFO.badChs.nCols  : # columns per page
%   INFO.badChs.nRows  : # rows per page
%   INFO.badChs.alpha  : data-line transparency
%   saveFigs : 0/1 snapshot PNGs
%
% Outputs:
%   maskOut  : updated tri-state mask
%   badList  : channel indices where maskOut==2

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

    %— Defaults & validation
    if nargin<2||isempty(t), t = 1:size(X,2); end
    if nargin<5||isempty(titles), titles = repmat({''},1,numel(groups)); end
    if nargin<7, saveFigs = 0; end

    sgtitleFontSize = 16;
    titleFontSize = 16;

    [nCh,nT] = size(X);
    maskOut  = double(maskIn(:));
    assert(all(ismember(maskOut,[0 1 2])),'maskIn must be 0/1/2');
    assert(iscell(groups)&&iscell(titles)&&numel(groups)==numel(titles));

    %— Pull INFO.badChs settings
    bc = INFO.badChs;
    if ~isfield(bc,'ref'),   bc.ref   = [];  end
    if ~isfield(bc,'nCols'), bc.nCols = 2;   end
    if ~isfield(bc,'nRows'), bc.nRows = 3;   end
    if ~isfield(bc,'alpha'), bc.alpha = 0.5; end
    INFO.badChs = bc;
    nCols = bc.nCols; nRows = bc.nRows; alpha = bc.alpha; ref = bc.ref;

    %— Prepare reference trace
    if isempty(ref)||(isscalar(ref)&&ref==0)
        refTrace = [];
    elseif isscalar(ref)
        refTrace = X(ref,:);
    else
        assert(isrow(ref)&&numel(ref)==nT,'badChs.ref must be 1×nT');
        refTrace = ref;
    end

    %— Colors & helper
    colRef     = [0.35 0.35 0.35];
    colGood    = [0.00 0.45 0.00]; tcolGood=[0.00 0.30 0.00];
    colSusp    = [0.80 0.62 0.10]; tcolSusp=[0.55 0.38 0.05];
    colBad     = [0.70 0.25 0.25]; tcolBad =[0.50 0.10 0.10];
    rgba = @(c,a)[c(:).',a];

    %— Compute tight x-limits
    pad = 0.01; tr = max(1e-9,t(end)-t(1));
    xL = [t(1)-pad*tr, t(end)+pad*tr];

    %— Build pages per cluster
    pages = struct('cluster',{},'i0',{},'i1',{});
    cap   = nRows * nCols;
    S     = numel(groups);
    for s=1:S
        chs = groups{s}(:);
        n   = numel(chs);
        if n==0
            pages(end+1) = struct('cluster',s,'i0',1,'i1',0); %#ok<AGROW>
        else
            k=1;
            while k<=n
                pages(end+1) = struct('cluster',s,'i0',k,'i1',min(k+cap-1,n)); %#ok<AGROW>
                k = k + cap;
            end
        end
    end
    P = numel(pages);
    savedBefore = false(1,P);
    currentPage = 1;
    currentTL   = [];

    %— Create figure & top controls
    fig = figure('Name','QC (Paged)','NumberTitle','off','Color','w', ...
        'Units','normalized','Position',[.07 .07 .86 .86], ...
        'WindowKeyPressFcn',@onKey,'Renderer','opengl');
    ctrlH = 0.08;
    ctrl  = uipanel(fig,'Units','normalized','Position',[0 1-ctrlH 1 ctrlH],...
        'BackgroundColor',[.97 .97 .97],'BorderType','none');
    content = uipanel(fig,'Units','normalized','Position',[0 0 1 1-ctrlH],...
        'BackgroundColor','w','BorderType','none');

    uicontrol(ctrl,'Style','pushbutton','String','< Back','Units','normalized',...
        'Position',[.01 .15 .10 .7],'Callback',@(~,~)changePage(-1));
    uicontrol(ctrl,'Style','pushbutton','String','Next >','Units','normalized',...
        'Position',[.12 .15 .10 .7],'Callback',@(~,~)changePage(+1));
    pageLabelH = uicontrol(ctrl,'Style','text','Tag','pageLabel','Units','normalized',...
        'Position',[.23 .15 .38 .7],'BackgroundColor',[.97 .97 .97],...
        'FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    uicontrol(ctrl,'Style','pushbutton','String','All Good','Units','normalized',...
        'Position',[.62 .15 .12 .7],'Callback',@(~,~)setAllGood());
    uicontrol(ctrl,'Style','pushbutton','String','Done (return)','Units','normalized',...
        'Position',[.76 .15 .22 .7],'FontWeight','bold','Callback',@(~,~)onDone());

    %— Draw the first page
    drawPage(currentPage,true);
    uiwait(fig);
    badList = find(maskOut==2);
    close(fig);

  %—— drawPage: renders page p —————————————————————

    function drawPage(p,doBefore)
        cl = pages(p).cluster;
        pageLabelH.String = sprintf('Page %d/%d — Cluster %d/%d',p,P,cl,S);

        delete(findall(content,'Type','matlab.ui.container.TileLayout'));
        tl = tiledlayout(content,nRows,nCols, 'Padding','compact','TileSpacing','compact');
        currentTL = tl;
        sgtitle(tl,titles{cl},'FontSize',sgtitleFontSize,'FontWeight','bold');

        allCh = groups{cl}(:);
        chs   = allCh(pages(p).i0 : min(pages(p).i1,numel(allCh)));

        for idx=1:numel(chs)
            ax = nexttile(tl,idx);
            hold(ax,'on');
            if ~isempty(refTrace), plot(ax,t,refTrace,'Color',colRef,'LineWidth',1,'HitTest','off'); end
            ch = chs(idx); st = maskOut(ch);
            switch st
              case 0, c0=colGood; tc=tcolGood;
              case 1, c0=colSusp; tc=tcolSusp;
              case 2, c0=colBad;  tc=tcolBad;
            end
            hd = plot(ax,t,X(ch,:),'Color',rgba(c0,alpha),'LineWidth',1,'Tag','dataLine');
            hd.UserData = ch;
            hd.ButtonDownFcn = @(~,~)toggleState(ch,ax);
            ax.ButtonDownFcn  = @(~,~)toggleState(ch,ax);
            xlim(ax,xL);
            applyStyle(ax,ch,st);
            hold(ax,'off');
        end

        drawnow;
        axesArr = flip(tl.Children);
        for k=1:numel(axesArr)
            ax = axesArr(k);
            ax.XTickLabelMode = 'auto'; ax.YTickLabelMode = 'auto'; ax.Box = 'on';
        end

        if saveFigs && doBefore && ~savedBefore(p)
            snap('before',p);
            savedBefore(p)=true;
        end
    end

  %—— toggleState: toggles good<->bad —————————————————

    function toggleState(ch,ax)
        if maskOut(ch)==0, maskOut(ch)=2; else, maskOut(ch)=0; end
        applyStyle(ax,ch,maskOut(ch));
    end

  %—— onKey: navigation & hotkeys ———————————————————

    function onKey(~,ev)
        switch lower(ev.Key)
          case {'rightarrow','n'}, changePage(+1);
          case {'leftarrow','p'},  changePage(-1);
          case {'space','return'}
            ax=gca; hd=findobj(ax,'Tag','dataLine'); if ~isempty(hd), toggleState(hd.UserData,ax); end
          case 'g', setState(gca,0);
          case 's', setState(gca,1);
          case 'b', setState(gca,2);
        end
    end

    function setState(ax,val)
        hd=findobj(ax,'Tag','dataLine'); if isempty(hd), return; end
        ch=hd.UserData; maskOut(ch)=val; applyStyle(ax,ch,val);
    end

  %—— changePage / setAllGood / onDone ——————————————————

    function changePage(delta)
        currentPage = max(1,min(P,currentPage+delta));
        drawPage(currentPage,true);
    end

    function setAllGood
        % Only set channels on the CURRENT page to good
        cl  = pages(currentPage).cluster;
        allCh = groups{cl}(:);
        i0   = pages(currentPage).i0;
        i1   = pages(currentPage).i1;
        chs  = allCh(i0:min(i1,numel(allCh)));
        maskOut(chs) = 0;
        drawPage(currentPage,false);
    end

    function onDone
        if saveFigs
            orig=currentPage;
            for pp=1:P, drawPage(pp,false); snap('after',pp); end
            drawPage(orig,false);
        end
        uiresume(fig);
    end

  %—— applyStyle: title & badge glyph —————————————————

    function applyStyle(ax,ch,state)
        hd=findobj(ax,'Tag','dataLine'); if isempty(hd), return; end
        switch state
          case 0, col=colGood;  ttl='good';    tc=tcolGood;
          case 1, col=colSusp;  ttl='suspicious';tc=tcolSusp;
          case 2, col=colBad;   ttl='bad';     tc=tcolBad;
        end
        hd.Color = rgba(col,alpha);
        eogTag = '';
        if ~isempty(INFO.EOG) && ismember(ch, INFO.EOG)
            eogTag = ' - EOG';
        end
        title(ax,sprintf('Ch %d%s (%s)',ch,eogTag,ttl),'Color',tc,'FontWeight','bold','FontSize',titleFontSize);
        delete(findobj(ax,'Tag','stateBadge'));
        glyph='✓'; if state==1, glyph='?'; elseif state==2, glyph='✗'; end
        text(ax,0.02,0.90,glyph,'Units','normalized','FontSize',12,'FontWeight','bold','Color',col,'Tag','stateBadge','HitTest','off','VerticalAlignment','top');
    end

  %—— snap: exports tiledlayout to PNG —————————————————

    function snap(kind,pageNum)
        fname = sprintf('%s_03c_BadChs_p%02d_%s.png',INFO.subject,pageNum,kind);
        fullpath = fullfile(INFO.figure_folder,fname);
        try, exportgraphics(currentTL,fullpath,'Resolution',200);
        catch, print(currentTL,fullpath,'-dpng','-r200'); end
    end
end