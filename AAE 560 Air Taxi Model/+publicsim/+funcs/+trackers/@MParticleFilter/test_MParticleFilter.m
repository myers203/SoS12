        %publicsim.funcs.trackers.MParticleFilter.test_MParticleFilter

        function test_MParticleFilter()
            earth_type = 'elliptical';
            earth = publicsim.util.Earth();
            earth.setModel(earth_type);
            center_ecef = [0,0,earth.getRadius()];
            times = csvread('./+publicsim/+funcs/+trackers/@MParticleFilter/trajtime.csv');
            trajECEFo = csvread('./+publicsim/+funcs/+trackers/@MParticleFilter/trajECEF.csv')';
            trajevECEFo = csvread('./+publicsim/+funcs/+trackers/@MParticleFilter/trajevECEF.csv')';
            startObs = 1;
            endObs = 5000;
            trajECEF = trajECEFo(:,startObs:endObs);
            trajevECEF = trajevECEFo(:,startObs:endObs);
            times = times(startObs:endObs) - times(startObs);
            numObs = endObs - startObs + 1 - 2;
            sensorPosition = center_ecef';
            numStates = 9;
            numParticles = 10000;
            numMeasurementStates = 3;
            if numMeasurementStates==3
                measurementNoise = [0.5 0.5 100];
            else
                measurementNoise = [0.05 0.05 1 1];
            end
            MParticleFilter = publicsim.funcs.trackers.MParticleFilter(numStates,...
                numMeasurementStates,numParticles, earth_type);
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
                trueObservations(:,i) = MParticleFilter.cart2azelr(xyz,sensorPosition);
            end                      
            observations = zeros(numMeasurementStates,numObs);
            for i=1:numObs
                observations(:,i) = ...
                    publicsim.funcs.trackers.MParticleFilter.add_meas_err(...
                    trueObservations(:,i),measurementNoise);
            end
            groundTruth = false;
            if groundTruth
                x=trueState(:,1);  
                MParticleFilter.initByState(x,...
                    MParticleFilter.buildProcessNoise(0.1),times(1)); 
            else
                pos = MParticleFilter.azelr2cart(observations(:,1),sensorPosition);
                if numMeasurementStates==3
                    x = [pos; 0; 0; 0; 0; 0; 0];
                else
                    x = [pos; 0; 0; 0];
                end
                obsData = struct('time',times(1),'measurements',observations(:,1),...
                    'errors',measurementNoise,'sensorPosition',sensorPosition,...
                    'trueId',1);
                MParticleFilter.initByObs(obsData);
            end
            stateHistory = zeros(numStates,numObs);
            PHistory = zeros(numStates,numStates,numObs);
            stateHistory(:,1) = x;
            for k=2:numObs
                obsData = struct('time',times(k),'measurements',observations(:,k),...
                    'errors',measurementNoise,'sensorPosition',sensorPosition,...
                    'trueId',1);
                [x,P]=MParticleFilter.addObservation(obsData);
                stateHistory(:,k) = x(1:numStates);                            
                PHistory(:,:,k) = P(1:numStates,1:numStates);                            
            end
            for k=1:3                                 
              subplot(3,1,k)
              plot(1:numObs, trueState(k,:), '-', 1:numObs, stateHistory(k,:), '--')
            end 
            poserr=zeros(numObs,1);
            for i=1:numObs
                poserr(i,1)=sqrt(sum((stateHistory(1:3,i)-trueState(1:3,i)).^2));
            end
            figure;
            plot(poserr,'b');
            xlabel('Time (sec)')
            ylabel('Position Error (m/s)')
            velerr=zeros(numObs,1);
            for i=1:numObs
                velerr(i,1)=sqrt(sum((stateHistory(4:6,i)-trueState(4:6,i)).^2));
            end
            figure;
            plot(velerr,'b');
            xlabel('Time (sec)')
            ylabel('Velocity Error (m/s)')
            Perr=zeros(numObs,1);
            for i=1:numObs
                Perr(i,1)=sqrt(det(PHistory(1:3,1:3,i)));
            end
            figure;
            plot(Perr,'b');
            xlabel('Time (sec)')
            ylabel('Square root of position covariance determinat (m)')
        end