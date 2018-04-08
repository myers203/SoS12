classdef SplineInterpolater < handle
    %INTERPOLATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        splineSet
    end
    
    methods
        
        function obj=SplineInterpolater(targets,values)
            for i=1:size(values,2)
                obj.splineSet{i}=spline(targets,values(:,i));
            end
        end
        
        function value=getPoint(obj,target)
            value=zeros(numel(obj.splineSet),1);
            for i=1:numel(obj.splineSet)
                pp=obj.splineSet{i};
                value(i)=pp(target);
            end
        end
    end
    
end

