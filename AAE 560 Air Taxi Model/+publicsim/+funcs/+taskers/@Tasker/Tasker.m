classdef Tasker < handle
    %TASKER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        period=5;
    end
    
    methods
        
        function obj=Tasker()
        end
        
        function waitTime=getWaitTime(obj,time) %#ok<INUSD>
            waitTime=obj.period;
        end
        
        function setPeriod(obj,period)
            obj.period=period;
        end
        
    end
    
    methods (Abstract)
        addNewAssessments(obj,ids,priorities,otherDatas)
        
        %May process updates as well
        addTaskableAsset(obj,time,id,otherData)
        
        [commands,ids]=getTasking(obj,time)
    end
    
end

