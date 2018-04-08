
function clearPlotter(fh, spacingFactor)
if ~exist('spacingFactor', 'var')
    spacingFactor = 1;
end

% Get all axes
ax = {};
for i = 1:numel(fh.Children)
    if isa(fh.Children(i), 'matlab.graphics.axis.Axes')
        ax{numel(ax) + 1} = fh.Children(i);
    end
end

if numel(ax) == 0
    warning('No axis in the provided figure!');
    return;
end

for i = 1:numel(ax)
    % Do work on each graphics axis
    
    % Set the units to pixels
    set(ax{i}, 'Units', 'pixels');
    
    % Get all lines on the graph
    lines = cell(1, numel(ax{i}.Children));
    for j = 1:numel(ax{i}.Children)
        assert(isa(ax{i}.Children(j), 'matlab.graphics.chart.primitive.Line'), 'Graphic object not a line!');
        lines{j} = soda.util.plot.clearPlot.Line(ax{i}.Children(j));
        lines{j}.frameSize = ax{i}.Position(3:4);
        lines{j}.frameXBounds = xlim(ax{i});
        lines{j}.frameYBounds = ylim(ax{i});
        lines{j}.setSpacingFactor(spacingFactor);
    end
    
    % Get all points that need to be sampled
    xSplits = [];
    for j = 1:numel(lines)
        xSplits = [xSplits, lines{j}.graphicLine.XData];
    end
    xSplits = sort(unique(xSplits));
    xSamples = xSplits(1:end - 1) + diff(xSplits) / 2;
    
    % Sample each point for intersecting lines
    matchedLines = []; %i x j x k matrix
    % i: Sample index
    % j: Group number
    % k: List of intersecting line indecies
    for j = 1:numel(xSamples)
        groupNum = 1;
        eqns = cell(1, numel(lines));
        for k = 1:numel(lines)
            eqns{k} = lines{k}.getEquationAtX(xSamples(j));
        end
        
        testIndex = 1;
        isMatched = zeros(1, numel(eqns));
        while testIndex < numel(eqns)
            numMatched = 0;
            for m = testIndex + 1:numel(eqns)
                if isMatched(m) == 0 && ...
                        ~isempty(eqns{testIndex}) && ...
                        ~isempty(eqns{m}) && ...
                        all(eqns{testIndex} == eqns{m});
                    if numMatched == 0
                        matchedLines(j, groupNum, 1) = testIndex; %#ok<AGROW>
                        numMatched = numMatched + 1;
                        isMatched(testIndex) = 1;
                    end
                    numMatched = numMatched + 1;
                    matchedLines(j, groupNum, numMatched) = m; %#ok<AGROW>
                    isMatched(m) = 1;
                end
            end
            groupNum = groupNum + 1;
            testIndex = max(find(~isMatched, 1, 'first'), testIndex + 1);
        end
    end
    
    % Found all intersecting things, now go through cases where
    % things matched and tell the lines to sort themselves out
    
    for j = 1:size(matchedLines, 1)
        k = 1;
        while  k <= size(matchedLines, 2) && (matchedLines(j, k, 1) ~= 0)
            % Continue as long as there is a group number
            numMatchedLinesHere = sum(matchedLines(j, k, :) ~= 0);
            for m = 1:numMatchedLinesHere
                lines{matchedLines(j, k, m)}.notifyMove(xSamples(j), numMatchedLinesHere, m);
            end
            k = k + 1;
        end
    end
    
    xbounds = xlim(ax{i});
    ybounds = ylim(ax{i});
    warnFlag = 0;
    % Now actually tell all the lines to move themselves
    for j = 1:numel(lines)
        [xtemp, ytemp, tempFlag] = lines{j}.executeMove();
        xbounds(1) = min(xbounds(1), xtemp(1));
        xbounds(2) = max(xbounds(2), xtemp(2));
        ybounds(1) = min(ybounds(1), ytemp(1));
        ybounds(2) = max(ybounds(2), ytemp(2));
        
        warnFlag = warnFlag + tempFlag;
    end
    
    if (warnFlag > 0)
        if (warnFlag == 1)
            warning('1 line shifted greater than the tolerance!')
        else
            warning('%d lines shifted greater than the tolerance!', warnFlag);
        end
    end
    
    % Shift the bounds to make everything visible
    xlim(ax{i}, xbounds);
    ylim(ax{i}, ybounds);
    
end
end