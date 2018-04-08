classdef Fuser < handle
   
    properties
        trackMap
        trackerType='publicsim.funcs.trackers.BasicKalman(9)';
        fusedTrack
    end
    
    methods
        function obj=Fuser(trackerType)
            if nargin >= 1 && ~isempty(trackerType)
                obj.trackerType=trackerType;
            end
            obj.trackMap=containers.Map('KeyType','int64','ValueType','any');
            obj.fusedTrack=eval(obj.trackerType);
        end
        
        function updateTrack(obj,sourceId,track)
            obj.trackMap(sourceId)=track;
        end
        
        function [x,P]=getFusedState(obj,time)
            obj.fuseTracks(time);
            [x,P]=obj.fusedTrack.getPositionAtTime(time);
        end
        
        function [x,P]=getCurrentState(obj,time)
            %obj.fuseTracks(time);
            [x,P]=obj.fusedTrack.getPositionAtTime(time);
        end
        
    end
    
    methods(Abstract)
        fuseTracks(obj,time)
    end
end

