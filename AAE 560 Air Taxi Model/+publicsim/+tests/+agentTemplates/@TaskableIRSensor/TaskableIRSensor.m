classdef TaskableIRSensor < publicsim.agents.functional.Sensing
    
    properties
        configTaskableType='Sensor'
        configSensorType='publicsim.funcs.sensors.TaskableIR'
        groupId
    end
    
    methods
        
        function obj=TaskableIRSensor()
        end
        
        function init(obj)
            obj.enableObservationTransmission();
            obj.enableSensing(obj.configSensorType);
            obj.setTaskableGroupId(obj.groupId);
        end
        
        function setGroupId(obj,id)
            obj.groupId=id;
        end
    end
    
        %%%% TEST METHDOS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests = {};
        end
    end
    
end

