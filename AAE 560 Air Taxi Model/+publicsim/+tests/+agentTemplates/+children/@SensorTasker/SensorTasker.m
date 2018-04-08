classdef SensorTasker < publicsim.agents.functional.Tasking  & publicsim.agents.hierarchical.Child
    
    properties
        configTaskingClass='Sensor'
        configTaskingFunction='publicsim.funcs.taskers.SensorWeightedRoundRobin'
        configAssessingClass='Track'
    end
    
    methods
        function obj=SensorTasker()
        end
        
        function init(obj)
            obj.setTaskingGroupId(obj.groupId);
            obj.enableTasking(obj.configTaskingFunction,obj.configTaskingClass,obj.configAssessingClass);
        end
    end
    
end

