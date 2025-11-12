function [maskOut,badList] = reviewBadChsUI(X,t,maskIn,groups,titles,INFO,gridCols,ref,alpha,saveFigs)
% reviewBadChsUI GROUPED
% Groups of channels with section headings; scrollable UI; per-axes zoom.
% Tri-state: 0=good, 1=suspicious, 2=bad.
%
% Inputs
%   X        : [nCh x nT]
%   t        : [1 x nT] (default 1:nT)
%   maskIn   : [nCh x 1] values in {0,1,2}
%   groups   : {1 x S} cell; each cell = vector of channel indices for that section
%   titles   : {1 x S} cellstr; headings per section
%   gridCols : scalar (# of columns per section grid) (default 2)
%   ref      : [] | scalar channel index | 1 x nT reference vector
%
% Outputs
%   maskOut  : updated tri-state mask
%   badList  : indices with state==2

    if nargin<2 || isempty(t), t=1:size(X,2); end
    if nargin<5 || isempty(titles), titles = repmat({''}, 1, numel(groups)); end
    if nargin<7 || isempty(gridCols), gridCols=2; end
    if nargin<8, ref=[]; end
    if nargin<9, alpha=.5; end 
    if nargin<10, saveFigs = 0; end


    nCh=size(X,1);
    maskOut=double(maskIn(:));
    assert(numel(maskOut)==nCh && all(ismember(maskOut,[0 1 2])));
    assert(iscell(groups) && iscell(titles) && numel(groups)==numel(titles));

    % Reference
    refTrace=[];
    if ~isempty(ref) && ~(isscalar(ref) && ref==0)
        if isscalar(ref), refTrace=X(ref,:);
        else, assert(isrow(ref) && numel(ref)==numel(t)); refTrace=ref;
        end
    end

    % Colors + alpha (UIAxes supports RGBA)
    colRef=[0.35 0.35 0.35]; aRef=1.00;
    colGood=[0.00 0.45 0.00]; aGood=alpha;
    colSusp=[0.80 0.62 0.10]; aSusp=alpha;
    colBad =[0.70 0.25 0.25]; aBad =alpha;

    gridColor=[0.88 0.88 0.88]; boxLW=0.6; fszTitle=11; fszTicks=10;
    lineWData=1.0; lineWRef=1.0;

    % Tight x-limits
    tMin=t(1); tMax=t(end); tr=max(1e-9,tMax-tMin); pad=0.01; xL=[tMin-pad*tr, tMax+pad*tr];

    % ------- Layout constants -------
    sectTitleH = 28;  % pixels for section heading label
    tileW_des  = 520; % desired tile width (will adapt)
    tileH      = 220; % per-plot height
    mL=16; mR=12; mT=12; mB=14; hG=10; vG=12;
    ctrlH=48;

    % Precompute section sizes
    S = numel(groups);
    sectRows = zeros(1,S);
    sectTiles = cell(1,S);
    for s=1:S
        g = groups{s}(:);
        assert(all(g>=1 & g<=nCh), 'Group %d has invalid channel indices.', s);
        sectTiles{s}=g;
        sectRows(s)=ceil(numel(g)/gridCols);
    end

    % Figure width from columns; height from total rows
    totalRows = sum(sectRows);
    desiredW = mL + gridCols*tileW_des + (gridCols-1)*hG + mR;
    figW = min(1400, max(1100, desiredW)); % wider default
    totalH_content = 0;
    for s=1:S
        nRows = sectRows(s);
        totalH_content = totalH_content + sectTitleH + (nRows*tileH + (nRows-1)*vG) + vG; % add extra vG between sections
    end
    totalH_content = totalH_content + mT + mB;

    maxVisibleH = 900;
    figH = min(maxVisibleH, max(560, ctrlH + totalH_content));

    % ------- Figure & panels -------
    fig=uifigure('Name','QC (Grouped • Scroll • Zoom)','Position',[100 100 figW figH],'Color','w');
    ctrl=uipanel(fig,'Position',[0 figH-ctrlH figW ctrlH],'BackgroundColor',[0.97 0.97 0.97],'BorderType','none');
    scrollH = figH-ctrlH;
    scrollPanel=uipanel(fig,'Position',[0 0 figW scrollH],'Scrollable','on','BackgroundColor','w','BorderType','none');

    % Compute actual tile width to fit columns
    availW = figW - mL - mR - (gridCols-1)*hG;
    tileW  = floor(availW / gridCols);

    % Canvas height
    totalH = totalH_content;
    canvasW = max(figW, mL + gridCols*tileW + (gridCols-1)*hG + mR);
    anchorY = max(0, scrollH - totalH);
    canvas=uipanel(scrollPanel,'Position',[0 anchorY canvasW totalH],'BackgroundColor','w','BorderType','none');

    % Controls
    uibutton(ctrl, 'Text','Done (return)', 'FontWeight','bold', ...
        'Position',[round(figW*0.38) 7 240 34], 'ButtonPushedFcn', @onDone);
    % uibutton(ctrl,'Text','Done (return)','FontWeight','bold',...
    %     'Position',[round(figW*0.38) 7 240 34], ....
    %     'ButtonPushedFcn',@(~,~) uiresume(fig));

    uibutton(ctrl,'Text','All Good','Position',[figW-150-12 7 150 34],...
        'ButtonPushedFcn',@(~,~) setAllGood());


    % ------- Build sections -------
    yCursor = totalH - mT;  % start from top and move downward
    axPerSection = cell(1,S);  % keep handles per section for x-tick labeling

    for s=1:S
        g = sectTiles{s};
        nS = numel(g);
        rows = sectRows(s); cols = gridCols;

        % Section heading
        yCursor = yCursor - sectTitleH;
        uilabel(canvas,'Text',titles{s}, ...
            'Position',[0 yCursor canvasW 30], ...   % span full width
            'FontWeight','bold','FontSize',16, ...  % larger font
            'HorizontalAlignment','center', ...
            'BackgroundColor','w');

        % Section grid top-left anchor
        yCursor = yCursor - vG; % small gap under title
        sectionTop = yCursor;

        axH = gobjects(nS,1);
        for i=1:nS
            ch = g(i);
            r = ceil(i/cols);
            c = i - (r-1)*cols;

            left   = mL + (c-1)*(tileW+hG);
            bottom = sectionTop - (r*tileH + (r-1)*vG);

            ax=uiaxes('Parent',canvas,'Units','pixels','Position',[left bottom tileW tileH],...
                      'BackgroundColor','w','HitTest','on');
            axH(i)=ax;
            ax.XGrid='on'; ax.YGrid='on'; ax.GridColor=gridColor; ax.LineWidth=boxLW;
            ax.FontSize=fszTicks; ax.Toolbar.Visible='on';

            hold(ax,'on');
            if ~isempty(refTrace)
                rl=plot(ax,t,refTrace,'LineWidth',lineWRef);
                rl.Tag='refLine'; rl.Color=[colRef aRef]; rl.HitTest='off'; rl.PickableParts='none';
            end
            dl=plot(ax,t,X(ch,:),'LineWidth',lineWData);
            dl.Tag='dataLine'; dl.HitTest='off'; dl.PickableParts='none';
            hold(ax,'off');

            ax.XLim=xL;
            ax.UserData.section = s;
            ax.UserData.localIdx = i;
            ax.UserData.channel = ch;
            ax.ButtonDownFcn=@(~,~) onToggleGoodBad(ax);

            applyStyle(ax,ch,maskOut(ch));
            ax.Title.FontSize=fszTitle;
        end
        axPerSection{s} = axH;

        % Move cursor below this section’s grid
        yCursor = bottom - vG; %#ok<NASGU> % (bottom defined in loop)
        % recompute robustly:
        yCursor = sectionTop - (rows*tileH + (rows-1)*vG) - vG;
    end

    % Force start-at-top behavior
    drawnow;
    try
        scroll(scrollPanel,'top'); 
    catch
        canvas.Position(2)=canvas.Position(2)+1; drawnow; canvas.Position(2)=anchorY; drawnow;
    end

    if saveFigs
        saveFullCanvas('03c_uiBadChs_before');
    end


    % X-tick labels: only on TRUE bottom row per section (ensures at least one row has labels)
    for s=1:S
        axH = axPerSection{s};
        nS  = numel(axH);
        rows = sectRows(s); cols = gridCols;
        for i=1:nS
            r = ceil(i/cols);
            if r < rows
                axH(i).XTickLabel = [];
            else
                % bottom row of this section keeps X labels
                % (you can thin ticks here if needed)
            end
        end
    end

    fig.KeyPressFcn=@onKey;
    uiwait(fig); try, close(fig); catch, end
    badList=find(maskOut==2);

    % ------- nested helpers -------
    function setAllGood()
        % mark all channels appearing in groups as good
        for ss=1:S
            g = sectTiles{ss};
            maskOut(g)=0;
            for ii=1:numel(g)
                ax = axPerSection{ss}(ii);
                applyStyle(ax, g(ii), 0);
            end
        end
    end

    function onToggleGoodBad(ax)
        if ~isfield(ax.UserData,'channel'), return; end
        ch = ax.UserData.channel;
        switch maskOut(ch)
            case 0, maskOut(ch)=2;
            case 2, maskOut(ch)=0;
            otherwise, maskOut(ch)=2;
        end
        applyStyle(ax,ch,maskOut(ch));
    end

    function onKey(~,evt)
        ax=gca;
        if ~isa(ax,'matlab.ui.control.UIAxes') || ~isfield(ax.UserData,'channel'), return; end
        ch = ax.UserData.channel;
        switch lower(evt.Key)
            case {'space','return'}
                onToggleGoodBad(ax);
            case 'g'
                maskOut(ch)=0; applyStyle(ax,ch,0);
            case 's'
                maskOut(ch)=1; applyStyle(ax,ch,1);
            case 'b'
                maskOut(ch)=2; applyStyle(ax,ch,2);
        end
    end

    function applyStyle(ax,ch,state)
        dl = findobj(ax,'Type','line','-and','Tag','dataLine');
        if isempty(dl), return; end
        switch state
            case 0, dl.Color=[colGood aGood]; glyph='✓'; bcol=colGood;  ttl='good';       tcol=[0.0 0.30 0.0];
            case 1, dl.Color=[colSusp aSusp]; glyph='?'; bcol=colSusp;  ttl='suspicious'; tcol=[0.55 0.38 0.05];
            case 2, dl.Color=[colBad  aBad ]; glyph='✗'; bcol=colBad;   ttl='bad';        tcol=[0.50 0.10 0.10];
        end
        old=findall(ax,'Type','text','Tag','stateBadge'); if ~isempty(old), delete(old); end
        text(ax,0.02,0.93,glyph,'Tag','stateBadge','Units','normalized','FontSize',12,...
             'FontWeight','bold','Color',bcol,'VerticalAlignment','top');
        title(ax,sprintf('Ch %d (%s)',ch,ttl),'FontWeight','bold','Color',tcol);
    end

    function fp = tsFile(base)
        fp = fullfile(INFO.figure_folder, sprintf('%s_%s', INFO.subject, base));
    end


    function onDone(~,~)
        % Take an "after" snapshot before returning
        if saveFigs
            saveFullCanvas('03d_uiBadChs_after');
        end
        
        uiresume(fig);   % lets the main function finish and return maskOut, badList
    end

    function saveFullCanvas(kind)
        % Save the ENTIRE scrolled content (not just the visible viewport)
        base   = sprintf('%s', kind);
        target = tsFile(base);
    
        % Remember original geometry/state
        origFigPos   = fig.Position;
        origSPPos    = scrollPanel.Position;
        origSPScroll = scrollPanel.Scrollable;
        origCanvasPos= canvas.Position;
    
        try
            drawnow;
    
            % Turn off scrolling and size the viewport to exactly the full content
            scrollPanel.Scrollable = 'off';
    
            % Make the scroll panel as tall as the full canvas content
            scrollPanel.Position(4) = origCanvasPos(4);   % height = total content height
            scrollPanel.Position(2) = 0;                  % bottom align
            canvas.Position(2)      = 0;                  % anchor canvas to bottom-left
    
            % Option 1: export just the canvas as a tall PNG/PDF
            % (Works even if figure would be “larger than screen”)
            warning('off','all')
            exportgraphics(canvas, [target '.png'], 'Resolution', 200);
            warning('on','all')
            % exportgraphics(canvas, [target '.pdf'], 'ContentType','vector');
    
        catch ME
            warning('Full-canvas export failed: %s');
            disp(ME.message)
        end
    
        % Restore geometry/state
        canvas.Position        = origCanvasPos;
        scrollPanel.Position   = origSPPos;
        scrollPanel.Scrollable = origSPScroll;
        fig.Position           = origFigPos;
        drawnow;
    end




end
