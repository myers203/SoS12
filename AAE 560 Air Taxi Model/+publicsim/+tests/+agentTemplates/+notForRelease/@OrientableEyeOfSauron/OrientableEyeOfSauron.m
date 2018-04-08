classdef OrientableEyeOfSauron < publicsim.funcs.sensors.OrientableDopplerRadarSensor
    
    properties (SetAccess=protected)
        nObjects = 0;
    end
    
    methods
        function obj=OrientableEyeOfSauron()
            obj = obj@publicsim.funcs.sensors.OrientableDopplerRadarSensor();
        end
    end
end

