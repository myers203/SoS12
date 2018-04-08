classdef Frustum < publicsim.tests.UniversalTester
    %FRUSTUM Abstractly defines what a frustum should do
    
    properties (SetAccess = private)
        position % Reference point of the frustum
    end
    
    methods
        function obj = Frustum()
            % Create the frustum object
        end
        
        function setPosition(obj, position)
            obj.position = position;
        end
        
        
    end
    
    methods (Abstract)
        bool=isPointInFrustum(obj, points); % Returns a boolean array of which points are in the frustum
        orientFrustum(obj, vector); % Orients the frustum to the supplied vector, usually on center line
    end
    
end

