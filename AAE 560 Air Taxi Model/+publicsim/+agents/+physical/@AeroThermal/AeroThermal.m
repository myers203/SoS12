classdef AeroThermal < publicsim.agents.physical.Thermal & publicsim.agents.physical.Worldly
    %AEROTHERMAL Supports basic conical aerodynamic heating
    
    properties (Access = private)
        coneAngle; % [rad] Angle of the cone (NOT the half angle)
        coneLength; % [m] Length of the cone
        coneRadius; % [m] Radius of the nose of the cone
        coneArea; % [m^2] Approximate area of the cone
        heatCapacity; % [J/m^2*K] Heat capacity of the object
    end
    
    properties (Access = private, Constant)
        RE_SWITCH = 1e6; % Reynolds number transition point between laminar and turbulent flow
        gamma = 1.4; % Assume constant gamma for air
    end
    
    methods
        
        function obj = AeroThermal()
            % Run super constructor
            obj@publicsim.agents.physical.Thermal();
            obj.setTemperature(293); % Set initial temperature to STP
        end
        
        function setCone(obj, angle, length, radius)
            % Sets the cone parameters
            obj.coneAngle = angle;
            obj.coneLength = length;
            obj.coneRadius = radius;
            rad = length * tan(angle / 2);
            
            obj.coneArea = pi * rad * (rad + sqrt(length^2 + rad^2));
        end
        
        function setHeatCapacity(obj, G)
            % Set the cone heat capacity
            obj.heatCapacity = G;
        end
        
        function thermalRunAtTime(obj, time)
            % Update temperature over time
            
            % Get local air properties
            lla = obj.world.convert_ecef2lla(obj.spatial.position);
            [T, ~, ~, a] = publicsim.funcs.aero.atmosphere(lla(3));
            
            if norm(obj.spatial.velocity) == 0
                % Ignore if no velocity or effectively outside the
                % atmosphere
                obj.setTemperature(obj.temperature, time);
                return;
            end
            
            % Find out how much time has gone by
            dt = time - obj.lastThermalUpdateTime;
            % Treat 80 km as the cutoff for convective heating
            if lla(3) < 8e4
                T = T + 273; % Convert to K
                M0 = norm(obj.spatial.velocity) / a;
                [~, T_rat, ~, ~, ~] = flowisentropic(obj.gamma, M0, 'mach');
                T_stag = T / T_rat; % Stagnation temperature
                K = obj.calcRecoveryFactor();
                T_bl = K * (T_stag - T) * K + T; % Boundary layer temperature
                
                
                % Get some parameters
                Re = obj.calcReynoldsNumber(norm(obj.spatial.velocity), T);
                Pr = publicsim.funcs.aero.getPrandtlNumber(T);
                Nu = obj.calcNusseltNumber(Re, Pr);
                h = obj.calcHeatTransferCoefficient(M0, norm(obj.spatial.velocity), Nu, T_bl);
                % Make a smooth transfer to no atmospheric heating
                if lla(3) >= 0
                    % This smoothing function has no source, it's just
                    % something to smooth out heating
                    s = 0.5 * tanh((lla(3) - 7.6e4) / 1.2e3) + 0.5;
                    h = (1 - s) * h; 
                end
            else
                % Outside of atmosphere, get rid heat transfer from the
                % air
                h = 0;
                T_bl = obj.temperature;
            end
            
            max_dt = 0.1;
            currTime = 0;
            % Need to slow down integration at high temperatures due to
            % fourth order radiation terms
            while currTime < dt
                % Instantaneous rate of temperature change (sort of)
                dT_dt = (h * (T_bl - obj.temperature) - obj.getRadiation()) / obj.heatCapacity;
                % Simple integration to get new temperature
                tStep = min(max_dt, dt - currTime);
                newT = obj.temperature + dT_dt * tStep;
                currTime = currTime + tStep;
                
                if isnan(newT) || isinf(newT) || newT < 0
                    keyboard;
                end
                % Set the new temperature
                obj.setTemperature(newT, obj.lastThermalUpdateTime + tStep);
            end
            
            
        end
    end
    
    methods (Access = private)
        
        function K = calcRecoveryFactor(obj)
            if rad2deg(obj.coneAngle) > 40
                K = 0.89 + 0.001 * (rad2deg(obj.coneAngle) - 40);
            else
                K = 0.89;
            end
        end
        
        function Re = calcReynoldsNumber(obj, u0, T)
            % Calculates the Reynolds number
            % Inputs:
            % u0: Velocity of the flow [m/s]
            % T: Static temperature of the flow [K]
            % Outputs:
            % Re: Reynolds number
            nu = publicsim.funcs.aero.getKinematicViscosity(T);
            Re = (u0 * obj.coneLength) / nu;
        end
        
        function Nu = calcNusseltNumber(obj, Re, Pr)
            % Calculates the Nusselt number of the cone flow
            % Inputs:
            % Re: Reynolds number
            % Pr: Prandtl number
            
            if Re > obj.RE_SWITCH
                % Turbulent flow
                Nu_flat = 0.037 * Re^0.8 * Pr^(1/3);
            else
                % Laminar flow
                Nu_flat = 0.64 * sqrt(Re) * Pr^(1/3);
            end
            
            % Account for shape effects
            Nu = Nu_flat * sqrt(0.0058 * obj.coneAngle + 0.13 + 0.12 * exp(-0.07 * obj.coneAngle));
        end
        
        function h = calcHeatTransferCoefficient(obj, M0, u0, Nu, T)
            % Calculates the heat transfer coefficient
            % Inputs
            % M0: Free stream mach
            % Re: Reynolds number
            % u0: Free stream velocity [m/s]
            % Nu: Nusselt number
            % T: Recovered temperature of air [K]
            % Outputs:
            % h: Heat transfer coefficient [W/m^2*K]
            
            if M0 > 1
                [~, ~, ~, ~, M] = flownormalshock(obj.gamma, M0);
            else
                M = M0;
            end
            
            % Get the speed of sound
            a = sqrt(obj.gamma * 287.058 * T);
            
            C = 3 * (u0 / (obj.coneRadius * 2)) * (1 - 0.252 * M^2 - 0.0175 * M^4);
            T = min(T, 1400); % Limit to valid interpolation along curves
            k = publicsim.funcs.aero.getThermalConductivity(max(T, 1400));
            nu_sk = publicsim.funcs.aero.getKinematicViscosity(T);
            Re_sk = obj.calcReynoldsNumber(M * a, T);
            
            h = (k / sqrt(nu_sk)) * (Nu / sqrt(Re_sk)) * sqrt(C);
        end
    end
    
    methods (Static, Access = private)
        function addPropertyLogs(obj)
            % Adds periodic log of temperature
            obj.addPeriodicLogItems({'getTemperature'});
            if isa(obj, 'publicsim.funcs.detectables.IRDetectable')
                obj.addPeriodicLogItems({'getIrradiance'});
            end
        end
    end
    
end

