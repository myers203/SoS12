classdef Thermal < publicsim.tests.UniversalTester
    %THERMAL Object that supports temperature, heating, and emmisivity
    
    properties (SetAccess = private)
        temperature; % Temperature of the object
        lastThermalUpdateTime = -inf;
    end
    
    properties (Access = private)
        emmisivity = 0.5; % emissivity coefficient, default value based off nothing
        sigma = 5.67e-8; % [W/m^2*K] Stefan-Boltzman constant
    end
    
    methods
        
        function obj = Thermal()
            % Do nothing
        end
        
        function setTemperature(obj, T, time)
            % Sets the temperature, records the time
            obj.temperature = T;
            if nargin >= 3
                obj.lastThermalUpdateTime = time;
            end
        end
        
        function T = getTemperature(obj)
            T = obj.temperature;
        end
        
        function setEmmisivity(obj, e)
            obj.emmisivity = e;
        end
        
        function q_rad = getRadiation(obj)
            % Gets the heat flux due to radiation, [W/m^2]
            q_rad = obj.emmisivity * obj.sigma * obj.temperature^4;
        end
    end
    
end

