classdef EyeOfSauron < publicsim.funcs.sensors.DopplerRadar
    
    properties (SetAccess=protected)
        nObjects = 0;
    end
    
    methods
        function obj=EyeOfSauron()
            obj = obj@publicsim.funcs.sensors.DopplerRadar();
            obj.elevation_bounds=[0 90];
            obj.range_bounds = [0 1e7];
            obj.transmit_peak_power = 1e23;
        end
    end
    
    methods (Static)
        function eyeOfSauronRadarTest()
            % See rotating radar test for implementation.
            disp('You shall not pass! (but the test did)');
        end
    end
end

