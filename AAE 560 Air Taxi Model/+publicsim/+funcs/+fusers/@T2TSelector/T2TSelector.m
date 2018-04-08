classdef T2TSelector < publicsim.funcs.fusers.Fuser
    %T2TSELECTOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
%         function obj=T2TSelector(fuserType)
%              obj=obj@publicsim.funcs.fusers.Fuser(fuserType);
%          end
        
        function fuseTracks(obj,time)
            allTracks=values(obj.trackMap);
            covErrors=zeros(numel(allTracks),1);
            for i=1:numel(allTracks)
                track=allTracks{i};
                [covErrors(i)]=track.getPositionErrorAtTime(time);
            end
            
            [~,idx]=sort(covErrors);
            obj.fusedTrack=allTracks{idx(1)};
        end
    end
    
end

