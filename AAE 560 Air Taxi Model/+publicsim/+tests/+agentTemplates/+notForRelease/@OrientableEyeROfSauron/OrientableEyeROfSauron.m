classdef OrientableEyeROfSauron < publicsim.funcs.sensors.OrientableIRSensor
    
    properties (SetAccess=protected)
        nObjects = 0;
    end
    
    methods
        function obj=OrientableEyeROfSauron()
            obj = obj@publicsim.funcs.sensors.OrientableIRSensor();
        end
    end
end

