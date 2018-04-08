classdef Detectable < publicsim.funcs.detectables.RadarDetectable & publicsim.funcs.detectables.IRDetectable
    %DETECTABLE Agent supports both IR and RADAR detection
    %
    % Inherits from publicsim.funcs.detectables.RadarDetectable and
    % publicsim.funcs.detectables.IRDetectable
    
    properties
    end
    
    methods
        function obj=Detectable()
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

