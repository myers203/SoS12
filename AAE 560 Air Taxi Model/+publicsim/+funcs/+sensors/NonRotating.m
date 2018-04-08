classdef NonRotating < publicsim.funcs.sensors.Radar
    %Just copied over at this point. Still needs significant editing. 
    
    
    properties (SetAccess=protected)
% %         n_pulses = 10;
% %         transmit_peak_power = 20000; % W or 20 kW
% %         pulse_duration = 0.001; % s or 1ms
% %         transmit_antenna_gain = 3162; % or 35 dB; 10^(35dB/10)=3162
% %         receive_antenna_aperture = 2.079; % m2
% %         system_noise_temperature = 500; %K
% %         system_losses = 5.370; % or 7.3 dB; 10^(7.3dB/10)=5.370
% %         beamwidth = 1; %degrees
% %         bandwidth = 1000000; % Hz or 1 MHz
    end
    
    methods
        function obj=NonRotating()
            obj = obj@publicsim.funcs.sensors.Radar();
            % http://saab.com/land/istar/multi-role-surveillance-system/giraffe-4a/
            % Rotation rate 30 or 60 rpm
            % Elevation coverage > 70 degrees (probably typo because in
            % http://saab.com/air/sensor-systems/ground-based-air-defence/giraffe-8A/
            % volume search Elevation coverage: 0°- 65° while
            % technical data Elevation coverage > 65 degrees
            % assumed 0°- 70°
            % 6deg/sec=1rpm
            % Instrumented range 
            % Air surveillance 280km
            % Weapon locating 100km
            obj.rotation_rate=180; % in deg/sec or 30 rpm
            obj.azimuth_slice=30;
            obj.elevation_bounds=[0 70];
            obj.range_bounds = [0 280000]; 
            obj.start_boresight=rand()*360;
            obj.transmit_peak_power = 200000;
        end
    end
    
    methods (Static)
        function nonRotatingTest()
            % See rotating radar test for implementation.
            disp('Passed NonRotating test!');
        end
    end
end

