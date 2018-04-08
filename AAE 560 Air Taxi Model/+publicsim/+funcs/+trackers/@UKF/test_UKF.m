        %publicsim.funcs.trackers.UKF.test_UKF
        function test_UKF()
            numStates = 9;
            numMeasurementStates = 3;
            ukf = publicsim.funcs.trackers.UKF(numStates,numMeasurementStates);
            test_tracker(ukf,numStates,numMeasurementStates);
        end
        function test_tracker(ukf,numStates,numMeasurementStates)
            earth_type = 'elliptical';
            earth = publicsim.util.Earth();
            earth.setModel(earth_type);
            times = csvread('./+publicsim/+funcs/+trackers/@MParticleFilter/trajtime.csv');
            trajECEFo = csvread('./+publicsim/+funcs/+trackers/@MParticleFilter/trajECEF.csv')';
            trajevECEFo = csvread('./+publicsim/+funcs/+trackers/@MParticleFilter/trajevECEF.csv')';
            startObs = 1;
            endObs = 5000;
            trajECEF = trajECEFo(:,startObs:endObs);
            trajevECEF = trajevECEFo(:,startObs:endObs);
            times = times(startObs:endObs) - times(startObs);
            numObs = endObs - startObs + 1 - 1;
            limitObs = 1:numObs;
            xSensorPos = trajECEF(1,floor(endObs/2))-1000;
            ySensorPos = trajECEF(2,floor(endObs/2))-1000;
            sensorPosition = [xSensorPos;ySensorPos;...
                sqrt(earth.getRadius()^2-xSensorPos^2-ySensorPos^2)];
            IRsensorPosition = sensorPosition;
            IRmeasurementNoise = [0.001 0.001];
            if numMeasurementStates==3
                measurementNoise = [0.05 0.05 1];
            else
                measurementNoise = [0.05 0.05 1 1];
            end
            trueObservations = zeros(numMeasurementStates,numObs);
            trueState = zeros(numStates,numObs);
            for i = 1:numObs
                t0 = times(i);
                t1 = times(i+1);
                trueState(1:3,i) = trajECEF(:,i);
                trueState(4:6,i) = trajevECEF(:,i);
                trueState(7:9,i) = (trajevECEF(:,i+1)-trajevECEF(:,i))/(t1-t0);
                if numMeasurementStates==3
                    xyz = trueState(1:3,i);
                else
                    xyz = trueState(1:6,i);
                end
                trueObservations(:,i) = ukf.cart2azelr(xyz,sensorPosition);
            end                      
            observations = zeros(numMeasurementStates,numObs);
            IRobservations = zeros(2,numObs);
            posvel = zeros(6,numObs);
            for i=1:numObs
                observations(:,i) = ...
                    publicsim.funcs.trackers.UKF.add_meas_err(...
                    trueObservations(:,i),measurementNoise);
                IRobservations(:,i) = ...
                    publicsim.funcs.trackers.UKF.add_meas_err(...
                    trueObservations(1:2,i),IRmeasurementNoise);
                tmpPos = ukf.azelr2cart(observations(:,i),sensorPosition);
                if numMeasurementStates==3
                    posvel(1:3,i)=tmpPos;
                else
                    posvel(1:6,i)=tmpPos;
                end
            end
            % acceleration profile
            acc=zeros(numObs,1);
            for i=1:numObs
                acc(i,1)=sqrt(sum(trueState(7:9,i).^2));
            end
            figure;
            plot(times(limitObs),acc,'b');
            xlabel('Time (sec)')
            ylabel('Acceleration (m/s^2)'); 
            % figure in ECEF
            figure;
            plot3(trueState(1,limitObs),trueState(2,limitObs),...
                trueState(3,limitObs),'b');
            hold on;
            scatter3(posvel(1,limitObs),posvel(2,limitObs),...
                posvel(3,limitObs),'r*');
            hold on;
            plot3(sensorPosition(1,1),sensorPosition(2,1),...
                sensorPosition(3,1),'gX');
            % figure in lat lon
            trueState_lla = earth.convert_ecef2lla(trueState(1:3,:)')';
            posvel_lla = earth.convert_ecef2lla(posvel(1:3,:)')';
            sensorPosition_lla = earth.convert_ecef2lla(sensorPosition')';
            figure;
            scatter3(posvel_lla(2,limitObs),posvel_lla(1,limitObs),...
                posvel_lla(3,limitObs),'r*');
            hold on;
            plot3(trueState_lla(2,limitObs),trueState_lla(1,limitObs),...
                trueState_lla(3,limitObs),'bo');
            hold on;
            plot3(sensorPosition_lla(2,1),sensorPosition_lla(1,1),...
                sensorPosition_lla(3,1),'gX');            
            xlabel('Lattitude (deg)');
            ylabel('Longitude (deg)');
            zlabel('Altitude (m)');
            groundTruth = false;
            if groundTruth
                x=trueState(:,1);  
                ukf.initByState(x,eye(numStates),times(1)); 
            else
                pos = ukf.azelr2cart(observations(:,1),sensorPosition);
                if numMeasurementStates==3
                    x = [pos; 0; 0; 0; 0; 0; 0];
                else
                    x = [pos; 0; 0; 0];
                end
                obsData = struct('time',times(1),'measurements',observations(:,1),...
                    'errors',measurementNoise,'sensorPosition',sensorPosition,...
                    'trueId',1);
                ukf.initByObs(obsData);
            end
            stateHistory = zeros(numStates,numObs);
            PHistory = zeros(numStates,numStates,numObs);
            stateHistory(:,1) = x;
            for k=2:numObs
                obsData = struct('time',times(k),'measurements',observations(:,k),...
                    'errors',measurementNoise,'sensorPosition',sensorPosition,...
                    'trueId',1);
                IRobsData = struct('time',times(k),'measurements',IRobservations(:,k),...
                    'errors',IRmeasurementNoise,'sensorPosition',IRsensorPosition,...
                    'trueId',2);
                if times(k)>94.8
                    % switch to ballistic
                    ukf.processDynamics = 2;
                end
                [x,P]=ukf.addObservation(obsData);
                if times(k)<=94.8
                    [x,P]=ukf.addObservation(IRobsData);
                end
                stateHistory(:,k) = x(1:numStates);                            
                PHistory(:,:,k) = P(1:numStates,1:numStates);                            
            end
            figure;
            for k=1:3                                 
                subplot(3,1,k)
                plot(times(1:numObs), trueState(k,:), '-', times(1:numObs), ...
                    stateHistory(k,:), '--')
                xlabel('Time (sec)')
                if k==1 ylabel('x (m)'); end
                if k==2 ylabel('y (m)'); end
                if k==3 ylabel('z (m)'); end
            end 
            figure;
            for k=4:6                                 
                subplot(3,1,k-3)
                plot(times(1:numObs), trueState(k,:), '-', times(1:numObs), ...
                    stateHistory(k,:), '--')
                xlabel('Time (sec)')
                if k==4 ylabel('vx (m/s)'); end
                if k==5 ylabel('vy (m/s)'); end
                if k==6 ylabel('vz (m/s)'); end
            end
            figure;
            for k=7:9                                 
                subplot(3,1,k-6)
                plot(times(1:numObs), trueState(k,:), '-', times(1:numObs), ...
                    stateHistory(k,:), '--')
                xlabel('Time (sec)')
                if k==7 ylabel('ax (m/s2)'); end
                if k==8 ylabel('ay (m/s2)'); end
                if k==9 ylabel('az (m/s2)'); end
            end
            poserr=zeros(numObs,1);
            for i=1:numObs
                poserr(i,1)=sqrt(sum((stateHistory(1:3,i)-trueState(1:3,i)).^2));
            end
            figure;
            plot(times(1:numObs), poserr, 'b');
            xlabel('Time (sec)')
            ylabel('Position Error (m)')
            velerr=zeros(numObs,1);
            for i=1:numObs
                velerr(i,1)=sqrt(sum((stateHistory(4:6,i)-trueState(4:6,i)).^2));
            end
            figure;
            plot(times(1:numObs), velerr, 'b');
            xlabel('Time (sec)')
            ylabel('Velocity Error (m/s)')
            Perr=zeros(numObs,1);
            for i=1:numObs
                Perr(i,1)=sqrt(det(PHistory(1:3,1:3,i)));
            end
            figure;
            plot(times(1:numObs), Perr, 'b');
            xlabel('Time (sec)')
            ylabel('Square root of position covariance determinat (m)')
        end