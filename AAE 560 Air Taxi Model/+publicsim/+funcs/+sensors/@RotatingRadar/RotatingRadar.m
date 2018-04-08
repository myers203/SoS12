classdef RotatingRadar < publicsim.funcs.sensors.DopplerRadar
    
    properties
        rotation_rate = 120; % deg/sec 1RPM=360deg/min=6deg/sec
        azimuth_slice = 15; % deg
        start_boresight = 0; % deg
    end
    
    properties (SetAccess=protected)
        current_boresight = 0; % deg
        last_measurement_time = 0;
        minAzNextUpdate=0;
        useFineUpdates = false;
    end
    
    methods
        function obj=RotatingRadar()
            obj = obj@publicsim.funcs.sensors.DopplerRadar();
            assert(floor(obj.azimuth_slice)<=360-1e-9,'Rotating Radar cannot have a slice greater or equal to the full space');
            obj.useFineUpdates = false;
        end
        
        function setRotationRate(obj,rotationRate)
            obj.rotation_rate=rotationRate;
        end
        
        function setLastMeasurementTime(obj,time)
           obj.last_measurement_time = time; 
        end
        
        function initializeRadar(obj)
            obj.updateBoresight(obj.start_boresight);
            if ~obj.useFineUpdates
                obj.azimuth_bounds = [-180 180];
            end
        end
        
        function updateBoresight(obj,new_boresight)
            obj.current_boresight = publicsim.util.fixAzimuthBounds(new_boresight);
            azimuth_vector = [-1,1]/2*obj.azimuth_slice + ...
                new_boresight*ones(1,2);
            obj.azimuth_bounds = publicsim.util.fixAzimuthBounds(azimuth_vector);
        end
        
        function rotateFace(obj,rotation_time)
            % should rotate the face and probably generate measurements for
            % each observable that has been passed over? Will leave that up
            % to the implementing agent.
            if obj.useFineUpdates
                new_boresight = obj.current_boresight + rotation_time*obj.rotation_rate;
                obj.updateBoresight(new_boresight);
            end
        end
        
        function waitTime=getNextScanTime(obj)
            if obj.useFineUpdates
                waitTime=obj.azimuth_slice/obj.rotation_rate;
            else
                waitTime = 360/obj.rotation_rate;
            end
        end
        
        
        function [observations, visible_ids, errors]=...
                getObservations(obj,observables,sensorStatus)

            sensorTime=sensorStatus.time;
            rotation_time = sensorTime-obj.last_measurement_time;
            obj.rotateFace(rotation_time);
            obj.setLastMeasurementTime(sensorTime);
            
            [observations,visible_ids,errors] = getObservations@publicsim.funcs.sensors.DopplerRadar(obj,observables,sensorStatus);
            
        end
    end
    
    methods (Static)
        function rotatingRadarTest()
            %manager = publicsim.funcs.sensors.RadarMeasurementManager();
            a = publicsim.funcs.sensors.RotatingRadar();
            sensorStatus=publicsim.funcs.sensors.Sensor.SENSOR_STATUS;
            sensorStatus.position=[0 0 0];
            sensorStatus.velocity=[0 0 0];
            a.azimuth_slice = 180; % deg
            
            a.rotation_rate = 180; %deg/sec
            
            testLoc=100*[0 10 10];
            new_observable=publicsim.agents.test.SensorTarget();
            movable=publicsim.funcs.movement.NewtonMotion(3);
            new_observable.setMovementManager(movable);
            new_observable.setInitialState(0,{'position',testLoc,'velocity',[0 0 0],'acceleration',[0 0 0]});
            new_observable.setDimensions(10,5);
            new_observable.setHeading([0 1 0]);
            observables{1} = new_observable;
            
            n_observations = nan(1,2);
            
            sensorStatus.time=0;
            [emptyObs] = a.getObservations(observables,sensorStatus);
            assert(isempty(emptyObs),'Observations without any rotation time');
            
            sensorStatus.time=1;
            [obs1,ids1] = a.getObservations(observables,sensorStatus); %#ok<ASGLU>
            n_observations(1) = size(obs1,1);
            
            sensorStatus.time=2;
            [obs2,ids2] = a.getObservations(observables,sensorStatus); %#ok<ASGLU>
            n_observations(2) = size(obs2,1);
            
            assert(sum(n_observations)==1);
            assert( ~any(isnan(obs1)) && size(obs1,2)==3 );
            
            disp('Passed RotatingRadar test!');
        end
    end
end

