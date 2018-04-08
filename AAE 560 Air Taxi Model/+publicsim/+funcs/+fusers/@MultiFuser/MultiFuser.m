classdef MultiFuser < handle
    
    properties
        fuserMap
        fuserType='publicsim.funcs.fusers.T2TFwoMnf';
        %fuserSubtype='publicsim.funcs.trackers.BasicKalman(6)';
        enableNonIealCorrelation = 0;
        missCorrelationProb = 1;
    end
    
    methods
        function obj=MultiFuser(fuserType)
            if nargin >= 1 && ~isempty(fuserType)
                obj.fuserType=fuserType;
            end
            obj.fuserMap=containers.Map('KeyType','int64','ValueType','any');
        end
        
        function newTrackId = multiUpdateTrack(obj,trackId,sourceId,track)

            if obj.enableNonIealCorrelation && isKey(obj.fuserMap,trackId)
                
                allFusedTracksVals = values(obj.fuserMap);
                allFusedTrackKeys  = keys(obj.fuserMap);
                for i = 1:numel(allFusedTracksVals)
                    %Get fused track state and covariance at track.t
                    if isempty(allFusedTracksVals{i}.fusedTrack.t)
                        mdist(i) = NaN;
                        continue
                    end
                    
                    [~,maxTimeIndex] = max([allFusedTracksVals{i}.fusedTrack.t,track.t]);
                    
                    if maxTimeIndex == 1
                        [xT,PT] = track.predict(allFusedTracksVals{i}.fusedTrack.t);
                        [xF,PF] = allFusedTracksVals{i}.getCurrentState(allFusedTracksVals{i}.fusedTrack.t);
                    else
                        xT = track.x;
                        PT = track.P;
                        [xF,PF] = allFusedTracksVals{i}.getCurrentState(track.t);
                        
                    end
                    
                    %Calculate Mahalanobis Distance between Fused track and
                    % current track
                    mdist(i) = obj.mahalanobisDistacanceCalc(xF,PF,xT,PT); 
                end
                
                [mdistVal,corrId] = min(mdist);
                
                if corrId ~= trackId && rand <= obj.missCorrelationProb && ~isnan(mdistVal)
                    newTrackId = allFusedTrackKeys(corrId);
                    newTrackId = cell2mat(newTrackId);
                    % this is where miss correlations happen
                else
                    newTrackId = trackId;
                end
                
            else
                newTrackId = trackId;
            end
            
            if isKey(obj.fuserMap,trackId)
                fuser=obj.fuserMap(newTrackId);
                fuser.fusedTrack.updatePurity(trackId);
            else
                fuser=eval([obj.fuserType]);% '(''' obj.fuserSubtype ''')']);
                fuser.fusedTrack.updatePurity(trackId) % Assign inital ID
            end
            
            fuser.updateTrack(sourceId,track);
            obj.fuserMap(newTrackId)=fuser;
            
        end
        
        function [tracks,ids]=getAllTracks(obj,time)
            fusers=values(obj.fuserMap);
            ids=keys(obj.fuserMap);
            tracks=cell(numel(fusers),1);
            for i=1:numel(fusers)
                fuser=fusers{i};
                fuser.fuseTracks(time);
                tracks{i}=fuser.fusedTrack;
            end
        end
        
        function dist = mahalanobisDistacanceCalc(obj,x1,P1,x2,P2)
            
            dist = sqrt((x1-x2)'*(P1+P2)^-1*(x1-x2));
            
        end
          
    end
    
end

