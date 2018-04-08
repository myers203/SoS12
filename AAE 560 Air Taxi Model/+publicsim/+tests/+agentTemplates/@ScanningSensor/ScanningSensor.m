classdef ScanningSensor < publicsim.agents.functional.Sensing & publicsim.agents.functional.Tracking & publicsim.agents.hierarchical.Child
    properties
        configSensorType='publicsim.funcs.sensors.RotatingRadar';
        trackerGroupId=1
        %groupId
    end
    
    properties(Constant)
        configTrackerType='publicsim.funcs.trackers.BasicKalman(6)';
    end
    
    methods
        
        function obj = ScanningSensor()
        end
        
        function init(obj)
            obj.enableSensing(obj.configSensorType);
            obj.setTrackMessageKeys([],obj.groupId);
            obj.enableTracking(obj.configTrackerType);
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

