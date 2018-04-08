classdef SensorTarget < publicsim.agents.base.Movable & publicsim.agents.base.Periodic & publicsim.agents.base.Detectable
        
    properties
    end
    
    methods
        function obj = SensorTarget()
            
        end
        
        function init(obj) 
            obj.setHeading(obj.getVelocity());
            obj.setDimensions(10,1);
        end
        
        function runAtTime(obj,~); end %#ok<INUSD>
        
        function updateIrradiance(obj)
           obj.setIrradiance(1e9); 
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

