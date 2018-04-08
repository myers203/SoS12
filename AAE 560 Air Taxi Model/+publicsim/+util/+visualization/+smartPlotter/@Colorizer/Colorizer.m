classdef Colorizer < handle
    %COLORIZER Assigns independant colors to each of its elements
    
    properties (SetAccess = private)
        indexer = 0;
        colorMap;
    end
    
    properties (Access = private)
        default_colorMap = jet;
        
        colorIdToIndexMap;
    end
    
    methods
        
        function obj = Colorizer(varargin)
            np = inputParser;
            np.addParameter('colorMap', obj.default_colorMap, @isnumeric);
            np.parse(varargin{:});
            
            obj.setColorMap(np.Results.colorMap);
            obj.colorIdToIndexMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
        end
        
        function addElement(obj, newElement, varargin)
            np = inputParser;
            np.addParameter('colorId', [], @isnumeric);
            
            np.parse(varargin{:});
            if isempty(np.Results.colorId)
                obj.indexer = obj.indexer + 1;
                newElement.setColorId(obj.indexer);
                obj.colorIdToIndexMap(newElement.colorId) = obj.indexer;
            else
                newElement.setColorId(np.Results.colorId);
                if ~isKey(obj.colorIdToIndexMap, np.Results.colorId)
                    obj.indexer = obj.indexer + 1;
                    obj.colorIdToIndexMap(np.Results.colorId) = obj.indexer;
                end
            end
            newElement.setColorizer(obj);
        end
        
        function color = getColor(obj, plotElement)
            index = obj.colorIdToIndexMap(plotElement.colorId);
            color = publicsim.util.visualization.smartPlotter.util.getColorFromMap(obj.colorMap, index / (obj.indexer + 1));
        end
        
        function setColorMap(obj, colorMap)
            obj.colorMap = colorMap;
        end
    end
    
end

