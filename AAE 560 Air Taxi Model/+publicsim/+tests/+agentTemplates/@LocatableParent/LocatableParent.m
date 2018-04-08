classdef LocatableParent < publicsim.agents.base.Locatable & publicsim.agents.hierarchical.Parent
    
    properties
    end
    
    methods
        function obj=LocatableParent()
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()            
            tests = {}; 
        end
    end
    
end

