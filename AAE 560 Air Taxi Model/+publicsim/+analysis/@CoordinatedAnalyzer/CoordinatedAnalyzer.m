classdef CoordinatedAnalyzer < publicsim.funcs.basic.Memoizable
    %COORDINATEDANALYZER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        coordinator = [];
    end
    
    methods
        function obj = CoordinatedAnalyzer(coordinator)
            obj.coordinator = coordinator;
        end
    end
    
end

