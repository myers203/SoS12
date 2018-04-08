classdef IRSensor < publicsim.funcs.sensors.AzElRSensor

    properties
        trackLatch = false
    end
    
    properties (SetAccess=protected)
        perceivedIrradianceThreshold = 1000
        atmosphericAbsorption = 0.0293
        angularAccuracy = 0.1; % degrees
        rangeAccuracy = 1e6; % meters %Will likely remove this in favor of 2D tracking
        pDetection = 0.98;   % 95% chance of detection TODO: Why do these numbers not match?
        generate3DTrack = 0;
    end
    
    properties (Constant)
        SPACE_ALTITUDE = 100e3 % altitude at which space begins and there is no atmospheric attenuation of irradiance
        ALTITUDE_TOLERANCE_ABSORPTION = 2e3 % 2 km tolerance
    end
    
    methods
        function obj=IRSensor()
            obj = obj@publicsim.funcs.sensors.AzElRSensor();
        end
        
        function setPerceivedIrradianceThreshold(obj, threshold)
            obj.perceivedIrradianceThreshold = threshold;
        end
        
        function [observations, visibleIds, errors] = ...
                getObservations(obj,observables,sensorStatus)
            [azElRStateArray,~,ids,perceivedIrradiance] = obj.getLocalState(observables,sensorStatus);

            visibleIds = obj.getVisibleObjects(azElRStateArray);
            
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
            
            [observations.ECEF,errors.ECEF] = obj.convertObservationsEcef(observation,error,sensorStatus);
            visibleIds=ids{visibleIds};
        end
        
        function [observations,errors] = convertObservationsEcef(obj,observations,errors,sensorStatus)
            if ~isempty(observations)
                % position information and errors are expected in ECEF
                sensorPosition = sensorStatus.position;
                positions = observations(:,1:3);
                position_errors = errors(:,1:3);
                
                position_errors = obj.getECEFErrors(sensorPosition,positions,position_errors);
                positions = obj.batchAzElR2ECEF(sensorPosition,positions);
                
                observations(:,1:3) = positions;
                errors(:,1:3) = position_errors;
            else
                errors=[];
                observations=[];
            end
        end
        
        function [azElRState,ecefStateArray,ids,perceivedIrradiance] = getLocalState(obj,observables,sensorStatus)
            sensorPosition=sensorStatus.position;
            [ids, ecefStateArray, perceivedIrradiance] = ...
                obj.extractStateInformation(sensorPosition,observables); 
            azElRState = obj.getAzElR(sensorPosition,ecefStateArray(:,1:3));
        end
        
        function visible_ids = getVisibleObjects(obj,array)
            assert(obj.azimuth_bounds(1)<=obj.azimuth_bounds(2),'Azimuth max must be greater than or equal to azimuth min!');
            assert(obj.elevation_bounds(1)<=obj.elevation_bounds(2),'Elevation max must be greater than or equal to elevation min!');
            
            in_azimuth = array(:,1) >= obj.azimuth_bounds(1) & array(:,1) <= obj.azimuth_bounds(2);
            in_elevation = array(:,2) >= obj.elevation_bounds(1) & array(:,2) <= obj.elevation_bounds(2);
            
            visible_ids = find(in_azimuth & in_elevation); % range computation is managed by p_detection and Irradiance for IR sensor systems.
            
        end
        
        function [measurements,measurementError] = ...
                generateMeasurement(obj,targetAzElRArray,targetPerceivedIrradiance)
            if isempty(targetAzElRArray) || size(targetAzElRArray,1) ~= numel(targetPerceivedIrradiance)
                measurements = [];
                measurementError = [];
                return
            end
            
            %Filter on the irradiance here
            brightObjects = targetPerceivedIrradiance>obj.perceivedIrradianceThreshold;
            
            targetAzElRArray = targetAzElRArray(brightObjects,:);
                        
            accuracy = [obj.angularAccuracy, obj.angularAccuracy, obj.rangeAccuracy];
            if any(accuracy==Inf)
                positionMeasurements=[nan nan nan];
            else
                accuracyMatrix = repmat(accuracy,size(targetAzElRArray,1),1);
                positionError = obj.error_distribution(size(targetAzElRArray)).*accuracyMatrix;
                positionMeasurements = targetAzElRArray + positionError;
                
                positionMeasurements = ...
                    publicsim.funcs.sensors.AzElRSensor.fixMeasurementBounds(...
                    positionMeasurements);
            end
            
            if (obj.generate3DTrack)
                measurements = positionMeasurements;
                %             measurement_error = position_error;
                measurementError = accuracyMatrix;
            else
                measurements = positionMeasurements(:, 1:2);
                measurementError = accuracyMatrix(:, 1:2);
            end
            
            %TODO may want a detection probability here, or above where the
            %irradiance filter is.
            isDetected = rand(size(targetPerceivedIrradiance))<obj.pDetection;
            isDetected = isDetected & brightObjects; % Also filter out objects too cold to see
            %TODO why not delete these?
            measurements(~isDetected,:)=nan;
            measurementError(~isDetected,:)=nan;
            
            if obj.generate3DTrack && ~obj.trackLatch
               warning('IR Sensor producing 3D Track!');
               obj.trackLatch = true;
            end
        end
        
        function perceivedIrradiance = getPerceivedIrradiance(obj,sensorPosition, targetPosition, targetIrradiance)
            % Calc irradiance perc'd by sensor at distance
            % intensity model: irradiance = intensity * tau(r[m]) / (r[m])^2
            
            range = norm(sensorPosition-targetPosition); % presuming they are ECEF values.
            
            atmosphericDistance = obj.getAtmosphericDistance(sensorPosition,targetPosition);
            
            perceivedIrradiance = ...
                targetIrradiance * obj.getAtmosphericTransmittance(atmosphericDistance,obj.atmosphericAbsorption) / range^2;
            
            if perceivedIrradiance >= 0.1
                awef =1;
            end
        end
        
        function [ids, state_array, perceivedIrradiance] = ...
                extractStateInformation(obj,sensorPosition,observableTargets)
            state_array = nan(length(observableTargets),...
                length(observableTargets{1}.getPosition())+...
                length(observableTargets{1}.getVelocity()));
            
            perceivedIrradiance = nan(numel(observableTargets),1);
            ids=cell(numel(observableTargets),1); % TODO: Why is this a cell array?
            for i=1:numel(observableTargets)
                ids{i}=observableTargets{i}.movableId;%observable_targets{i}.id; % TODO: What's the ID structure?
                state_array(i,:) = [...
                    observableTargets{i}.getPosition(),...
                    observableTargets{i}.getVelocity()];
                perceivedIrradiance(i) = obj.getPerceivedIrradiance(sensorPosition,observableTargets{i}.getPosition(),observableTargets{i}.getIrradiance());
            end
        end
        
        function atmosphericDistance = getAtmosphericDistance(obj, p1, p2)
            % Calculate the formula of the line between the two points as:
            % [x, y, z] = [x0, y0, z0] + t * [cx, cy, cz]
            % Let p(t = 0) = p1, p(t = 1) = p2
            c = (p2 - p1); % Finds the slope of the line
            % Parse for easier readability
            u = c(1);
            v = c(2);
            w = c(3);
            x = p1(1);
            y = p1(2);
            z = p1(3);
            
            % Ellipsoid of earth plus the atmosphere
            a = obj.EARTH.getRadius + obj.SPACE_ALTITUDE;
            b = obj.EARTH.getPolarRadius + obj.SPACE_ALTITUDE;
            
            % Calculate the intersection point(s), if any, with the earth
            % ellipsoid
            
            t_intersection(1) = -(1/(b^2 * (u^2 + v^2) +  a^2 * w^2)) ...
                * (b^2 * (u * x + v * y) + a^2 * w * z + ...
                1/2 * sqrt(4 * (b^2 * (u * x + v * y) + a^2 * w * z)^2 - ...
                4*(b^2 * (u^2 + v^2) + a^2 * w^2) * ...
                (b^2 * (-a^2 + x^2 + y^2) + a^2 * z^2)));
            
            % If the line never even intersects the atmosphere, then the
            % atmospheric distance will always be zero
            if imag(t_intersection(1)) ~= 0
                atmosphericDistance = 0;
                return;
            end
            
            % Else, get the second intersection
            
            t_intersection(2) = -(1/(b^2 * (u^2 + v^2) +  a^2 * w^2)) ...
                * (b^2 * (u * x + v * y) + a^2 * w * z - ...
                1/2 * sqrt(4 * (b^2 * (u * x + v * y) + a^2 * w * z)^2 - ...
                4*(b^2 * (u^2 + v^2) + a^2 * w^2) * ...
                (b^2 * (-a^2 + x^2 + y^2) + a^2 * z^2)));
            
            % Next, need limit the possible distance to that between p1 and
            % p2, which translates to between 0 <= t =< 1
            
            for i = 1:numel(t_intersection)
                if t_intersection(i) > 1
                    t_intersection(i) = 1;
                elseif t_intersection(i) < 0
                    t_intersection(i) = 0;
                end
            end
            
            % Now solve for the intersection points and get the distance
            p1_atmosphere = p1 + t_intersection(1) * c;
            p2_atmosphere = p1 + t_intersection(2) * c;
            atmosphericDistance = norm(p1_atmosphere - p2_atmosphere);
            
        end
        
        function atmosphericDistance = getAtmosphericDistance_old(obj, p1, p2)
            lla1 = obj.EARTH.convert_ecef2lla(p1); %TODO: Needs validation test
            lla2 = obj.EARTH.convert_ecef2lla(p2);
            
            a1 = lla1(3);
            a2 = lla2(3);
            
            % If both endpoints are within the atmposphere, the entire
            % distance is within the atmosphere
            if a1<=obj.SPACE_ALTITUDE && a2<=obj.SPACE_ALTITUDE
                atmosphericDistance = norm(p2-p1);
                return
            end
            
            % Else, find the lowest altitude point
            distBetweenPoints = norm(p2 - p1);
            dist1 = norm(p1);
            dist2 = norm(p2);
            % Solve the angle between the (p2 <-> p1) and (p1 <-> center)
            % vectors
            primaryAngle = acosd((dist2^2 - dist1^2 - distBetweenPoints^2) / (-2 * dist1 * distBetweenPoints));
            minDistance = sind(primaryAngle) * dist1; % Minimum distance
            if (minDistance <= (obj.SPACE_ALTITUDE + obj.EARTH.getRadius())) || (a1 <= obj.SPACE_ALTITUDE) || (a2 <= obj.SPACE_ALTITUDE)
                
                if (a1 > obj.SPACE_ALTITUDE) && (a2 > obj.SPACE_ALTITUDE)
                    % In this case, we need to check if the minimum
                    % altitude is in between these two points. If not,
                    % nothing travels through the atmosphere
                    % Angle between (p1 <-> center) and (center <-> p2)
                    secondaryAngle = acosd((distBetweenPoints^2 - dist1^2 - dist2^2) / (-2 * dist1 * dist2));
                    % Angle between (p1 <-> center) and (center <-> minDistPoint)
                    minDistanceAngle = 90 - primaryAngle;
                    if (abs(minDistanceAngle) > abs(secondaryAngle))
                        % The minimum point lies outside, thus no part
                        % travels through the atmosphere
                        atmosphericDistance = 0;
                        return;
                    end
                    % At this point, we know that some part of the line between
                    % p1 and p2 intersects the atmosphere. We can split the
                    % line into two section at the minimum altitude an call
                    % this function again, twice
                    d1 = cosd(primaryAngle) * dist1; % Distance between p1 and the minimum distance point
                    midpoint = interp1([0; 1], [p1; p2], d1 / distBetweenPoints); % Get the min distance point
                    atmosphericDistance1 = obj.getAtmosphericDistance(p1, midpoint);
                    atmosphericDistance2 = obj.getAtmosphericDistance(midpoint, p2);
                    atmosphericDistance = atmosphericDistance1 + atmosphericDistance2;
                    return;
                end
                
                % By now, we know that only one end point lies in the
                % atmosphere and only need to solve for the intersection of
                % the atmosphere and the line between p1 and p2
                absoluteAtmosphere = obj.SPACE_ALTITUDE + obj.EARTH.getRadius();
                % Solve for the length between p1 and the atmospheric
                % intersection point
                
                % Angle between (p1 <-> intersection) and (intersection <->
                % center)
                midAngle = asind(dist1 * (sind(primaryAngle) / absoluteAtmosphere));
                centerAngle = 180 - (midAngle + primaryAngle); % Last angle
                p1ToIntersection = sind(centerAngle) * (absoluteAtmosphere / sind(primaryAngle));
                if (p1ToIntersection > distBetweenPoints)
                    midAngle = 180 - midAngle;
                    centerAngle = 180 - (midAngle + primaryAngle); % Last angle
                    p1ToIntersection = sind(centerAngle) * (absoluteAtmosphere / sind(primaryAngle));
                end
                if (a1 <= obj.SPACE_ALTITUDE)
                    atmosphericDistance = p1ToIntersection;
                    return;
                else
                    atmosphericDistance = distBetweenPoints - p1ToIntersection;
                    return;
                end
                assert(atmosphericDistance < distBetwenPoints);
            else
                atmosphericDistance = 0;
                return;
            end
        end
        
        function crossEcef = altitudeBisectionSearch(obj,p1,p2)
            % Find the point in ecef space where we cross the space 
            % threshold within the tolerance we could have one or two 
            % crossings, depending on geometry.
            crossEcef = nan;
            
            lla1 = obj.EARTH.convert_ecef2lla(p1);
            lla2 = obj.EARTH.convert_ecef2lla(p2);
            
            a1 = lla1(3);
            a2 = lla2(3);
            
            if a2>a1
                higher = p2;
                lower = p1;
            else
                higher = p1;
                lower = p2;
            end
            
            stop = false;
            
            while ~stop
                mid = lower + 0.5*(higher-lower);
                testLla = obj.EARTH.convert_ecef2lla(mid);
                testAlt = testLla(3);
                if abs(testAlt-obj.SPACE_ALTITUDE)<=obj.ALTITUDE_TOLERANCE_ABSORPTION
                    stop = true;
                    crossEcef = mid;
                end
                if testAlt >= obj.SPACE_ALTITUDE
                    higher = mid;
                else
                    lower = mid;
                end
            end

        end
    end
    
    methods (Static)
        
        function atmosphericTransmittance = getAtmosphericTransmittance(atmosphericRange,beta)
            %takes r in meters
            % but uses r in KM
            
            %satPos,threatPos) PROBLEM must determine how much of tau is through the atmosphere.
            R = atmosphericRange/1000;
            
            % betaS = 0.248; %scattering (validated by the Bar-Shalom for zero mm/hr of rainfall)
            % betaA = 0.005; %absorption
            %
            % beta = betaS+betaA;
            
            %beta=0.0223;  %This is for a clear day.  Assuming an absorption value of 0.0223;
            % beta= 0.007;
            
            atmosphericTransmittance = exp(-beta*R); %atmospheric transmissivity
            
            %greater than 100 km then outside the atmosphere and tau is
            %constant.
            
            % Note that this value cannot be grater than 2*sqrt((6378.15+100)^2-6378.15^2)*1000;
            % specify the maximum atmospheric range (tangent to the earth
            % at 100m altitude)
