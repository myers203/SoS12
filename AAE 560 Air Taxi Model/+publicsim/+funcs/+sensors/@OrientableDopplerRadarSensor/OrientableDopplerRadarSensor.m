classdef OrientableDopplerRadarSensor < publicsim.funcs.sensors.DopplerRadar & publicsim.funcs.sensors.OrientableSensor
    %ORIENTABLEDOPPLERRADARSENSOR Orientable doppler radar
    
    properties
    end
    
    methods
        
        function obj = OrientableDopplerRadarSensor()
            obj@publicsim.funcs.sensors.DopplerRadar();
            
            % Create the frustum
            conical = publicsim.funcs.geometric.frustum.Conical();
            obj.setFrustum(conical);
        end
        
        function setFieldOfView(obj, fov)
            obj.frustum.setFieldOfView(fov);
        end
        
        function [observations, visible_ids, errors] = ...
                getObservations(obj,observables,sensorStatus)

            [az_el_r_state_array,ecef_state_array,rcs_vector,ids] = obj.getLocalState(observables,sensorStatus);
            
            sensorVelocity=sensorStatus.velocity;
            az_el_r_velocity = obj.getAzElR(sensorVelocity,ecef_state_array(:,4:6));
            r_velocity = az_el_r_velocity(:,3);
            
            % Update the frustum
            obj.frustum.setPosition(sensorStatus.position);
            obj.frustum.orientFrustum(obj.pointerHandle());
            
            visible_ids = obj.frustum.isPointInFrustum(ecef_state_array(:, 1:3));
            
            [observations.AZELR,errors.AZELR] = ...
                obj.generateMeasurement(...
                az_el_r_state_array(visible_ids,:),rcs_vector(visible_ids),r_velocity(visible_ids));
            % Removing   r_velocity(visible_ids) from input as
            % generateMeasurement can only take two inputs.
            
            [observations.ECEF,errors.ECEF] = obj.convertObservationsEcef(observations.AZELR,errors.AZELR,sensorStatus);
            visible_ids=[ids{visible_ids}]';
        end
        
        function getVisibleObjects(~, ~)
            error('Method not available for orientalbe doppler radar sensor!');
        end
    end
    
end

