classdef T2TFwoMnf < publicsim.funcs.fusers.Fuser
    
    properties
    end
    
    methods
        
        function obj=T2TFwoMnf(fuserType)
            if nargin < 1
                fuserType='publicsim.funcs.trackers.BasicKalman(9)';
            end
            obj=obj@publicsim.funcs.fusers.Fuser(fuserType);
        end
        
        function fuseTracks(obj,~)
            allTracks=values(obj.trackMap);
            if numel(allTracks)==1
                track=allTracks{1};
                t=track.t;
                x0=track.x;
                P0=track.P;
                obj.fusedTrack.initByState(x0,P0,t);
            else
                times=zeros(numel(allTracks),1);
                for i=1:numel(allTracks)
                    track=allTracks{i};
                    times(i)=track.t;
                end
                [~,idx]=sort(times);
                allTracks=allTracks(idx);
                
                %fuse two tracks
                lastTrack=allTracks{1};
                for i=2:numel(allTracks)
                    nextTrack=allTracks{i};
                    [xi,Pi]=lastTrack.getPositionAtTime(nextTrack.t);
                    xj=nextTrack.x;
                    Pj=nextTrack.P;
                    [x,P]=obj.calcFusedTrack(xi,xj,Pi,Pj);
                    obj.fusedTrack.initByState(x,P,nextTrack.t);
                    lastTrack=obj.fusedTrack;
                end
            end
        end
        
    end
    
    methods(Static)
        function [x,P]=calcFusedTrack(xi,xj,Pi,Pj)
            warning('off','MATLAB:nearlySingularMatrix');
            x=Pj/(Pi+Pj)*xi+...
                Pi/(Pi+Pj)*xj;
            P=Pi/(Pi+Pj)*Pj;
            warning('on','MATLAB:nearlySingularMatrix');
        end
    end
    
end

