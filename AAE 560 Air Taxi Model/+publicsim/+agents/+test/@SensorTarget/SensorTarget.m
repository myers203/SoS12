classdef SensorTarget < publicsim.agents.base.Movable & publicsim.agents.base.Detectable
    properties
    end
    
    methods
        function obj=SensorTarget()
            % this is only to be used as a test agent!  Do not incorporate
            % into running code!
            
            
        end
        
        function v=getCurrentTime(obj) %#ok<MANU>
            v = 0;
        end
        function init(obj) 
            obj.setHeading(obj.getVelocity())
        end
        
        function runAtTime(~) 
        end
        
        function updateIrradiance(obj)
            obj.setIrradiance(1e9); % make it bright.
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

