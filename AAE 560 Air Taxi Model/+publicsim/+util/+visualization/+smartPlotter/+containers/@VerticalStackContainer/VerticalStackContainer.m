classdef VerticalStackContainer < publicsim.util.visualization.smartPlotter.containers.Container
    %VERTICALSTACKCONTAINER Container where all elements are stacked
    %vertically
    
    properties
    end
    
    methods
        
        function obj = VerticalStackContainer()
            obj = obj@publicsim.util.visualization.smartPlotter.containers.Container();
            obj.setSetChildBounds(0);
        end
        
        function handles = plot(obj, fig, varargin)
            % Set the bounds of each plot element to be stack on top of
            % each other within the bounds of this container
            bounds = obj.bounds;
            numElements = numel(obj.plotElements);
            for i = 1:numElements
                bounds.yMin = obj.bounds.yMin + ((i - 1) * (obj.bounds.yMax - obj.bounds.yMin) / (numElements));
                bounds.yMax = obj.bounds.yMin + (i * (obj.bounds.yMax - obj.bounds.yMin) / (numElements));
                obj.plotElements{i}.setBounds(bounds);
            end
            handles = plot@publicsim.util.visualization.smartPlotter.containers.Container(obj, fig, varargin{:});
        end
    end
    
end

