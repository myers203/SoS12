classdef Plottable < handle
    %PLOTTABLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        name = '';
        id; % Container-unique ID set by the parent
        bounds = struct('xMin', [], ...
            'xMax', [], ...
            'yMin', [], ...
            'yMax', [], ...
            'zMin', [], ...
            'zMax', []); % Positional bounds the element should abide by
        layer = 0; % Default layer, increasing number
        container; % The container that orchestrates this element's plotting
        colorizer; % What provides the color
        colorId;
    end
    
    methods
        
        function setId(obj, id)
            obj.id = id;
        end
        
        function setName(obj, name)
            obj.name = name;
        end
        
        function setBounds(obj, bounds)
            fieldNames = fields(bounds);
            for i = 1:numel(fieldNames)
                if ~isempty(bounds.(fieldNames{i}))
                    obj.bounds.(fieldNames{i}) = bounds.(fieldNames{i});
                end
            end
        end
        
        function setLayer(obj, layer)
            obj.layer = layer;
        end
        
                
        function setContainer(obj, container)
            obj.container = container;
        end
        
        function setColorizer(obj, colorizer)
            obj.colorizer = colorizer;
        end
        
        function setColorId(obj, id)
            obj.colorId = id;
        end
        
    end
    
    methods (Abstract)
        handles = plot(obj, fig)
    end
    
    
end

