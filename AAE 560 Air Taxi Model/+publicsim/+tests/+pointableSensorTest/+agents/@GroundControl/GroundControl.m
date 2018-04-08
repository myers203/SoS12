classdef GroundControl < publicsim.agents.base.Locatable & publicsim.agents.hierarchical.Parent
    
    properties
    end
    
    methods
        function obj=GroundControl()
        end
        
        function init(obj)
            import publicsim.tests.pointableSensorTest.agents.children.*;
            obj.addChild(Assessing());
            obj.addChild(Fusing());
            obj.addChild(Tasking());
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

