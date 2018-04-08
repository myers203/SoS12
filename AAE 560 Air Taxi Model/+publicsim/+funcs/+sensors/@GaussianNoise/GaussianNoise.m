classdef GaussianNoise < publicsim.funcs.sensors.Sensor
    %GAUSSIANNOISE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        positionError=1;
    end
    
    methods
        
        function obj=GaussianNoise()
            obj.setOutputType('ECEF');
        end
        
        function [observations, visible_ids, errors]=getObservations(obj,observables,sensorStatus) %#ok<INUSD>
            observations.ECEF=nan(numel(observables),3);
            visible_ids=nan(numel(observables),1);
            errors.ECEF=nan(numel(observables),3);
            for i=1:numel(observables)
                observations.ECEF(i,:)=observables{i}.getPosition()+randn(1,3)*obj.positionError;
                visible_ids(i)=observables{i}.movableId;
                errors.ECEF(i,:)=ones(1,3)*obj.positionError;
            end
            
        end
        
        function [measurements,errors] = generateMeasurement(obj,target_array) %#ok<INUSD>
            measurements=[];
            errors=[];
        end
    end
    
end

