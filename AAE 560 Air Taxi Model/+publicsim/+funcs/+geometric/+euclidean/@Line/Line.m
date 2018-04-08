classdef Line < publicsim.tests.UniversalTester
    %LINE Defines what makes a line, parametric form
    
    properties (SetAccess = private)
        v0; % Initial point
        slope; % Slope of each dimension
    end
    
    methods
        function obj = Line()
            % Nothing at construction
        end
        
        function constructFromVectors(obj, v0, slope)
            assert(all(size(v0) == size(slope)), 'Initial point and slope must have the same dimensions!');
            obj.v0 = v0;
            obj.slope = slope;
        end
        
        function y = getPointAt(obj, t)
            % Returns the point at t along the line
            y = obj.v0 + t * obj.slope;
        end
        
        function [dist, closestPoint, t] = distToPoint(obj, point)
            % Returns the distance, closest point, and 't' to point
            assert(all(size(point) == size(obj.v0)), 'Point and line must share the same space!');
            normSlope = obj.slope / norm(obj.slope); % Unit vector of slope
            t = dot((point - obj.v0), normSlope);
            closestPoint = obj.v0 + t * normSlope;
            dist = norm((point - obj.v0) - t * normSlope);
            t = t / norm(obj.slope); % Convert back to non-normal slope space
        end
    end
    
end

