classdef InspectorTest < publicsim.agents.base.Periodic
    %INSPECTORTEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        publicParam=99;
    end
    
    properties(SetObservable)
        listenParam1=11;
        listenParam2=22;
        listenParam3=33;
    end
        
    
    methods
        function obj=InspectorTest()
        end
        
        function param=getOtherParam(~)
            param=89;
        end
        
        function init(obj)
            obj.initPeriodic(0.5);
        end
        
        function runAtTime(obj,time)
            if obj.isRunTime(time)
                obj.listenParam1=obj.listenParam1+1;
                obj.listenParam2=obj.listenParam2+1;
            end
        end
        
        
    end
    
end

