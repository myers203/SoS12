classdef DopplerRadar < publicsim.funcs.sensors.Radar
    
    properties
    end
    
    methods
        function obj=DopplerRadar()
            obj = obj@publicsim.funcs.sensors.Radar();
        end
        
        function [observations, visible_ids, errors] = ...
                getObservations(obj,observables,sensorStatus)

            [az_el_r_state_array,ecef_state_array,rcs_vector,ids] = obj.getLocalState(observables,sensorStatus);
            
            sensorVelocity=sensorStatus.velocity;
            az_el_r_velocity = obj.getAzElR(sensorVelocity,ecef_state_array(:,4:6));
            r_velocity = az_el_r_velocity(:,3);
            
            visible_ids = obj.getVisibleObjects(az_el_r_state_array);
            
            [observations.AZELR,errors.AZELR] = ...
                obj.generateMeasurement(...
                az_el_r_state_array(visible_ids,:),rcs_vector(visible_ids),r_velocity(visible_ids));
            % Removing   r_velocity(visible_ids) from input as
            % generateMeasurement can only take two inputs.
            
            [observations.ECEF,errors.ECEF] = obj.convertObservationsEcef(observations.AZELR,errors.AZELR,sensorStatus);
            visible_ids=[ids{visible_ids}]';
        end
        
        function [measurements,measurement_error] = ...
                generateMeasurement(obj,target_array,RCS_vector,r_velocity)
            
            measurements=[];
            measurement_error=[];
            
            [position_measurements, position_error]=generateMeasurement@publicsim.funcs.sensors.Radar(obj,target_array,RCS_vector);
            
            if isempty(position_measurements)
                measurements = [];
                measurement_error = [];
                return
            end
            
            [SNR,~] = obj.getSNR(target_array,RCS_vector);
            
            % 4.5 in Radar System Performance Modeling
            waveform_duration = obj.pulse_duration*(obj.n_pulses-1);
            frequency_resolution = 1/waveform_duration;
            velocity_resolution = obj.wavelength*frequency_resolution/2;
            
            % 8.13 in Radar System Performance Modeling
            velocity_accuracy = velocity_resolution./sqrt(2*SNR);
            
            r_velocity_error = obj.error_distribution(size(r_velocity)).*velocity_accuracy;
            r_velocity_measurements = r_velocity + r_velocity_error;
            
            measurements = [position_measurements, r_velocity_measurements];
            measurement_error = [position_error, r_velocity_error];
            
            % probability of detection has already been determined.  Remove
            % the data for undetected obervables.
            
            measurements(isnan(measurements(:,1)),:)=nan;
            measurement_error(isnan(measurements(:,1)),:)=nan;
            
        end
    end
    
    methods (Static)
        
        function [ids, state_array,rcs_array] = ...
                extractStateInformation(sensor_location, observable_targets, wavelength)
            state_array = nan(length(observable_targets),...
                length(observable_targets{1}.getPosition())+...
                length(observable_targets{1}.getVelocity()));
            rcs_array = nan(numel(observable_targets),1);
            
            ids=cell(numel(observable_targets),1);
            for i=1:numel(observable_targets)
                ids{i}=observable_targets{i}.movableId;%observable_targets{i}.id; % TODO: What's the ID structure?
                state_array(i,:) = [...
                    observable_targets{i}.getPosition(),...
                    observable_targets{i}.getVelocity()];
                rcs = observable_targets{i}.getRCS( sensor_location , observable_targets{i}.getPosition(), wavelength );
                if isempty(rcs)
                    rcs=NaN;
                end
                rcs_array(i) = rcs;
            end
        end
        
        function radarTest()
            
            a = publicsim.funcs.sensors.Radar();
            
            sensorStatus=publicsim.funcs.sensors.Sensor.SENSOR_STATUS;
            sensorStatus.position=[0 0 0];
            sensorStatus.velocity=[0 0 0];
            
            observables = {};
            
            
            for i = 1:3
                new_observable = publicsim.agents.test.SensorTarget();
                movable=publicsim.funcs.movement.NewtonMotion(3);
                new_observable.setMovementManager(movable);
                new_observable.setInitialState(0,{'position',100*rand(1,3),'velocity',[0 0 0],'acceleration',[0 0 0]});
                new_observable.setDimensions(10,5);
                new_observable.setHeading([0 1 0]);
                
                observables{i} = new_observable; %#ok<AGROW>
            end
            
            a.getObservations(observables,sensorStatus);
            
            disp('Passed Radar test!');
        end
    end
end

