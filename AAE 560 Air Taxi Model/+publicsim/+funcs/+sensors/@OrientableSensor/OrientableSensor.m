classdef OrientableSensor < publicsim.funcs.sensors.Sensor
    %ORIENTABLESENSOR Sensor that can be oriented in a specific direction
    
    properties (SetAccess = private)
        frustum; % View frustum
        pointerHandle; % Function handle to retreive the point direction of the sensor
    end
    
    methods 
        function setFrustum(obj, frustum)
            obj.frustum = frustum;
        end
        
        function setPointerHandle(obj, fh)
            obj.pointerHandle = fh;
        end
    end
    
%     methods (Abstract)
%         updatePointDirection(obj, varargin); % Updates the point direction of the sensor
%     end
    
end

