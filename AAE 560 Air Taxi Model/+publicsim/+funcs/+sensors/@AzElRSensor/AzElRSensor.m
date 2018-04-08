classdef AzElRSensor < publicsim.funcs.sensors.Sensor
    
    % Sensor Properties
    properties (SetAccess=protected)
        azimuth_bounds = [-180, 180];
        elevation_bounds = [-90,90];
        range_bounds = [0, 100000];
    end
    
    % Error Properties
    properties (SetAccess=protected)
        angular_resolution = [0, 0]; % no error.  Replace with sensor angular resolution.
        range_resolution = 0; % m
        range_multiplier = 1;
        error_multiplier = 1;
        
        error_stdev = 1;
        error_distribution = @randn
    end
    
    properties (SetAccess=immutable)
        EARTH
        earth_type
    end
    
    methods
        function obj=AzElRSensor()
            obj.EARTH = publicsim.util.Earth();
            obj.earth_type = 'elliptical';
            obj.EARTH.setModel(obj.earth_type);
            obj.outputType={'ECEF','AZELR'};
        end
        
        function setAzimuthBounds(obj,azimuth_bounds)
            obj.azimuth_bounds=azimuth_bounds;
        end
        function setElevationBounds(obj,elevation_bounds)
            obj.elevation_bounds=elevation_bounds;
        end
        
        function [observationsOutput, visible_ids, errorsOutput]=getObservations(obj,observables,sensorStatus)
            sensorPosition=sensorStatus.position;
            [ids, ecef_state_array] = obj.extractPositionInformation(observables); %#ok<ASGLU>
            az_el_r_state_array = obj.getAzElR(sensorPosition,ecef_state_array);  % MAY NEED TO MAKE THIS INHERIT A MOVEMENT CHARACTERISTIC
            visible_ids = obj.getVisibleObjects(az_el_r_state_array);
            [observations, errors] = obj.generateMeasurement(az_el_r_state_array(visible_ids,:));
            if ~isempty(observations)
                errorsOutput.AZELR=errors;
                observationsOutput.AZELR=observations;
                errorsOutput.ECEF=obj.getECEFErrors(sensorPosition,observations,errors);
                observationsOutput.ECEF = obj.batchAzElR2ECEF(sensorPosition,observations);
            else
                errorsOutput=[];
                observationsOutput=[];
            end
        end
        
        function [measurements,errors] = generateMeasurement(obj,target_array)
            error_resolution = [obj.angular_resolution, obj.range_resolution];
            assert(size(target_array,2) == 3); %[azimuth, elevation, range]
            errors = obj.error_distribution(size(target_array)).*...
                repmat(error_resolution,size(target_array,1),1)*obj.error_multiplier*obj.error_stdev;
            errors(:,3) = errors(:,3)*obj.range_multiplier;
            measurements = target_array + errors;
            
            measurements = publicsim.funcs.sensors.AzElRSensor.fixMeasurementBounds(measurements);
        end
        
        function out = batchAzElR2ECEF(obj,sensor_location,array)
            assert(size(array,2)==3) % this only works for az el r arrays
            out = nan(size(array));
            
            sensor_lla = obj.EARTH.convert_ecef2lla(sensor_location);
            
            for i = 1:size(array,1)
                out(i,:) = obj.EARTH.convert_azelr2ecef(sensor_lla,array(i,1),array(i,2),array(i,3)); % this function is terrible.
            end
            
        end
        
        function errors = getECEFErrors(obj,sensor_location,target_lla_positions,input_errors)
            errors=zeros(size(target_lla_positions,1),size(target_lla_positions,2));
            sensor_lla = obj.EARTH.convert_ecef2lla(sensor_location);
            for i=1:size(target_lla_positions,1)
                base=target_lla_positions(i,:);
                azelR_noise=input_errors(i,:);
                fullNoiseMatrix=zeros(numel(azelR_noise),3);
                for k=1:numel(azelR_noise)
                    mult=-1:1:1;
                    fullNoiseMatrix(k,:)=mult*azelR_noise(k);
                end
                
                obs=zeros(size(fullNoiseMatrix,1),size(fullNoiseMatrix,2),length(base));
                for k=1:size(fullNoiseMatrix,1)
                    for j=1:size(fullNoiseMatrix,2)
                        addNoise=zeros(length(base),1);
                        addNoise(k)=fullNoiseMatrix(k,j);
                        measurement=base+addNoise';
                        obs(k,j,:)=obj.EARTH.convert_azelr2ecef(sensor_lla,measurement(1),measurement(2),measurement(3));
                    end
                end
                
                lowers=squeeze(min(min(obs)));
                uppers=squeeze(max(max(obs)));
                errors(i,:)=abs(lowers-uppers);
                
            end
        end
        
        function az_el_r_array = getAzElR(obj,self_location, ecef_array)
            assert(size(ecef_array,2)==3,'ecef_array must be a row vector or an array of row vectors!');
            az_el_r_array = nan(size(ecef_array));
            
            for i = 1:size(ecef_array,1)
                [az,el,r] = obj.EARTH.convert_ecef2azelr(self_location,ecef_array(i,:));
                az_el_r_array(i,:)=[az,el,r];
            end
        end
        
        function visible_ids = getVisibleObjects(obj,array)
            assert(obj.azimuth_bounds(1)<=obj.azimuth_bounds(2),'Azimuth max must be greater than or equal to azimuth min!');
            assert(obj.elevation_bounds(1)<=obj.elevation_bounds(2),'Elevation max must be greater than or equal to elevation min!');
            assert(obj.range_bounds(1)<=obj.range_bounds(2),'Range max must be greater than or equal to elevation min!');
            
            in_azimuth = array(:,1) >= obj.azimuth_bounds(1) & array(:,1) <= obj.azimuth_bounds(2);
            in_elevation = array(:,2) >= obj.elevation_bounds(1) & array(:,2) <= obj.elevation_bounds(2);
            in_range = array(:,2) >= obj.range_bounds(1) & array(:,2) <= obj.range_bounds(2);
            
            visible_ids = find(in_azimuth & in_elevation & in_range);
            
        end
    end
    
    methods (Static)
        function fixed_measurements = fixMeasurementBounds(measurements)
            
            fixed_measurements = nan(size(measurements));
            
            for i = 1:size(measurements,1)
                % Fix the bounds
                az = measurements(i,1);
                el = measurements(i,2);
                if isnan(el) || isinf (el) || isnan(az) || isinf (az)
                    continue;
                end
                
                while el>90
                    el = abs(el-180);
                    az = az+180;
                end
                
                while el<-90
                    el = -1*abs(el+180);
                    az = az+180;
                end
                
                while az > 180
                    az = az-360;
                end
                
                while az < -180
                    az = az+360;
                end
                
                fixed_measurements(i,1) = az;
                fixed_measurements(i,2) = el;
                fixed_measurements(i,3) = measurements(i,3);
            end
        end
        
    end
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.sensors.AzElRSensor.test_azElRSensor';
            tests{2} = 'publicsim.funcs.sensors.AzElRSensor.test_noiseTransform';
            tests{3} = 'publicsim.funcs.sensors.AzElRSensor.test_bounds';
        end
    end
    
    methods (Static)
        
        function test_azElRSensor()
            a = publicsim.funcs.sensors.AzElRSensor();
            
            observables = {};
            for i = 1:3
                % Create target
                newObservable = publicsim.agents.test.SensorTarget;
                % Create movement manager
                movable = publicsim.funcs.movement.StateManager();
                newObservable.setMovementManager(movable);
                newObservable.setInitialState(0,{'position',100*rand(1,3),'velocity',100*rand(1,3),'acceleration',[0 0 0]});
                observables{i} = newObservable; %#ok<AGROW>
            end
            
            a.getObservations([0,0,0],observables);
        end
        
        function test_noiseTransform()
            a = publicsim.funcs.sensors.AzElRSensor();
            
            sensor_location=[0 0 0];
            observations=[ 0 0 100; ...
                180 0 100; ...
                0 0 100;];
            noises = [ 1 1 0; ...
                1 1 0; ...
                0 0 5;];
            errors = a.getECEFErrors(sensor_location,observations,noises);
            
            noise_expected=[tand(noises(1,1))*observations(1,3)*2 tand(noises(1,2))*observations(1,3)*2 0;...
                tand(noises(2,1))*observations(2,3)*2 tand(noises(2,2))*observations(2,3)*2 0;...
                tand(noises(3,1))*observations(3,3)*2 tand(noises(3,2))*observations(3,3)*2 noises(3,3)*2];
            
            assert(~any(any(abs(noise_expected-errors)>1)),'Errors not within tolerance');
        end
        
        function test_bounds()
            a = publicsim.funcs.sensors.AzElRSensor();
            
            testLoc=[100 100 100+7e6];
            sensLoc=[0,0,7e6];
            observables = {};
            new_observable = publicsim.agents.test.SensorTarget();
            movable=publicsim.funcs.movement.NewtonMotion(3);
            new_observable.setMovementManager(movable);
            new_observable.setInitialState(0,{'position',testLoc,'velocity',[0 0 0],'acceleration',[0 0 0]});
            new_observable.setDimensions(10,5);
            new_observable.setHeading([0 1 0]);
            observables{1}=new_observable;
            
            obs=a.getObservations(sensLoc,observables);
            assert(~isempty(obs),'Error in measurement');
            assert(sum(abs(testLoc-obs))<1e-3,'Error in Measurement');
            %a.setAzimuthBounds([40 50]);
            %obs=a.getObservations([0,0,0],observables);
            [azelr]=a.getAzElR(sensLoc,testLoc);
            targetVec=testLoc-sensLoc;
            targetDist=sqrt(sum(targetVec.^2));
            assert(abs(azelr(3)-targetDist)<1e-3,'Distance Error');
            [testLLA]=a.EARTH.convert_ecef2lla(testLoc);
            [sensLLA]=a.EARTH.convert_ecef2lla(sensLoc);
            spheroid = referenceEllipsoid('WGS 84');
            [taz,tel,tr] = geodetic2aer( testLLA(1),testLLA(2),testLLA(3),sensLLA(1),sensLLA(2),sensLLA(3),spheroid);
            assert(abs(taz-azelr(1))<1e-3,'Error in Azimuth');
            assert(abs(tel-azelr(2))<1e-3,'Error in Elevation');
            assert(abs(tr-azelr(3))<1e-3,'Error in Range');
            
            azbounds=-180:5:180;
            allObs={};
            for i=1:length(azbounds)-1
                a.setAzimuthBounds([azbounds(i) azbounds(i+1)-1e-9]);
                obs=a.getObservations(sensLoc,observables);
                if ~isempty(obs)
                    allObs{end+1}={i,obs}; %#ok<AGROW>
                end
            end
            assert(numel(allObs)==1,'Azimuth bound failure');
        end
    end
end

