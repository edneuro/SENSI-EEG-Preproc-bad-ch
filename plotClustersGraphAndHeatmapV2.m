function plotClustersGraphAndHeatmapV2(D, eps, idx, clusterNames)
%PLOTCLUSTERSGRAPHANDHEATMAPV2
%   plotClustersGraphAndHeatmap_simple(D, eps)
%   plotClustersGraphAndHeatmap_simple(D, eps, idx)
%   plotClustersGraphAndHeatmap_simple(D, eps, idx, clusterNames)
%
% Inputs
%   D            : [n x n] symmetric distance matrix (finite, diag=0)
%   eps          : threshold for linking channels (D <= eps)
%   idx          : optional [n x 1] cluster IDs (1..k). If empty, computed via conncomp.
%   clusterNames : optional cell array of cluster names, length = k.
%
% Panels
%   Left  : force-directed graph. Each node is labeled with its channel number (1..n)
%           rendered directly at the node using a white halo + black text for legibility.
%           Cluster tag (e.g., 'C1: name') is placed just OUTSIDE the hull, not over nodes.
%   Right : reordered heatmap with numeric axis labels, cluster borders, colorbar.

    % ---- checks / prep ----
    n = size(D,1);
    if size(D,2) ~= n, error('D must be square'); end
    if any(~isfinite(D(:))), error('D contains non-finite values'); end
    D = (D + D.')/2; D(1:n+1:end)=0;

    if nargin < 3 || isempty(idx)
        A = (D <= eps);
        A(1:n+1:end) = false; A = A & A.';
        G = graph(A);
        idx = conncomp(G).';
    else
        A = (D <= eps);
        A(1:n+1:end) = false; A = A & A.';
        G = graph(A);
    end
    if nargin < 4, clusterNames = {}; end
    k = max(idx);

    % ---- palette (high contrast) ----
    base = [0.121,0.466,0.705;
            0.200,0.627,0.173;
            0.890,0.102,0.110;
            0.580,0.404,0.741;
            0.549,0.337,0.294;
            0.737,0.741,0.133;
            0.090,0.745,0.811;
            0.998,0.506,0.055];
    cmap = repmat(base, ceil(k/size(base,1)), 1);
    cmap = cmap(1:k,:);

    figure('Name','Clusters: Graph + Heatmap','Color','w','Position',[100 100 1200 540]);

    % ================== Left: Force-directed graph ==================
    subplot(1,2,1);
    h = plot(G, 'Layout','force', 'Iterations', 300, ...
             'NodeLabel', {}, 'MarkerSize', 3, ...
             'NodeColor', [0.4 0.4 0.4], 'EdgeColor', [0.5 0.5 0.5], 'LineWidth', 1.0);
    hold on;

    % color markers by cluster (labels will be black)
    set(h, 'NodeCData', idx);
    colormap(gca, cmap);

    X = h.XData(:); Y = h.YData(:);

    % --- draw numeric labels at nodes, with a simple halo (no boxes) ---
    % halo offsets (pixels) scaled to axis units via a small fraction of data span
    dx = 0.003 * range(X); if dx==0, dx = 1e-6; end
    dy = 0.003 * range(Y); if dy==0, dy = 1e-6; end
    offs = [ -dx 0; dx 0; 0 -dy; 0 dy; -dx -dy; -dx dy; dx -dy; dx dy ];

    for i = 1:n
        % halo: white copies around
        for o = 1:size(offs,1)
            text(X(i)+offs(o,1), Y(i)+offs(o,2), sprintf('%d', i), ...
                'FontSize', 9, 'FontWeight', 'bold', ...
                'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                'Color', [1 1 1], 'Clipping','on');
        end
        % main label: black on top
        text(X(i), Y(i), sprintf('%d', i), ...
            'FontSize', 9, 'FontWeight', 'bold', ...
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'Color', [0 0 0], 'Clipping','on');
    end

    % --- draw faint cluster hulls and put cluster tags OUTSIDE ---
    for c = 1:k
        sel = (idx == c);
        if nnz(sel) >= 3
            Xi = X(sel); Yi = Y(sel);
            K = convhull(Xi, Yi);
            plot(Xi(K), Yi(K), '-', 'Color', cmap(c,:), 'LineWidth', 1.2);
            % place tag above the topmost hull vertex (outside, small offset)
            [~, topIdx] = max(Yi(K));
            vx = Xi(K(topIdx)); vy = Yi(K(topIdx));
            offY = 0.04 * range(Y);
            if isempty(clusterNames)
                labelStr = sprintf('C%d', c);
            else
                labelStr = sprintf('C%d: %s', c, clusterNames{c});
            end
            % halo for tag
            for o = 1:size(offs,1)
                text(vx, vy+offY, labelStr, ...
                    'FontSize', 12, 'FontWeight','bold', ...
                    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                    'Color', [1 1 1], 'Clipping','on');
            end
            text(vx, vy+offY, labelStr, ...
                'FontSize', 12, 'FontWeight','bold', ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'Color', cmap(c,:), 'Clipping','on');
        else
            % small clusters: just place tag slightly above centroid
            Xi = X(sel); Yi = Y(sel);
            cx = mean(Xi); cy = mean(Yi);
            offY = 0.04 * range(Y);
            if isempty(clusterNames), labelStr = sprintf('C%d', c);
            else, labelStr = sprintf('C%d: %s', c, clusterNames{c}); end
            for o = 1:size(offs,1)
                text(cx, cy+offY, labelStr, ...
                    'FontSize', 12, 'FontWeight','bold', ...
                    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                    'Color', [1 1 1], 'Clipping','on');
            end
            text(cx, cy+offY, labelStr, ...
                'FontSize', 12, 'FontWeight','bold', ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'Color', cmap(c,:), 'Clipping','on');
        end
    end

    title(sprintf('Force-directed graph (\\epsilon = %.3g) — zoom if crowded', eps));
    axis equal off;
    hold off;

    % ================== Right: Reordered heatmap ==================
    subplot(1,2,2);
    order = [];
    borders = 0;
    for c = 1:k
        idx_c = find(idx==c);
        order = [order; idx_c(:)]; %#ok<AGROW>
        borders(end+1) = numel(order); %#ok<AGROW>
    end
    if isempty(order), order = (1:n)'; end

    Dp = D(order, order);
    imagesc(Dp);
    axis image;
    colormap(parula); caxis([0 1]);
    cb = colorbar; cb.Ticks = 0:0.25:1; cb.Label.String='Distance';

    xticks(1:n); yticks(1:n);
    xticklabels(arrayfun(@num2str, order, 'uni',0));
    yticklabels(arrayfun(@num2str, order, 'uni',0));
    xtickangle(90);

    title('Distance matrix (reordered by cluster)');
    hold on;
    for b = borders(1:end-1)
        xline(b+0.5, 'k-', 'LineWidth', 0.8);
        yline(b+0.5, 'k-', 'LineWidth', 0.8);
    end
    hold off;
end
