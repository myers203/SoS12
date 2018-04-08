classdef Rectangular < publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement
    %RECTANGULAR Makes a rectangle
    
    properties (SetAccess = private)
        data = struct('x', [], 'y', []);
        
        % Line properties
        lineColor;
        lineWidth;
        lineStyle;
        
        % Fill properties
        faceAlpha;
        
        fitToBounds = 0;
    end
    
    properties (Access = private)
        % Line default properties
        default_lineColor = [];
        default_lineWidth = 1;
        default_lineStyle = '-'
        default_faceAlpha = 1;
    end
    
    methods
        function obj = Rectangular(x, y, varargin)
            obj = obj@publicsim.util.visualization.smartPlotter.plotTypes.basic.PlotElement();
            
            % Get data
            assert((numel(x) == 2) && (numel(y) == 2), 'Rectangles must have X and Y vectors of size 2');
            obj.data.x = x;
            obj.data.y = y;
            
            % Get optional inputs
            np = inputParser;
            np.PartialMatching = 0;
            np.KeepUnmatched = 1;
            % Marker properties
            np.addParameter('lineColor', obj.default_lineColor, @isnumeric);
            np.addParameter('lineWidth', obj.default_lineWidth, @isnumeric);
            np.addParameter('lineStyle', obj.default_lineStyle, @ischar);
            
            % Parse
            np.parse(varargin{:});
            obj.setLineColor(np.Results.lineColor);
            obj.setLineWidth(np.Results.lineWidth);
            obj.setLineStyle(np.Results.lineStyle);
        end
        
        function handles = plot(obj, fig)
            figure(fig);
            hold on;
            % Construct the rectangle position
            if (obj.fitToBounds)
                if ~isempty(obj.bounds.xMin) && ~isempty(obj.bounds.xMax)
                    obj.data.x(1) = obj.bounds.xMin;
                    obj.data.x(2) = obj.bounds.xMax;
                end
                
                if ~isempty(obj.bounds.yMin) && ~isempty(obj.bounds.yMax)
                    obj.data.y(1) = obj.bounds.yMin;
                    obj.data.y(2) = obj.bounds.yMax;
                end
            else
                obj.data.x(1) = max(obj.bounds.xMin, obj.data.x(1));
                obj.data.x(2) = min(obj.bounds.xMax, obj.data.x(2));
                obj.data.y(1) = max(obj.bounds.yMin, obj.data.y(1));
                obj.data.y(2) = min(obj.bounds.yMax, obj.data.y(2));
            end
            pos = obj.getPosFromRectData(obj.data);
            handles{1} = rectangle('Position', pos, ...
                'FaceColor', obj.getColor(), ...
                'EdgeColor', obj.getColor(), ...
                'LineWidth', obj.lineWidth, ...
                'LineStyle', obj.lineStyle);
        end
    end
    
    methods
        % Setters and getters
        % Line property setters        
        function setLineColor(obj, color)
            obj.lineColor = color;
        end
        function setLineWidth(obj, lineWidth)
            obj.lineWidth = lineWidth;
        end
        
        function setLineStyle(obj, lineStyle)
            obj.lineStyle = lineStyle;
        end
        
        function setFitToBounds(obj, bool)
            obj.fitToBounds = bool;
        end
    end
    
    methods (Static)
        function pos = getPosFromRectData(data)
            pos(1) = data.x(1);
            pos(2) = data.y(1);
            pos(3) = data.x(2) - data.x(1);
            pos(4) = data.y(2) - data.y(1);
        end
    end
    
end