% %             if atmosphericRange > 2*sqrt((6378.15+100)^2-6378.15^2)*1000;
% %                 atmosphericTransmittance = publicsim.funcs.detectables.IRDetectable.getAtmosphericTransmittance(2*sqrt((6378.15+100)^2-6378.15^2)*1000,beta);
% %             end
        end
        
        function atmosphericDistanceTest()
            a = publicsim.funcs.sensors.IRSensor;
            
            % Two points out of space, no section in atmosphere
            p1High = a.EARTH.convert_lla2ecef([1 1 500e3]);
            p2High = a.EARTH.convert_lla2ecef([3 4 500e3]);
            
            aDistHigh = a.getAtmosphericDistance(p1High,p2High);
            if aDistHigh ~= 0
               error('Space obj to space obj atmospheric distance should be zero!'); 
            end
            
            % Two points in atmosphere
            p1Low = a.EARTH.convert_lla2ecef([1 1 10e3]);
            p2Low = a.EARTH.convert_lla2ecef([3 4 10e3]);
            
            aDistLow = a.getAtmosphericDistance(p1Low,p2Low);
            if aDistLow ~= norm(p1Low-p2Low)
               error('Atmospheric obj to atmospheric obj atmospheric distance should be the true distance!'); 
            end
            
            % Two points in space, but does cross the atmosphere
            p1Mid = a.EARTH.convert_lla2ecef([1 1 104e3]);
            p2Mid = a.EARTH.convert_lla2ecef([10 10 104e3]);
            
            aDistMid = a.getAtmosphericDistance(p1Mid,p2Mid);
            if abs(aDistMid-1354040) >= 5 % If we're within 5 meters, call it ok.
               error('Computation has changed significantly!'); 
            end
            
            % Two points, one in atmosphere, one out, that are also
            % directly on top of each other
            p1Low = a.EARTH.convert_lla2ecef([1, 1, 10e3]);
            p2High = a.EARTH.convert_lla2ecef([1, 1, 500e9]);
            
            aDistLH = a.getAtmosphericDistance(p1Low, p2High);
            if abs(aDistLH-90000) >=5
                error('Atmospheric distance calculation incorrect!')
            end
            
            % Two points, both outside of atmosphere, but an extension of
            % the line would intersect the atmosphere
            
            p1SpaceLow = a.EARTH.convert_lla2ecef([1, 1, 100e9]);
            p2SpaceHigh = a.EARTH.convert_lla2ecef([1, 1, 200e9]);
            aDistSpace = a.getAtmosphericDistance(p1SpaceLow, p2SpaceHigh);
            if aDistSpace ~= 0
                error('Space obj to space obj atmospheric distance should be zero!');
            end
            
            %if all those worked, the easy case had to work as well.
            disp('Passed atmospheric distance test!');
        end
        
        function IRTest()
            
            a = publicsim.funcs.sensors.IRSensor();
            a.generate3DTrack = 1;
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
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.sensors.IRSensor.IRTest';
            tests{2} = 'publicsim.funcs.sensors.IRSensor.atmosphericDistanceTest';
        end
    end
end

