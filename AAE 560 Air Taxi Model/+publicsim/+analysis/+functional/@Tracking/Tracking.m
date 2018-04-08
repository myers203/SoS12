classdef Tracking < publicsim.analysis.CoordinatedAnalyzer
    %TRACKING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=protected)
        logger
        allTracks=struct('trackId',[],...
            'trackFilter',[],...
            'trackTime',[],...
            'trackSourceId',[],...
            'trackTxTime',[]);
    end
    
    methods
        function obj=Tracking(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.getAllTracks();
        end
        
        function bestTrack=getTrack(obj,time,id,sourceId)
            trackIds=[obj.allTracks.trackId];
            trackSourceIds=[obj.allTracks.trackSourceId];
            trackTimes=[obj.allTracks(trackIds==id & trackSourceIds == sourceId).trackTime];
            timeDiffs=time-trackTimes;
            timeDiffs(timeDiffs < 0)=[];
            closestTime=time-min(timeDiffs);
            if isempty(closestTime)
                bestTrack=[];
                return;
            end
            trackFilter={obj.allTracks(trackIds==id & trackSourceIds == sourceId).trackFilter};
            trackFilter=trackFilter(trackTimes==closestTime);
            if ~isempty(trackFilter)
                bestTrack=trackFilter{1};
            else
                bestTrack=[];
            end
        end
        
        function [position,track]=getPosition(obj,time,id,sourceId)
            track=obj.getTrack(time,id,sourceId);
            if isempty(track)
                position=[NaN NaN NaN];
            else
                x=track.getPositionAtTime(time);
                position=x(1:3);
            end
        end
        
        function output=getAllTracksInTimeBySource(obj,timeStart,timeEnd)
            allSourceIds=unique([obj.allTracks.trackSourceId]);
            allObjectIds=unique([obj.allTracks.trackId]);
            times=timeStart:1:timeEnd;
            for i=1:numel(allSourceIds)
                output(i).sourceId=allSourceIds(i); %#ok<AGROW>
                for k=1:numel(allObjectIds)
                    positions=zeros(3,numel(times));
                    tracks=cell(1,numel(times));
                    for j=1:numel(times)
                        
                        [positions(:,j),tracks{j}]=obj.getPosition(times(j),allObjectIds(k),allSourceIds(i));
                        %tracks{j}=obj.getTrack(times(j),allObjectIds(k),allSourceIds(i));
                    end
                    trackData(k).positions=positions; %#ok<AGROW>
                    trackData(k).trackId=allObjectIds(k);  %#ok<AGROW>
                    trackData(k).trackObjects=tracks; %#ok<AGROW>
                end
                output(i).trackData=trackData; %#ok<AGROW>
            end
        end
        
        function plotAllTracks(obj)
            allSourceIds=unique([obj.allTracks.trackSourceId]);
            allObjectIds=unique([obj.allTracks.trackId]);
            timeStart=floor(min([obj.allTracks.trackTime]));
            timeEnd=ceil(max([obj.allTracks.trackTime]));
            times=timeStart:1:timeEnd;

            for i=1:numel(allSourceIds)
                figure;
                positions=zeros(3,numel(times),numel(allObjectIds));
                for j=1:numel(times)
                    for k=1:numel(allObjectIds)
                        positions(:,j,k)=obj.getPosition(times(j),allObjectIds(k),allSourceIds(i));
                    end
                end
                for k = 1:numel(allObjectIds)
                    scatter3(positions(1,:,k),positions(2,:,k),positions(3,:,k));
                    hold on
                end
                title(['Track Positions for Observer' num2str(allSourceIds(i))]);
                hold off;
            end
        end
        
        function plotTrackPurity(obj)
            % get all sources and Tracks
            for i = 1:numel(obj.allTracks)
                allSources(i) = obj.allTracks(i).trackSourceId;
                %Determine total number of Tracks
                allTrkIds(i) = obj.allTracks(i).trackId;
            end
            
            unqSrcs = unique(allSources);
            unqTracks = unique(allTrkIds);
            numUnqTracks = numel(unqTracks);
            
            for j = 1:numel(unqSrcs)
                % Get Tracks from source j
                
                [~,tempIndx] = find(allSources == unqSrcs(j));
                
                srcTracks = obj.allTracks(tempIndx);
                
                % determine Track by this source
                allSrcTrkIds = [];
                for ktemp = 1:numel(srcTracks)
                    allSrcTrkIds(ktemp) = srcTracks(ktemp).trackId;
                end
                
                unqSrcTrkIds = unique(allSrcTrkIds);
                numSrcTrks = numel(unqSrcTrkIds);
                confMatrix = zeros(numUnqTracks,numUnqTracks);
                normConfMatrix = zeros(numUnqTracks,numUnqTracks);
                labels = [];
                
                for jj = 1:numSrcTrks
                    
                    [~,srcTrkIndx] = find(allSrcTrkIds == unqSrcTrkIds(jj),1,'Last');
                    
                    
                    srcTrackPurity = srcTracks(srcTrkIndx).trackFilter.trackPurity;
                    srcTrackKey = srcTrackPurity(1); %first element is always correct Id
                    missValues = unique(srcTrackPurity);
                    
                    for kk = 1:numel(missValues)
                        [~,conutVals]= find(srcTrackPurity == missValues(kk));
                        confMatrix(unqSrcTrkIds(jj),missValues(kk)) = numel(conutVals);
                    end
                    
                    normConfMatrix(unqSrcTrkIds(jj),:) = confMatrix(unqSrcTrkIds(jj),:)./sum(confMatrix(unqSrcTrkIds(jj),:));
                    
                end
                %Build Trk Legend
                for h = 1:numUnqTracks
                    labels{h} = sprintf('Trk %i',unqTracks(h));
                end
                
                heatMap =   HeatMap(normConfMatrix','ColorMap','parula','Symmetric',false,'RowLabels',labels,'ColumnLabels',labels);
                % colorbar Need to figure out how to add color bar to heat map
                addTitle(heatMap,sprintf('Meas. Assoc. Confusion Tracker %i',unqSrcs(j)));
                addXLabel(heatMap,'Tracks');
                addYLabel(heatMap,'Correlated Measurements');
                
            end
            
        end
        
    end
    
    methods(Access=private)
        function getAllTracks(obj)
            trackingData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.functional.Tracking',{publicsim.agents.functional.Tracking.TRACK_LOGGING_KEY});
            if isempty(trackingData.(publicsim.agents.functional.Tracking.TRACK_LOGGING_KEY))
                warning('No tracking data loaded!');
                return;
            end
        
            obj.allTracks=struct('trackIds',[],...
                'trackFilters',[],...
                'trackTimes',[],...
                'trackSourceIds',[],...
                'trackTxTimes',[]);
        
            allData=trackingData.(publicsim.agents.functional.Tracking.TRACK_LOGGING_KEY);
            for i=1:numel(allData)
                trackMessage=allData(i).value;
                %trackDB=getArrayFromByteStream(trackMessage.databaseSerialObject);
                %trackFilters=values(trackDB.map);
                serializedTrackFilters=trackMessage.trackSerialObjects;
                trackFilters=cell(numel(serializedTrackFilters),1);
                for j=1:numel(serializedTrackFilters)
                    filterObject=eval(trackMessage.filterType);
                    filterObject=filterObject.deserialize(serializedTrackFilters{j}{2});
                    trackFilters{j}=filterObject;
                end
                trackIds=trackMessage.ids;
                trackTimes=zeros(numel(trackFilters),1);
                for j=1:numel(trackFilters)
                    trackTimes(j)=trackFilters{j}.t;
                    %offset=trackMessage.time-trackTimes(j)
                end
                trackTxTimes=trackMessage.time*ones(numel(trackFilters),1);
                trackSourceIds=allData(i).id*ones(numel(trackFilters),1);
                
                obj.allTracks.trackIds=[obj.allTracks.trackIds; trackIds'];
                obj.allTracks.trackFilters=[obj.allTracks.trackFilters; trackFilters];
                obj.allTracks.trackTimes=[obj.allTracks.trackTimes; trackTimes];
                obj.allTracks.trackSourceIds=[obj.allTracks.trackSourceIds; trackSourceIds];
                obj.allTracks.trackTxTimes=[obj.allTracks.trackTxTimes; trackTxTimes];
            end
            
            %Convert to single idx across struct
            trackArrayStruct=obj.allTracks;
            obj.allTracks=[];
            for i=1:numel(trackArrayStruct.trackIds)
                obj.allTracks(i).trackId=trackArrayStruct.trackIds(i);
                obj.allTracks(i).trackFilter=trackArrayStruct.trackFilters{i};
                obj.allTracks(i).trackTime=trackArrayStruct.trackTimes(i);
                obj.allTracks(i).trackSourceId=trackArrayStruct.trackSourceIds(i);
                obj.allTracks(i).trackTxTime=trackArrayStruct.trackTxTimes(i);
            end
            
        end
    end
    
end

