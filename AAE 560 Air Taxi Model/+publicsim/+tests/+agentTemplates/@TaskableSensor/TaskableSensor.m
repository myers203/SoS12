classdef TaskableSensor < publicsim.agents.functional.Sensing & publicsim.agents.functional.Tracking
    
    properties
        configTaskableType='Sensor'
        configTrackerType='publicsim.funcs.trackers.BasicKalman(9)';
        configSensorType='publicsim.funcs.sensors.TaskableMultiPoint'
        groupId
    end
    
    methods
        
        function obj=TaskableSensor()
        end
        
        function init(obj)
            obj.setTaskableGroupId(obj.groupId);
            obj.enableSensing(obj.configSensorType);
            obj.setTrackMessageKeys([],9999);
            obj.enableTracking(obj.configTrackerType);
        end
        
        function setGroupId(obj,id)
            obj.groupId=id;
        end
    end
    
        %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests = {};
        end
    end
    
end

