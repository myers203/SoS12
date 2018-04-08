classdef TaskableIR < publicsim.funcs.sensors.PointableAzElRSensor & publicsim.funcs.sensors.IRSensor

    properties
        lookPeriod = 1; % go look every 1 second.
    end
    
    methods
        
        function obj=TaskableIR()
            obj.azimuth_bounds = [-5,0];
            obj.elevation_bounds = [-5,0];
            obj.range_bounds = [0,inf]; % not enforcing range bounds for now.
            obj.setSensorType(obj.IR_SENSOR);
        end
        
        function waitTime=getNextScanTime(obj)
            waitTime=obj.lookPeriod;
        end
        
        function updatePointingAngle(obj,time,sensorStatus)
            if isempty(obj.visitQueue)
                return;
            end
            pointingDirections = nan(0,3);
            for i = numel(obj.visitQueue):-1:1 % Going backwards so we can delete them as we go
                currentTarget=obj.visitQueue{i};
                obj.visitQueue(i)=[];
                if currentTarget.revisit==1
                    obj.visitQueue{end+1}=currentTarget;
                end
                targetEcef=currentTarget.track.getPositionAtTime(time);
                pointingAzElR=obj.getAzElR(sensorStatus.position,targetEcef(1:3)');
                pointingDirections(i,:) = pointingAzElR;
            end
            
            %TODO: do smart recentering here based on visible targets.
            %This should also appear in the constraints for the tasker.
            
            centerPoint = mean(pointingDirections);
            
            obj.pointToAzEl(centerPoint(1:2));
        end
        
    end
    
end

