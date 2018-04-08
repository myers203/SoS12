classdef PlotElement < publicsim.util.visualization.smartPlotter.Plottable
    %PLOTELEMENT Abstract class defining how plot elements must behave
    
    properties (SetAccess = private)

    end
    
    properties (SetAccess = immutable)
        key_automaticColor = 0;
    end
    
    properties (Access = private)
        color;
    end
    
    methods
        
        function obj = PlotElement()
            obj.setColor(obj.key_automaticColor);
        end

        
        function setColor(obj, color)
            obj.color = color;
        end
        


        
        % Color getter
        function color = getColor(obj)
            % If the color is automatic, let the container assign it's
            % color
            if (obj.color == obj.key_automaticColor)
                color = obj.colorizer.getColor(obj);
            else
                if isa(obj.color, 'function_handle')
                    color = obj.color();
                else
                    color = obj.color;
                end
            end
        end
        
    end
    
    methods (Static)
        % scales and shifts data to fit within bounds
        function data = shiftData(data, minVal, maxVal)
            data = data - min(data); % Shift to zero
            data = data / max(data); % Normalize
            data = data * (maxVal - minVal); % Scale to fit in range
            data = data + minVal; % Shift to within bounds
        end
        
        function data = scaleFromTo(data, oldMin, oldMax, newMin, newMax)
            data = data - oldMin;
            data = data / (oldMax - oldMin);
            data = data * (newMax - newMin);
            data = data + newMin; % Hey look at that we used all basic operators
        end
        
        function [data, bools] = getDataInBounds(data, minVal, maxVal)
            assert((size(data, 1) == 1) || (size(data, 2) == 1), 'Must be a single row or column vector');
            bools = (data >= minVal) & (data <= maxVal);
            data = data(bools);
        end
    end
    
end

