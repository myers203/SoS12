classdef NetworkedSensor < publicsim.agents.functional.Sensing & publicsim.agents.base.Movable
    %NETWORKEDSENSOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        sensorType='publicsim.funcs.sensors.GaussianNoise';
        sensingPeriod=1.0;
    end
    
    properties(SetAccess=private)

    end
    
    properties(Constant)
        
    end

    methods
        function obj=NetworkedSensor()
        end
        
        function init(obj)
            obj.enableSensing(obj.sensorType);
            obj.setSensorParameter('scanPeriod',1.0);
        end
        
        
        function runAtTime(obj,time) %#ok<INUSD>
            %No need to do anything, handled by sensing
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

