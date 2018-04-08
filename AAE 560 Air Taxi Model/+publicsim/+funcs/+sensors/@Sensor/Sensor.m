classdef Sensor < publicsim.tests.UniversalTester
    %SENSOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=protected)
        scanPeriod=1.0; %[s]
        outputType='ECEF';
    end
    
    properties(Constant)
        SENSOR_STATUS=struct('position',[0 0 0],...
            'velocity',[0 0 0],...
            'acceleration',[0 0 0],...
            'time',0);
    end
    
    methods
        
        function obj=Sensor()
            
        end
        
        function waitTime=getNextScanTime(obj)
            waitTime=obj.scanPeriod;
        end
        
        function setScanPeriod(obj,scanPeriod)
            obj.scanPeriod=scanPeriod;
        end
        
        function setOutputType(obj,type)
            obj.outputType=type;
        end
        
        function type=getOutputType(obj)
            type=obj.outputType;
            if ~iscell(type)
                type={type};
            end
        end
        
    end
    
    methods(Abstract)
        obs=getObservations(obj,observables,sensorStatus)
        [observations, visible_ids, errors] = generateMeasurement(obj,target_array)
    end
    
    methods (Static)
        function [ids, state_array] = extractPositionInformation(observable_targets)
            state_array = nan(length(observable_targets),length(observable_targets{1}.getPosition()));
            
            ids=cell(numel(observable_targets),1);
            for i=1:numel(observable_targets)
                ids{i}=observable_targets{i}.id;
                state_array(i,:) = observable_targets{i}.getPosition();
            end
        end
    end
end

