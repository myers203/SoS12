function hoverText(fh, cull, texts, debug)
%HOVERTEXT Makes text appear when hovering over bounds in a plot
% fh: Figure handle
% centers: Array, Centers of all the rectangles
% bounds: Array , Bounds of the rectangle for each center
% text: Cell array, Text to appear for each rectangle
% debug: (Optional), 1 = plot rectangles
% size(centers) == size(bounds) == size(text)
% 
% 
% Example:
% fh = figure();
% centers = [1 1; 2 5]; % x-y pairs
% bounds = [0.5 1; 1 2]; % x-y pairs
% text = {'rect1', 'rect2'};
figure(fh);
ax = gca;


txt = annotation('textbox', [0 0 0.01 0.01], 'String', '');
txt.Visible = 'off';
txt.VerticalAlignment = 'Bottom';
txt.BackgroundColor = [1 1 1];
txt.FaceAlpha = 0.8;
txt.Units = 'pixels';
txt.FitBoxToText = 'on';
if exist('debug', 'var') && debug == 1
    plotRectangles();
end
fh.WindowButtonMotionFcn = @hoverOverCallback;

    function hoverOverCallback(~, ~)
        mousePoint = get(ax, 'CurrentPoint');

        % Find the rectangle(s) that are being moused over
        activeRects = cull.getActiveZones(mousePoint(1, 1), mousePoint(1, 2));
        if any(activeRects)
            str = '';
            % Build the string to be displayed
            for j = 1:numel(activeRects)
                if activeRects(j)
                    if isempty(str)
                        str = texts{j};
                    else
                        str = [str, sprintf('\n%s', texts{j})]; %#ok<AGROW>
                    end
                end
            end
            txt.String = str;
            
            % Shift over the text box so the corner is under the pointer
            ax.Units = 'Pixels';
            PixperX = ax.Position(3) / diff(ax.XLim);
            PixperY = ax.Position(4) / diff(ax.YLim);
            mousePoint(1, 1:2) = mousePoint(1, 1:2) .* [PixperX, PixperY];
            
            txt.Position(1:2) = mousePoint(1, 1:2) + ax.Position(1:2);
            txt.Visible = 'on';
            
            ax.Units = 'normalized';
        else
            txt.Visible = 'off';
        end

    end

    function plotRectangles
        % Plot the bounding rectangles
        xl = xlim;
        yl = ylim;
        for i = 1:size(centers, 1)
            position = [];
            position(1) = centers(i, 1) - bounds(i, 1);
            position(2) = centers(i, 2) - bounds(i, 2);
            position(3) = 2 * bounds(i, 1);
            position(4) = 2 *bounds(i, 2);
            rect = rectangle('Position', position, 'LineStyle', '--', 'EdgeColor', 'green');
        end
    end

end

