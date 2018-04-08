classdef Line < handle
    %LINE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        graphicLine; % Matlab 'matlab.graphics.chart.primitive.Line' object
        moveOrders = [];
        order = [];
        frameSize;
        frameXBounds;
        frameYBounds;
        tolerance = 0.01; % Minimum value times the frame bounds that a warning will be sent
        pixelsPerLine = 2
    end
    
    properties (Access = private)
        defaultPixelsPerLine = 2;
    end
    
    methods
        function obj = Line(graphicLine)
            assert(all(diff(graphicLine.XData) >= 0), 'Line is not monotonically increasing!');
            obj.graphicLine = graphicLine;
            obj.moveOrders = zeros(1, numel(graphicLine.XData) - 1);
            obj.order = zeros(1, numel(graphicLine.XData) - 1);
        end
        
        function setSpacingFactor(obj, factor)
            obj.pixelsPerLine = obj.defaultPixelsPerLine * factor;
        end
        
        function eqn = getEquationAtX(obj, x)
            % Get the 'y=mx+b' form in [m b] form at the point X
            eqn = [];
            if all(x < obj.graphicLine.XData) || all(x > obj.graphicLine.XData)
                return;
            end
            
            lastInd = find(x < obj.graphicLine.XData, 1, 'first');
            firstInd = find(x > obj.graphicLine.XData, 1, 'last');
            assert(firstInd + 1 == lastInd); % Should already be a thing, but just to be sure
            
            m = (obj.graphicLine.YData(lastInd) - obj.graphicLine.YData(firstInd)) / ...
                (obj.graphicLine.XData(lastInd) - obj.graphicLine.XData(firstInd));
            b = obj.graphicLine.YData(firstInd) - m * obj.graphicLine.XData(firstInd);
            eqn = [m b];
        end
        
        function notifyMove(obj, x, num, order)
            index = find(x > obj.graphicLine.XData, 1, 'last');
            obj.moveOrders(index) = max(obj.moveOrders(index), num);
            obj.order(index) = max(obj.order(index), order);
        end
        
        function [xbounds, ybounds, warnFlag] = executeMove(obj)
            warnFlag = 0;
            newX = [];
            newY = [];
            for i = 1:numel(obj.moveOrders)
                if obj.moveOrders(i) == 0
                    newX = [newX obj.graphicLine.XData(i:i+1)];
                    newY = [newY obj.graphicLine.YData(i:i+1)];
                else
                    % Have to move the line
                    x = (obj.graphicLine.XData(i) + obj.graphicLine.XData(i + 1)) / 2;
                    eqn = obj.getEquationAtX(x);
                    angle = -atand(eqn(1));
                    
                    dxPixel = sind(angle) * obj.pixelsPerLine * obj.graphicLine.LineWidth;
                    dyPixel = cosd(angle) * obj.pixelsPerLine * obj.graphicLine.LineWidth;
                    
                    
                    
                    dx = dxPixel * diff(obj.frameXBounds / obj.frameSize(1)) * (obj.moveOrders(i) / 2 + 0.5 - obj.order(i));
                    dy = dyPixel * diff(obj.frameYBounds / obj.frameSize(2)) * (obj.moveOrders(i) / 2 + 0.5 - obj.order(i));
                    
                    if dx > obj.tolerance * diff(obj.frameXBounds)
                        warnFlag = 1;
                    end
                    
                    if dy > obj.tolerance * diff(obj.frameYBounds)
                        warnFlag = 1;
                    end
                    
                    newX = [newX obj.graphicLine.XData(i:i+1) + dx]; %#ok<AGROW>
                    newY = [newY obj.graphicLine.YData(i:i+1) + dy]; %#ok<AGROW>
                end
            end
            
            % Go through the new lines and clean up intersections
            trueX = newX(1);
            trueY = newY(1);
            
            % Second line
            b.m = (newY(2) - newY(1)) / (newX(2) - newX(1));
            b.b = (newY(2) - newX(2) * b.m);
            
            maxShift = sqrt((obj.tolerance * diff(obj.frameXBounds))^2 + (obj.tolerance * diff(obj.frameYBounds))^2);
            for i = 2:2:numel(newX) - 2;
                % Get equations for each line segment then find the
                % intersection
                
                % First line becomes the last second line
                a = b;
                
                b.m = (newY(i + 2) - newY(i + 1)) / (newX(i + 2) - newX(i + 1));
                b.b = (newY(i + 1) - newX(i + 1) * b.m);
                
                
                if (a.m == b.m)
                    % Same slope, infinite intersection points, so just
                    % chose the existing intersection
                    xInt = newX(i);
                    yInt = newY(i);
                else
                    % Not the same line, get the intersection
                    xInt = (b.b - a.b) / (a.m - b.m);
                    yInt = xInt * a.m + a.b;
                end
                
                % Get the original point of intersection
                origPointX = obj.graphicLine.XData(ceil((i + 1) / 2));
                origPointY = obj.graphicLine.YData(ceil((i + 1) / 2));
                
                % Find how much that intersection point shifted
                pointShift = ((xInt - origPointX)^2 + (yInt - origPointY)^2)^0.5;
                if (pointShift > maxShift)
                    % Point shift is out of tolerance. Rather than just
                    % leave it (because it could be a huge shift), use the
                    % average of the two existing points to create a new
                    % intersection
                    xInt = (newX(i) + newX(i + 1)) / 2;
                    yInt = (newY(i) + newY(i + 1)) / 2;
                end
                
                
                trueX = [trueX xInt]; %#ok<AGROW>
                trueY = [trueY yInt]; %#ok<AGROW>
            end
            
            trueX(end + 1) = newX(end);
            trueY(end + 1) = newY(end);
            
            xbounds = [min(trueX), max(trueX)];
            ybounds = [min(trueY), max(trueY)];
            
            % Finally set the new line
            obj.graphicLine.XData = trueX;
            obj.graphicLine.YData = trueY;
        end
        
    end 
    
end

