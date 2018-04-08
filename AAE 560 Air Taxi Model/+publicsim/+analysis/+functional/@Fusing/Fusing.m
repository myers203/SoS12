classdef Fusing < publicsim.analysis.CoordinatedAnalyzer
    %TRACKING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=protected)
        logger
        fusedTracks=struct('trackId',[],...
            'trackFilter',[],...
            'trackTime',[],...
            'trackSourceId',[],...
            'trackTxTime',[]);
    end
    
    methods
        function obj=Fusing(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.getFusedTracks();
            %obj.plotPurity();
            %obj.plotFusedTracks();
        end
        
        function plotFusedTracks(obj)
            allSourceIds=unique([obj.fusedTracks.trackSourceId]);
            allObjectIds=unique([obj.fusedTracks.trackId]);
            timeStart=floor(min([obj.fusedTracks.trackTime]));
            timeEnd=ceil(max([obj.fusedTracks.trackTime]));
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
                title(['Track Positions for Fuser' num2str(allSourceIds(i))]);
                hold off;
            end
        end
        

        function getFusedTracks(obj)
            
            fusingData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.functional.Fusing',{publicsim.agents.functional.Fusing.FUSING_LOGGING_KEY});
            allData = fusingData.(publicsim.agents.functional.Fusing.FUSING_LOGGING_KEY);
            
            for i = 1:numel(allData)
                
                if isempty(allData(i).value.ids)
                    sprintf('No Fused Track at time %i',allData(i).time)
                    continue
                    
                else
                    
                    for j = 1:numel(allData(i).value.ids)
                        obj.fusedTracks.trackSourceId(end+1) = allData(i).id;
                        obj.fusedTracks.trackTxTime(end+1) = allData(i).time;
                        obj.fusedTracks.trackId(end+1) = allData(i).value.ids{j};
                        
                        
                        serializedTrack= allData(i).value.otherData.serializedTracks{j}; %#ok<NASGU>
                        trackType=allData(i).value.otherData.trackTypes{j};
                        track=eval([trackType '.deserializeWithType(serializedTrack,trackType)']);
                        
                        obj.fusedTracks.trackFilter{end+1} = track;
                        obj.fusedTracks.trackTime(end+1) = track.t;
                        
                    end
                    
                end
                
            end
            
            %Convert to single idx across struct
            trackArrayStruct=obj.fusedTracks;
            obj.fusedTracks=[];
            for i=1:numel(trackArrayStruct.trackId)
                obj.fusedTracks(i).trackId=trackArrayStruct.trackId(i);
                obj.fusedTracks(i).trackFilter=trackArrayStruct.trackFilter{i};
                obj.fusedTracks(i).trackTime=trackArrayStruct.trackTime(i);
                obj.fusedTracks(i).trackSourceId=trackArrayStruct.trackSourceId(i);
                obj.fusedTracks(i).trackTxTime=trackArrayStruct.trackTxTime(i);
            end
            
        end
        
                function bestTrack=getTrack(obj,time,id,sourceId)
            trackIds=[obj.fusedTracks.trackId];
            trackSourceIds=[obj.fusedTracks.trackSourceId];
            trackTimes=[obj.fusedTracks(trackIds==id & trackSourceIds == sourceId).trackTime];
            timeDiffs=time-trackTimes;
            timeDiffs(timeDiffs < 0)=[];
            closestTime=time-min(timeDiffs);
            if isempty(closestTime)
                bestTrack=[];
                return;
            end
            trackFilter={obj.fusedTracks(trackIds==id & trackSourceIds == sourceId).trackFilter};
            trackFilter=trackFilter(trackTimes==closestTime);
            if ~isempty(trackFilter)
                bestTrack=trackFilter{1};
            else
                bestTrack=[];
            end
        end
        
        function [position,track]=getPosition(obj,time,id,sourceId)
            
            [output, bool, memoizeKey] = obj.getMemoize(time, id, sourceId);
            if bool
                position = output.position;
                track = output.track;
                return;
            end
            
            track=obj.getTrack(time,id,sourceId);
            if isempty(track)
                position=[NaN NaN NaN];
            else
                x=track.getPositionAtTime(time);
                position=x(1:3);
            end
            
            
            output.position = position;
            output.track = track;
            obj.memoize(output, memoizeKey, time, id, sourceId);
        end

        
        function output=getAllTracksInTimeBySource(obj,timeStart,timeEnd)
            [output, bool, memoizeKey] = obj.getMemoize(timeStart, timeEnd);
            if bool
                return;
            end
            
            allSourceIds=unique([obj.fusedTracks.trackSourceId]);
            allObjectIds=unique([obj.fusedTracks.trackId]);
            times=timeStart:1:timeEnd;
            for i=1:numel(allSourceIds)
                output(i).sourceId=allSourceIds(i); %#ok<AGROW>
                for k=1:numel(allObjectIds)
                    positions=zeros(3,numel(times));
                    tracks=cell(1,numel(times));
                    for j=1:numel(times)
                        
                        positions(:,j)=obj.getPosition(times(j),allObjectIds(k),allSourceIds(i));
                        tracks{j}=obj.getTrack(times(j),allObjectIds(k),allSourceIds(i));
                    end
                    trackData(k).positions=positions; %#ok<AGROW>
                    trackData(k).trackId=allObjectIds(k);  %#ok<AGROW>
                    trackData(k).trackObjects=tracks; %#ok<AGROW>
                end
                output(i).trackData=trackData; %#ok<AGROW>
            end
            
            obj.memoize(output, memoizeKey, timeStart, timeEnd);
        end
        
        
        function plotPurity(obj)
            % This currently assumes only one fuser
            %             % Get all Fused Tracks
            %             for i = 1:numel(obj.fusedTracks)
            %                 allIds(i) = obj.fusedTracks(i).trackId;
            %
            %             end
            %
            %             uniqueTracks = unique(allIds);
            %             numUniqueTracks = numel(uniqueTracks);
            %             confMatrix =zeros(numUniqueTracks,numUniqueTracks);
            %
            %             for j = 1:numUniqueTracks
            %
            %                 %get Track Purity
            %                 [~,tempid] = find(allIds == uniqueTracks(j),1,'Last');
            %
            %                 allPurity = obj.fusedTracks(tempid).trackFilter.trackPurity;
            %
            %                 missValues = unique(allPurity);
            %
            %
            %                 for k = 1:numel(missValues)
            %                     [~,conutVals]= find(allPurity == missValues(k));
            %                     confMatrix(uniqueTracks(j),missValues(k)) = numel(conutVals);
            %                 end
            %
            %                 normConfMartix(j,:) = confMatrix(uniqueTracks(j),:)./max(confMatrix(uniqueTracks(j),:));
            %                 labels{j} = sprintf('Trk %i',uniqueTracks(j));
            %
            %             end
            %
            %             heatMap =   HeatMap(normConfMartix','ColorMap','parula','Symmetric',false,'RowLabels',labels,'ColumnLabels',labels);
            %             % colorbar Need to figure out how to add color bar to heat map
            %             addTitle(heatMap,sprintf('Track Correlation Confusion Fuser %i (normalized)',obj.fusedTracks(1).trackSourceId));
            %             addXLabel(heatMap,'System Level Tracks');
            %             addYLabel(heatMap,'Correlated Tracks');
            
            
            % get all sources and Tracks
            for i = 1:numel(obj.fusedTracks)
                allSources(i) = obj.fusedTracks(i).trackSourceId;
                %Determine total number of Tracks
                allTrkIds(i) = obj.fusedTracks(i).trackId;
            end
            
            unqSrcs = unique(allSources);
            unqTracks = unique(allTrkIds);
            numUnqTracks = numel(unqTracks);
            
            for j = 1:numel(unqSrcs)
                % Get Tracks from source j
                
                [~,tempIndx] = find(allSources == unqSrcs(j));
                
                srcTracks = obj.fusedTracks(tempIndx);
                
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
                addTitle(heatMap,sprintf('Track Correlation Confusion Tracker %i',unqSrcs(j)));
                addXLabel(heatMap,'Tracks');
                addYLabel(heatMap,'Correlated Tracks');
                
            end
            
        end
        
        function names=getNamesFromIds(obj,idList)
            
            [names, bool, memoizeKey] = obj.getMemoize(obj, idList);
            if bool
                return;
            end
            
            
            allAgents=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.functional.Fusing');
            names=cell(numel(idList),1);
            for i=1:numel(idList)
                for j=1:numel(allAgents)
                    agent=allAgents(j).value;
                    if agent.id==idList(i)
                        names{i}=agent.commonName;
                    end
                end
            end
        end
        
        function sourceId=getSourceByName(obj,name)
            
            [sourceId, bool, memoizeKey] = obj.getMemoize(name);
            if bool
                return;
            end
            
            sourceIds=unique([obj.fusedTracks.trackSourceId]);
            names=obj.getNamesFromIds(sourceIds);
            sourceId=[];
            for i=1:numel(names)
                if strncmpi(names{i},name,length(name))
                    sourceId(end+1)=sourceIds(i); %#ok<AGROW>
                end
            end
        end
        
    end
    
    
    
    
    
end
