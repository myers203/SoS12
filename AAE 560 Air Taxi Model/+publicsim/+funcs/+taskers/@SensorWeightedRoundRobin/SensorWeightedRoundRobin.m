classdef SensorWeightedRoundRobin < publicsim.funcs.taskers.Tasker & publicsim.funcs.schedulers.WeightedRoundRobin
    %SENSORWEIGHTEDROUNDROBIN Used by a class inheriting from the
    %publicsim.agents.functional.Tasking class.
    
    properties
        assetMap
        targetProperties
        earth
        scheduleLength = 5
    end
    
    properties(Access=private)
       constraintWarningLatch = true; 
    end
    
    properties (Constant)
        ASSET_PROPERTIES = struct('position',[],'lastPointingAngle',[],'azWidth',[],'elHeight',[],'FORBounds',[]);
        TARGET_PROPERTY_LIST = struct('id',[],'priority',[],'filter',[]);
        COMMAND = struct('serializedTrack',[],'revisit',[],'filterType',[]);
    end
    
    methods
        function obj=SensorWeightedRoundRobin()
            obj.assetMap = containers.Map('ValueType','any','KeyType','double');
            obj.earth = publicsim.util.Earth();
            obj.earth.setModel('Elliptical');
        end
        
        function addNewAssessments(obj,ids,priorities,otherData)
            if ~isempty(ids)
                % Let's assume, for now, that the assessor is smarter than
                % the tasker.  I.e., it will manage the list of assets to
                % track and we'll assume that's properly updated each time
                % step.
                obj.targetProperties = obj.TARGET_PROPERTY_LIST;
                for i = 1:numel(ids)
                    obj.targetProperties(i).id = ids(i);
                    obj.targetProperties(i).priority = priorities(i);
                    
                    filter = eval([otherData.trackTypes{i} '.deserialize(otherData.serializedTracks{i});']);
                    obj.targetProperties(i).filter = filter;
                end
                
            end
        end
        
        function addTaskableAsset(obj,time,id,otherData)
            if isempty(time)
                return
            end
            % Just add every asset as if you've never seen it before.
            newEntry = obj.ASSET_PROPERTIES;
            newEntry.position = otherData.sensorStatus.position;
            newEntry.lastPointingAngle = otherData.pointingAngle;
            newEntry.azWidth = otherData.azWidth;
            newEntry.elHeight = otherData.elHeight;
            newEntry.FORBounds = otherData.FORBounds;
            newEntry.sensorType = otherData.sensorType;
            obj.assetMap(id) = newEntry; % this will overwrite any old saved assets with new info.
        end
        
        function [commands,ids]=getTasking(obj,time)
            if isempty(obj.targetProperties) || isempty(obj.assetMap)
                commands = [];
                ids = [];
                return
            end
            
            targetLLAs = obj.propagateTargets(time);
            
            priorities = [obj.targetProperties.priority];
            scheduleIndices = obj.getSchedule(priorities,obj.scheduleLength);
            
            %TODO add pointing validaton (in below commented logic) to make
            %sure of which assets can see which tracks and that they can
            %all either be in a field of view (IR sensors) or that the list
            %is less than the maximum queue size (PAR).  Will also want to
            %set revisit to true when the list length is less than the
            %queue size (PAR) or constantly on for the IR sensors.
            
            if obj.constraintWarningLatch
                warning('Tasker does not include constraint checking!');
                obj.constraintWarningLatch = false;
            end
            
            assetKeys = cell2mat(obj.assetMap.keys);
            
            ids = nan(1,numel(assetKeys));
            commands = cell(1,numel(ids));
            
            for j=1:numel(assetKeys)
                commandIndices = scheduleIndices; 
                
                assetType = obj.assetMap(assetKeys(j)).sensorType; %#ok<NASGU>
                %TODO do some smart selection of commands to assets that
                %includes error checking.
                commandList = cell(1,numel(commandIndices));
                for i = 1:numel(commandIndices)
                    nextIndex = commandIndices(i); % this is the index with the next highest priority
                    newCommand = obj.COMMAND;
                    newCommand.serializedTrack = obj.targetProperties(nextIndex).filter.serialize();
                    newCommand.revisit = 1;
                    newCommand.filterType = class(obj.targetProperties(nextIndex).filter);
                    commandList{i} = newCommand;
                end
                commands{j} = commandList;
                ids(j) = assetKeys(j);
            end
            
            deleteMe = isnan(ids);
            ids(deleteMe) =[];
            commands(deleteMe) = [];
        end
        
        function targetLLAs = propagateTargets(obj,time)
            nTargets = numel(obj.targetProperties);
            targetLLAs = nan(nTargets,3);
            for i = nTargets
                position = obj.targetProperties(i).filter.getPositionAtTime(time);
                targetLLAs(i,:)=obj.earth.convert_ecef2lla(position(1:3)');
            end
        end
        
        function targetAzElR = getAzElR(obj,sensorIdx,targetLLAs)
            sensorLLA = obj.earth.convert_ecef2lla(obj.assetMap(sensorIdx).position);
            
            targetAzElR = nan(size(targetLLAs));
            for i = 1:size(targetLLAs,1)
                [targetAzElR(i,1), targetAzElR(i,2), targetAzElR(i,3)] = obj.earth.convert_lla2azelr(sensorLLA,targetLLAs(i,:));
            end
        end
    end
    
end

