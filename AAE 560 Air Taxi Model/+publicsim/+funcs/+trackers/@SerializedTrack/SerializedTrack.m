classdef SerializedTrack < handle
    
    properties
        serializedTrack
        serializedTrackType
    end
    
    methods
        function obj=SerializedTrack(track)
            obj.serializedTrack=track.serialize();
            obj.serializedTrackType=class(track);
        end
        
        function track=getTrack(obj)
            track=eval([obj.serializedTrackType '.deserialize(obj.serializedTrack);']);
        end
        
    end
    
end

