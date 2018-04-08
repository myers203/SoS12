classdef Container < publicsim.util.visualization.smartPlotter.Plottable
    %CONTAINER Basic container
    
    properties (SetAccess = private)
        plotElements = {};
        indexer = 0;
        setChildBounds = 1;
    end
    
    methods
        function obj = Container()
            obj.setColorizer(publicsim.util.visualization.smartPlotter.Colorizer());
        end
        
        function addPlotElement(obj, plotElement, varargin)
            obj.indexer = obj.indexer + 1;
            obj.plotElements{end + 1} = plotElement;
            plotElement.setId(obj.indexer);
            
            np = inputParser;
            np.addParameter('setColorizer', 1, @isnumeric)
            np.parse(varargin{:});
            if np.Results.setColorizer
                obj.colorizer.addElement(plotElement);
            end
        end
        
        function handles = plot(obj, fig, varargin)
            
            
            np = inputParser;
            np.addParameter('isMaster', 0, @isnumeric);
            np.parse(varargin{:});
            
            figure(fig);
            hold on;
            handles = {};
            % First, get all known layers
            layers = [];
            for i = 1:numel(obj.plotElements)
                if any(layers == obj.plotElements{i}.layer)
                    continue;
                else
                    layers(end + 1) = obj.plotElements{i}.layer;
                end
            end
            
            layers = sort(layers); % Sort ascending
            % Plot the bottom layers first
            for i = 1:numel(layers)
                for j = 1:numel(obj.plotElements)
                    if layers(i) == obj.plotElements{j}.layer
                        if obj.setChildBounds
                            obj.plotElements{j}.setBounds(obj.bounds);
                        end
                        newHandles = obj.plotElements{j}.plot(fig);
                        handles = {handles{:}, newHandles{:}}; %#ok
                    end
                end
            end
            
            if np.Results.isMaster
                % Top level container, set the graph bounds
                if ~isempty(obj.bounds.xMin) && ~isempty(obj.bounds.xMax)
                    xlim([obj.bounds.xMin, obj.bounds.xMax]);
                end
                
                if ~isempty(obj.bounds.yMin) && ~isempty(obj.bounds.yMax)
                    ylim([obj.bounds.yMin, obj.bounds.yMax]);
                end
            end
        end
        
        function setSetChildBounds(obj, bool)
            obj.setChildBounds = bool;
        end
    end
    
end

