classdef IRDetectable < handle
        
    properties (SetAccess = private)
        irradiance
        plumeSize % might not need this here.
        intensityProfile
    end
    
    properties (Constant) % default constant values.
        INTENSITY_ALTITUDES    = [0 5 10 20 30 40 50 55 60 62 65 70 80 90 95 100 110 120 130 140 150]*1e3;
        INTENSITY_COEFFS       = [4 5.301029996 6 6.397940009 6.447158031 6.243038049 5.698970004 5 4.397940009 4.176091259 4 3.954242509 3.942008053 4 4.301029996 5 5.477121255 5.698970004 5.77815125 5.954242509 6]
        INTENSITY_VACUUM_LIMIT = 3;
        INTENSITY_TAPER_TIME = 20; %time that stage irradiance intensity tapers off i.e. slowly burns out after ejection (s)
    end
    
    methods
        function obj = IRDetectable()
            obj.intensityProfile=pchip(obj.INTENSITY_ALTITUDES,...
                obj.INTENSITY_COEFFS); %Profile of intensity with altitude based on standard atmosphere.
        end
        
        function v = getIrradiance(obj)
           obj.updateIrradiance();
           v = obj.irradiance();
        end
        
        function setIrradiance(obj,currentIrradiance)
            assert(isnumeric(currentIrradiance) && numel(currentIrradiance)==1);
            obj.irradiance = currentIrradiance;
        end
        
        % for thrusting bodies
        function irradiance = computeIrradiance(obj,altitude,thrust)
            
            if altitude > obj.intensityProfile.breaks(end)
                coeff = obj.INTENSITY_VACUUM_LIMIT;
            else
                coeff = ppval( obj.intensityProfile,altitude);
            end
            irradiance = (10^coeff)*(thrust/1e6);
        end
        
        function updateIrradiance(obj) %#ok<MANU>
            %Update using setIrradiance; left as non-abstract until
            %development completed
        end
        
    end
    
    methods (Abstract)
        %updateIrradiance(obj) % this should update the value of obj.irradiance using the setIrradiance function.
    end
   
end

