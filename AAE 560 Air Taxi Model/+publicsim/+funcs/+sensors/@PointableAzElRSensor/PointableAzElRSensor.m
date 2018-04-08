classdef PointableAzElRSensor < publicsim.funcs.taskers.Taskable & publicsim.funcs.sensors.AzElRSensor
    %This class is inherited by sensors for which you would like tasking
    %support.
    %   Detailed explanation goes here
    
    properties
        visitQueue={};
        sensorType
    end
    
    properties(SetAccess=protected)
        FORBounds = [-100,100,-5,80]; % Az min az max el min el max.
    end
    
    properties(Constant,Access=protected)
        VISIT_ENTRY=struct(...
            'track',[],...
            'revisit',0); % whether or not the sensor should automatically reschedule this threat.
        IR_SENSOR = 'IR'
        RF_SENSOR = 'RF'
    end
    
    
    
    methods
        function obj = PointableAzElRSensor()
        end
        
        function setSensorType(obj,type)
            assert(strcmp(type,obj.IR_SENSOR)||strcmp(type,obj.RF_SENSOR),'Unsupported sensor type!');
            obj.sensorType = type;
        end
        
        function setAzimuthBounds(obj,azimuth_bounds)
            assert(numel(azimuth_bounds)==2)
            assert(all(azimuth_bounds) >= obj.FORBounds(1),'Cannot set azimuth below FoR minimum value!');
            assert(all(azimuth_bounds) <= obj.FORBounds(2),'Cannot set azimuth above FoR maximum value!');
            
            setAzimuthBounds@publicsim.funcs.sensors.AzElRSensor(obj,azimuth_bounds);
        end
        
        function setElevationBounds(obj,elevation_bounds)
            assert(numel(elevation_bounds)==2)
            assert(all(elevation_bounds) >= obj.FORBounds(3),'Cannot set elevation below FoR minimum value!');
            assert(all(elevation_bounds) <= obj.FORBounds(4),'Cannot set elevation above FoR maximum value!');
            
            setElevationBounds@publicsim.funcs.sensors.AzElRSensor(obj,elevation_bounds);
        end
        
        function processTaskableCommand(obj,time,command) %#ok<INUSL>
            for i = 1:numel(command)
                newEntry=obj.VISIT_ENTRY;
                filter = eval([command{i}.filterType '.deserialize(command{i}.serializedTrack);']);
                newEntry.track=filter;
                newEntry.revisit=command{i}.revisit;
                obj.visitQueue{end+1}=newEntry;
            end
        end
        
        function pointToAzEl(obj,azElVector)
           assert(numel(azElVector)==2,'May only point array to single az/el pair!');
           azWidth = diff(obj.azimuth_bounds);
           elHeight = diff(obj.elevation_bounds);
           
           fovAz = [azElVector(1)-azWidth/2 azElVector(1)+azWidth/2];
           fovEl = [azElVector(2)-elHeight/2 azElVector(2)+elHeight/2];
           
           %Now do some checking on FoR.
           if fovAz(1) < obj.FORBounds(1)
               fovAz = fovAz+(obj.FORBounds(1)-fovAz(1));
           elseif fovAz(2) > obj.FORBounds(2)
               fovAz = fovAz-abs(obj.FORBounds(2)-fovAz(2));
           elseif fovEl(1) < obj.FORBounds(3)
               fovEl = fovEl+(obj.FORBounds(3)-fovEl(1));
           elseif fovEl(2) > obj.FORBounds(4)
               fovEl = fovEl-abs(obj.FORBounds(4)-fovEl(2));
           end
           
           obj.setAzimuthBounds(fovAz);
           obj.setElevationBounds(fovEl);
        end
        
        function bounds = getAzimuthBounds(obj)
            bounds = obj.azimuth_bounds;
        end
        
        function bounds = getElevationBounds(obj)
            bounds = obj.elevation_bounds;
        end
        
        function status=getTaskableStatus(obj,sensorStatus,time) 
            status.sensorStatus=sensorStatus;
            status.time=time;
            status.pointingAngle = [mean(obj.azimuth_bounds),mean(obj.elevation_bounds)];
            status.azWidth = diff(obj.azimuth_bounds);
            status.elHeight = diff(obj.elevation_bounds);
            status.FORBounds = obj.FORBounds;
            status.sensorType = obj.sensorType;
            
            if strcmp(obj.sensorType,'RF_SENSOR')
                status.maxQueueSize=obj.maximumQueueSize;
                status.currentQueueSize=numel(obj.visitQueue);
            end
        end
    end
    
    methods (Abstract)
        updatePointingAngle(obj,time,sensorStatus)
    end
    
%     methods (Static,Access=private)
%         
%         function addPropertyLogs(obj)
%             obj.addPeriodicLogItems({'getAzimuthBounds','getElevationBounds'});
%         end
%         
%     end
end

