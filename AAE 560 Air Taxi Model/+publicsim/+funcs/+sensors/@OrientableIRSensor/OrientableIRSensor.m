classdef OrientableIRSensor < publicsim.funcs.sensors.IRSensor & publicsim.funcs.sensors.OrientableSensor
    %ORIENTABLEIRSENSOR IR sensor that is orientable
    
    properties
    end
    
    methods
        
        function obj = OrientableIRSensor()
            obj@publicsim.funcs.sensors.IRSensor();
            
            % Create the frustum
            conical = publicsim.funcs.geometric.frustum.Conical();
            obj.setFrustum(conical);

        end
        
        function setFieldOfView(obj, fov)
            obj.frustum.setFieldOfView(fov);
        end
        
        function [observations, visibleIds, errors] = getObservations(obj, observables, sensorStatus)            
            [azElRStateArray,ecefStateArray,ids,perceivedIrradiance] = obj.getLocalState(observables,sensorStatus);
            
            obj.frustum.setPosition(sensorStatus.position);
            obj.frustum.orientFrustum(obj.pointerHandle());
            
            visibleIds = obj.frustum.isPointInFrustum(ecefStateArray(:, 1:3));
            
            if isempty(visibleIds)
               observations = [];
               visibleIds = [];
               errors = [];
               return
            end
            
            [observation,error] = ...
                obj.generateMeasurement(...
                azElRStateArray(visibleIds,:),perceivedIrradiance(visibleIds));
            % Removing   r_velocity(visible_ids) from input as
            % generateMeasurement can only take two inputs.
            
            % Note difference between observation and observations &
            % between error and errors
            errors.AZELR=error;
            observations.AZELR=observation;
            
            if obj.generate3DTrack
                [observations.ECEF,errors.ECEF] = obj.convertObservationsEcef(observation,error,sensorStatus);
            end
            visibleIds=[ids{visibleIds}]';
        end
        
        function getVisibleObjects(~, ~)
            error('Method not available for orientalbe IR sensor!');
        end
    end
    
end

