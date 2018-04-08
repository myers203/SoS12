classdef TaskableMultiPoint < publicsim.funcs.sensors.PointableAzElRSensor
    
    properties(SetAccess=protected)
        visitsPerSecond=5
        maximumQueueSize=30
    end
    
    methods
        
        function obj=TaskableMultiPoint()
            obj.azimuth_bounds = [-1,0];
            obj.elevation_bounds = [-1,0];
            obj.range_bounds = [0,inf]; % not enforcing range bounds for now.
            obj.setSensorType(obj.RF_SENSOR);
        end
        
        function waitTime=getNextScanTime(obj)
            waitTime=1/obj.visitsPerSecond;
        end
        
        function updatePointingAngle(obj,time,sensorStatus)
            %TODO If IR sensor, point to a particular angle, if PAR, cycle
            %through the list.
            if isempty(obj.visitQueue)
                return;
            end
            
            target=obj.visitQueue{1};
            obj.visitQueue(1)=[];
            if target.revisit==1
                obj.visitQueue{end+1}=target;
            end
            targetEcef=target.track.getPositionAtTime(time);
            pointingAzElR=obj.getAzElR(sensorStatus.position,targetEcef(1:3)');
            obj.pointToAzEl(pointingAzElR(1:2));
        end
        
    end
    
end

