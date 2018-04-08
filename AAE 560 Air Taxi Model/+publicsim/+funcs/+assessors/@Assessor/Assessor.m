classdef Assessor < handle
    %ASSESSOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        period=5;
    end
    
    methods
        function obj=Assessor()
        end
        
        function waitTime=getWaitTime(obj,time) %#ok<INUSD>
            waitTime=obj.period;
        end
    end
    
    methods(Abstract)
        updateAssessorData(obj,time,ids,inputDatas) 
        [ids,priorities,otherData]=getPriorities(obj,time) 
    end
    
end

