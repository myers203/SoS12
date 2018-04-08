classdef Scatter < publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement
    %SCATTER Simple scatter plot
    
    properties (SetAccess = private)
        data = struct('x', [], 'y', []);
        % Marker properties
        marker;
        markerSize;
        
        % Line properties
        lineWidth;
        lineStyle;
        
        % Plot settings
        fitToBounds = 0;
        scaleToBounds = 0;
        cropToBounds = 0;
    end
    
    properties (Access = private)
        % Marker default properties
        default_marker = 'o';
        default_markerSize = 4;
        
        % Line default properties
        default_lineWidth = 1;
        default_lineStyle = 'none';
    end
    
    methods
        
        function obj = Scatter(x, y, varargin)
            obj = obj@publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement();
            
            % Get data
            assert(numel(x) == numel(y), 'X and Y datasets must have the same number of elements!');
            obj.data.x = x;
            obj.data.y = y;
            
            % Get optional inputs
            np = inputParser;
            np.PartialMatching = 0;
            np.KeepUnmatched = 1;
            % Marker properties
            np.addParameter('marker', obj.default_marker, @ischar);
            np.addParameter('markerSize', obj.default_markerSize, @isnumeric);
            
            % Line properties
            np.addParameter('lineWidth', obj.default_lineWidth, @isnumeric);
            np.addParameter('lineStyle', obj.default_lineStyle, @ischar);
            
            % Parse
            np.parse(varargin{:});
            
            % Set
            % Marker
            obj.setMarker(np.Results.marker);
            obj.setMarkerSize(np.Results.markerSize);
            
            % Line
            obj.setLineWidth(np.Results.lineWidth);
            obj.setLineStyle(np.Results.lineStyle);
        end
        
        function handles = plot(obj, fig)
            % If either are cell arrays, they should be function handles.
            % Evaluate them first
            if isa(obj.data.x, 'cell')
                for i = 1:numel(obj.data.x)
                    newData.x(i) = obj.data.x{i}();
                end
                obj.data.x = newData.x;
            end
            
            if isa(obj.data.y, 'cell')
                for i = 1:numel(obj.data.y)
                    newData.y(i) = obj.data.y{i}();
                end
                obj.data.y = newData.y;
            end
            figure(fig);
            hold on;
            
            if obj.fitToBounds
                % Check the bounds to see if we have limits. If so, scale the x
                % and y data to fit in those bounds (seperately)
                if ~isempty(obj.bounds.xMin) && ~isempty(obj.bounds.xMax)
                    obj.data.x = obj.shiftData(obj.data.x, obj.bounds.xMin, obj.bounds.xMax);
                end
                
                if ~isempty(obj.bounds.yMin) && ~isempty(obj.bounds.yMax)
                    obj.data.y = obj.shiftData(obj.data.y, obj.bounds.yMin, obj.bounds.yMax);
                end
            elseif obj.cropToBounds
                % Check the bounds to see if we have limits. If so, limit
                % data to those limits
                if ~isempty(obj.bounds.xMin) && ~isempty(obj.bounds.xMax) && ...
                        ~isempty(obj.bounds.yMin) && ~isempty(obj.bounds.yMax)
                    obj.data = obj.limitData(obj.data, obj.bounds);
                end
            end
            handles{1} = plot(obj.data.x, obj.data.y, ...
                'Color', obj.getColor(), ...
                'LineWidth', obj.lineWidth, ...
                'LineStyle', obj.lineStyle, ...
                'Marker', obj.marker, ...
                'MarkerSize', obj.markerSize);
        end
        
        function data = getData(obj)
            % Returns the X and Y data starting at the specied indicies
            data = obj.data;
        end
        
        function data = getDataPoint(obj, field, index)
            data = obj.data.(field)(index);
        end
        
    end
    
    % Setters
    methods
        % Marker property setters
        function setMarker(obj, marker)
            obj.marker = marker;
        end
        
        function setMarkerSize(obj, markerSize)
            obj.markerSize = markerSize;
        end
        
        % Line property setters        
        function setLineWidth(obj, lineWidth)
            obj.lineWidth = lineWidth;
        end
        
        function setLineStyle(obj, lineStyle)
            obj.lineStyle = lineStyle;
        end
        
        function setFitToBounds(obj, bool)
            obj.fitToBounds = bool;
        end
        
        function setScaleToBounds(obj, bool)
            obj.scaleToBounds = bool;
        end
        
        function setBounds(obj, newBounds)
            
            if (obj.scaleToBounds)
                if ~isempty(obj.bounds.xMin) && ~isempty(obj.bounds.xMax) ...
                        && ~isempty(newBounds.xMin) && ~isempty(newBounds.xMax)
                    % Scale the X data
                    obj.data.x = obj.scaleFromTo(obj.data.x, obj.bounds.xMin, ...
                        obj.bounds.xMax, newBounds.xMin, newBounds.xMax);
                end
                
                if ~isempty(obj.bounds.yMin) && ~isempty(obj.bounds.yMax) ...
                        && ~isempty(newBounds.yMin) && ~isempty(newBounds.yMax)
                    % Scale the X data
                    obj.data.y = obj.scaleFromTo(obj.data.y, obj.bounds.yMin, ...
                        obj.bounds.yMax, newBounds.yMin, newBounds.yMax);
                end
            end
            
            setBounds@publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement(obj, newBounds);
        end
    end
    
    methods (Static)
        function data = limitData(data, bounds)
            % Limits the data to what falls withing the X and Y bounds
            [~, xbools] = publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement.getDataInBounds(data.x, bounds.xMin, bounds.xMax);
            [~, ybools] = publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement.getDataInBounds(data.y, bounds.yMin, bounds.yMax);
            bools = xbools & ybools;
            data.x = data.x(bools);
            data.y = data.y(bools);
        end
    end

    
end

