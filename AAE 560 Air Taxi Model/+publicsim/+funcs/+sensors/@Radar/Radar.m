classdef Radar < publicsim.funcs.sensors.AzElRSensor
    
    properties (SetAccess=protected)
        %         waveform properties
        %         pulse-burst waveform section 4.5 in Radar System Performance Modeling
        %         n_pulses, n_s - number of pulses in the waveform
        %         pulse_duration, tau_s - pulse duration
        %         waveform duration, tau=tau_s*(n_s-1)
        %         frequency, frequency of radar sending waveforms, i.e. S-band
        %         radar
        %         bandwidth, B_s - bandwidth of pulse
        %         for CW pulse B_s=1/tau_s
        %         for linear FM chirp B_s=f_2-f_1
        %         wavelength = c/frequency
        %         PRT, tau_p - pulse repetition time
        %         in http://www.radartutorial.eu/08.transmitters/Intrapulse%20Modulation.en.html
        %         PCR - pulse compression ration = ratio of the range resolution of
        %         an unmodulated pulse of length tau_s to that of the modulated pulse
        %         of the same length and bandwidth B_s: PCR = B_s * tau_s
        n_pulses = 1;
        % parameters from table 5.1 in Radar System Performance Modeling
        pulse_duration = 0.001; % s or 1ms
        frequency = 3300000000; % Hz or 3.3 GHz; S-band radar
        bandwidth = 1000000; % Hz or 1 MHz
        transmit_peak_power = 20000; % W or 20 kW
        transmit_antenna_gain = 3162.3; % or 35 dB; 10^(35dB/10)=3162.3
        %       RCS = 10; % m2 or 10 dBsm; 10^(10dBsm/10)=10m2
        %       to be calculated from target
        system_noise_temperature = 293.15; % K or room temperature
        % for some reason 500K is in table
        system_losses = 5.3703; % or 7.3 dB; 10^(7.3dB/10)=5.3703
        % SNR based on this is 53.39
        beamwidth = 1; % degree
        P_FA = 1e-8;
        wavelength
    end
    
    properties (SetAccess = protected)
        % internal parameters to calculate probability of detection
        P_Dv % vector of probability of detection
        SNRv % vector of SNR
        N_swerling = 1; % number of pulses incoherently integrated
        % for swerling calculations
        % for noncoherent integration use SNR of a single pulse
        % for coherent integration N=1 and SNR is of pulse train with n_pulses
        
        swerling = 3; % swerling
        % 0 - nonfluctuating target
        % 1 - Swerling 1 slow fluctuation scan-to-scan, all scatterers are
        % similar
        % 2 - Swerling 2 fast fluctuation pulse-to-pulse, all scatterers are
        % similar
        % 3 - Swerling 3 slow fluctuation scan-to-scan, one scatterer much
        % larger than others
        % 4 - Swerling 4 fast fluctuation pulse-to-pulse, one scatterer much
        % larger than others
    end
    
    properties (Constant)
        c = 299792458; % m/s speed of light
        k = 1.3807e-23; % J/K Boltzmann’s constant
    end
    
    methods
        function obj=Radar()
            obj = obj@publicsim.funcs.sensors.AzElRSensor();
            obj.setSwerling();
        end
        
        function [observations, movableIds, errors] = ...
                getObservations(obj,observables,sensorStatus)
            [az_el_r_state_array,~,rcs_vector,ids] = obj.getLocalState(observables,sensorStatus);
            
            visible_ids = obj.getVisibleObjects(az_el_r_state_array);
            
            [obsAZELR,errorAZELR] = ...
                obj.generateMeasurement(...
                az_el_r_state_array(visible_ids,:),rcs_vector(visible_ids));
            % Removing   r_velocity(visible_ids) from input as
            % generateMeasurement can only take two inputs.
            
            
            
            [obsECEF,errorECEF] = obj.convertObservationsEcef(obsAZELR,errorAZELR,sensorStatus);
            
            %Assign outputs for visibile IDs only
            movableIds=ids(visible_ids);
            movableIds = cell2mat(movableIds);
            
            observations.AZELR = obsAZELR(visible_ids,:);
            observations.ECEF = obsECEF(visible_ids,:);
            
            errors.AZELR = errorAZELR(visible_ids,:);
            errors.ECEF = errorECEF(visible_ids,:);
            
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
        
        function [azElRState,ecef_state_array,rcs_vector,ids] = getLocalState(obj,observables,sensorStatus)
            sensorPosition=sensorStatus.position;
            obj.wavelength = obj.c/obj.frequency;
            [ids, ecef_state_array, rcs_vector] = ...
                obj.extractStateInformation(sensorPosition,observables,obj.wavelength);
            azElRState = obj.getAzElR(sensorPosition,ecef_state_array(:,1:3));  % MAY NEED TO MAKE THIS INHERIT A MOVEMENT CHARACTERISTIC
        end
        
        function visible_ids = getVisibleObjects(obj,array)
            assert(obj.azimuth_bounds(1)<=obj.azimuth_bounds(2),'Azimuth max must be greater than or equal to azimuth min!');
            assert(obj.elevation_bounds(1)<=obj.elevation_bounds(2),'Elevation max must be greater than or equal to elevation min!');
            
            in_azimuth = array(:,1) >= obj.azimuth_bounds(1) & array(:,1) <= obj.azimuth_bounds(2);
            in_elevation = array(:,2) >= obj.elevation_bounds(1) & array(:,2) <= obj.elevation_bounds(2);
            
            visible_ids = find(in_azimuth & in_elevation); % range computation is managed by p_detection and SNR for radar systems.
        end
        
        function setSwerling(obj)
            % In Fundamentals of radar signal processing by Richards, 2005
            % Detection Fundamentals p. 337
            N = obj.N_swerling;
            switch obj.swerling
                case 1
                    K = 1;
                case 2
                    K = N;
                case 3
                    K = 2;
                case 4
                    K = 2*N;
                otherwise
                    K = Inf;
            end
            if N<40
                alpha = 0;
            else
                alpha = 0.25;
            end
            d = 0.01;
            max_SNR_idx = 0.99/d;
            min_SNR_idx = 0.1/d;
            obj.SNRv = zeros(max_SNR_idx-min_SNR_idx+1,1);
            SNR_dB = zeros(max_SNR_idx-min_SNR_idx+1,1);
            obj.P_Dv = zeros(max_SNR_idx-min_SNR_idx+1,1);
            assert (obj.P_FA>0,'probability of FA<=0');
            for i=min_SNR_idx:max_SNR_idx
                P_D=i*d;
                eta = sqrt(-0.8*log(4*obj.P_FA*(1-obj.P_FA)))+...
                    sign(P_D-0.5)*sqrt(-0.8*log(4*P_D*(1-P_D)));
                X_inf = eta*(eta+2*sqrt(N/2+(alpha-0.25)));
                C1 = (((17.7006*P_D-18.4496)*P_D+14.5339)*P_D-3.525)/K;
                C2 = 1/K*(exp(27.31*P_D-25.14)+(P_D-0.8)*(0.7*log(1e-5/obj.P_FA)+...
                    (2*N-20)/80));
                if P_D<=0.872
                    C_dB = C1;
                else
                    C_dB = C1+C2;
                end
                C = 10^(C_dB/10);
                obj.P_Dv(i-min_SNR_idx+1,1) = P_D;
                obj.SNRv(i-min_SNR_idx+1,1) = C*X_inf/N;
                SNR_dB(i-min_SNR_idx+1,1) = 10*log10(obj.SNRv(i-min_SNR_idx+1,1));
            end
        end
        
        function [measurements,measurement_error] = ...
                generateMeasurement(obj,targetAzelrArray,rcsVector)
            if isempty(targetAzelrArray) || size(targetAzelrArray,1) ~= numel(rcsVector)
                measurements = [];
                measurement_error = [];
                return
            end
            
            [SNR,p_detection] = obj.getSNR(targetAzelrArray,rcsVector);
            
            angular_accuracy = obj.beamwidth./(1.6*sqrt(2*SNR));
            % 4.4 in Radar System Performance Modeling
            time_resolution = 1/obj.bandwidth;
            range_resolution = obj.c*time_resolution/2;
            % 4.5 in Radar System Performance Modeling
            
            % 8.6 in Radar System Performance Modeling
            range_accuracy = range_resolution./sqrt(2*SNR);
            
            accuracy = [angular_accuracy, angular_accuracy, range_accuracy];
            
            position_error = obj.error_distribution(size(targetAzelrArray)).*accuracy;
            position_measurements = targetAzelrArray + position_error;
            
            position_measurements = ...
                publicsim.funcs.sensors.AzElRSensor.fixMeasurementBounds(...
                position_measurements);
            
            
            
            measurements = position_measurements;
            %             measurement_error = position_error;
            measurement_error = accuracy;
            
            [ii,~]=find(isnan(accuracy)| isinf(accuracy));
            rowNumbers=unique(ii);
            measurements(rowNumbers,:)=nan;
            measurement_error(rowNumbers,:)=nan;
            
            isDetected = rand(size(p_detection))<p_detection;
            
            measurements(~isDetected,:)=nan;
            measurement_error(~isDetected,:)=nan;
            
        end
        
        function [SNR, pDetection] = getSNR(obj,targetAzelrArray,rcsVector)
            target_range = targetAzelrArray(:,3);
            assert(size(targetAzelrArray,2) == 3); %[azimuth, elevation, range]
            % 5.4 in Radar System Performance Modeling
            receive_antenna_aperture_area = obj.transmit_antenna_gain*...
                obj.wavelength^2/(4*pi);
            % 5.1 in Radar System Performance Modeling
            SNR_single_pulse = obj.transmit_peak_power*obj.pulse_duration*...
                obj.transmit_antenna_gain.*rcsVector*...
                receive_antenna_aperture_area./...
                ((4*pi)^2*target_range.^4*obj.k*...
                obj.system_noise_temperature*obj.system_losses);
            % assume coherent integration
            % 5.14 in Radar System Performance Modeling
            SNR = obj.n_pulses*SNR_single_pulse;
            % for noncoherent integration
            % 5.14 in Radar System Performance Modeling
            %SNR_NI = obj.n_pulses*SNR_single_pulse.*SNR_single_pulse./...
            %    (1+SNR_single_pulse);
            % 8.8 in Radar System Performance Modeling
            
            % Now generate detection probabilities
            pDetection = nan(size(SNR));
            pDetection(SNR>max(obj.SNRv))=max(obj.P_Dv);
            pDetection(SNR<min(obj.SNRv))=0;
            
            computeMe = find(isnan(pDetection));
            for i = 1:numel(isnan(computeMe))
                current_idx = computeMe(i);
                [~,bestIdx] = min( (SNR(current_idx)-obj.SNRv).^2 );
                pDetection(current_idx) = obj.P_Dv(bestIdx(1)); % in case one falls right in the middle.
            end
            
            
            
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
                ids{i}=observable_targets{i}.movableId;
                state_array(i,:) = [...
                    observable_targets{i}.getPosition(),...
                    observable_targets{i}.getVelocity()];
                
                
                rcs_array(i) = observable_targets{i}.getRCS( sensor_location , observable_targets{i}.getPosition(), wavelength );
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

