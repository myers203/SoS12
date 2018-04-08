classdef Culling < handle
    %CULLING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        zones; % List of geometric zones of interest
    end
    
    properties (Access = private)
        numZones = 0;
    end
    
    methods
        
        function obj = Culling()
            obj.zones = obj.makeZone;
        end
        
        function addZones(obj, zoneType, varargin)
            assert(isa(zoneType, 'char'), 'Zone type specifier must be a string!');
            switch lower(zoneType)
                case {'rect', 'rectangle'}
                    obj.addRectangle(varargin{1}, varargin{2});
                case {'circ', 'circle'}
                    obj.addCircle(varargin{1}, varargin{2});
                otherwise
                    error('''%s'' is not a supported zone type!');
            end
        end
        
        function addRectangle(obj, centers, dims)
            % Adds rectangular zones
            % centers: Centerpoint of the rectangle
            % dims: Width, height of the rectangle
            
            assert(size(centers, 1) == size(dims, 1), 'Center and dimensions must have the same number of rows!');
            
            inBoundsFcn = @(x, center, dim) abs(x - center) < (dim / 2);
            plotFcn = @(center, dim, color) rectangle('Position', ...
                [center(1) - dim(1) / 2, center(2) - dim(2) / 2, ...
                dim(1), dim(2)], ...
                'LineStyle', '--', ...
                'EdgeColor', color);
            
            for i = 1:size(centers, 1)
                newZone = obj.makeZone();
                newZone.cullTest = @(x, y) inBoundsFcn(x, centers(i, 1), dims(i, 1)) && ...
                    inBoundsFcn(y, centers(i, 2), dims(i, 2));
                newZone.plot = @(color) plotFcn(centers(i, :), dims(i, :), color);
                obj.addZone(newZone);
            end
        end
        
        function addCircle(obj, centers, rads)
            % Adds a circular zone
            % centers: Centerpoint of the circle
            % rads: Radii of the circles
            
            assert(size(centers, 1) == length(rads), 'Number of centers must equal number of radii!');
            
            inBoundsFcn = @(x, y, center, rad) sqrt((center(1) - x)^2 + (center(2) - y)^2) < rad;
            
            numVerts = 20;
            alphas = linspace(0, 2 * pi, numVerts);
            plotFcn = @(center, rad, color) plot(cos(alphas) * rad + center(1), ...
                sin(alphas) * rad + center(2), ...
                'LineStyle', '--', ...
                'Color', color);
            
            for i = 1:size(centers, 1)
                newZone = obj.makeZone();
                newZone.cullTest = @(x, y) inBoundsFcn(x, y, centers(i, :), rads(i));
                newZone.plot = @(color) plotFcn(centers(i, :), rads(i), color);
                obj.addZone(newZone);
            end
        end
        
        function isActive = getActiveZones(obj, x, y)
            isActive = zeros(1, obj.numZones);
            for i = 1:obj.numZones
                 isActive(i) = obj.zones(i).cullTest(x, y);
            end
        end
        
        % Visual debuging tools
        
        function ph = plotZones(obj, fh)
            if ~exist('fh', 'var')
                fh = figure();
            end
            figure(fh);
            hold on;
            
            ph = cell(1, obj.numZones);
            
            for i = 1:obj.numZones
                ph{i} = obj.zones(i).plot('red');
            end
        end
        
        function interactivePlotZones(obj, fh)
            if ~exist('fh', 'var')
                fh = figure();
            end
            figure(fh);
            hold on;
            
            plotHandles = obj.plotZones(fh);
            
            fh.WindowButtonMotionFcn = @(varargin) obj.hoverOverCallback(plotHandles, varargin{:});
        end
        
    end
    
    methods (Access = private)
        function newZone = makeZone(obj)
            newZone = struct( ...
                'cullTest', [], ...
                'plot', []);
        end
        
        function addZone(obj, newZone)
            obj.numZones = obj.numZones + 1;
            obj.zones(obj.numZones) = newZone;
        end
        
        % Assists with visual debugging
        function hoverOverCallback(obj, plotHandles, varargin)
            mousePoint = get(gca, 'CurrentPoint');
            
            isActive = obj.getActiveZones(mousePoint(1, 1), mousePoint(1, 2));
            
            for i = 1:obj.numZones
                if isActive(i)
                    color = 'green';
                else
                    color = 'red';
                end
                
                switch class(plotHandles{i})
                    case 'matlab.graphics.primitive.Rectangle'
                        plotHandles{i}.EdgeColor = color;
                    case 'matlab.graphics.chart.primitive.Line'
                        plotHandles{i}.Color = color;
                    otherwise
                        warning('Color setting for plot class ''%s'' is not supported!', class(plotHandles{i}));
                end
            end
        end
    end
    
end

