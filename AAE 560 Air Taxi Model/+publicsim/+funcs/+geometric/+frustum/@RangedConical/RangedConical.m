classdef RangedConical < publicsim.funcs.geometric.frustum.Conical
    %RANGEDCONICAL Conical type that has a maximum range
    properties (SetAccess = private)
        range;
    end
    
    methods
        
        function setRange(obj, range)
            obj.range = range;
        end
        
        function bool = isPointInFrustum(obj, points)
            % Returns a boolean array of the points in the frustum
            bool = false(1, size(points, 1));
            spatial = obj.getSpatial();
            for i = 1:size(points, 1)
                if norm(points(i, :) - spatial.position) < obj.range
                    [dist, ~, t] = obj.line.distToPoint(points(i, :));
                    rad = obj.getRadiusAtDistance(t);
                    bool(i) = dist <= rad;
                end
            end
        end
    end
    
end

