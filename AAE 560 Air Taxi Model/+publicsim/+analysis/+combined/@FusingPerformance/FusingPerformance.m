classdef FusingPerformance < publicsim.analysis.CoordinatedAnalyzer
    %TRACKING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        fusionAnalyzer
        trackingAnalyzer
        movementAnalyzer
        idToName
        logger
        calculatedFusionErrors
        calculatedTrackErrors
        fusionIdSelect
        projectionTime=15
    end
    
    properties 
        posThreshold = 30;
        velThreshold = 40;
        pcovThreshold = 50;
        vcovThreshold = 60;
    end
    
    
    methods
        
        function obj=FusingPerformance(logger, coordinator, varargin)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            
            obj.logger=logger;
            obj.buildAgentIdToNames();
            obj.movementAnalyzer= coordinator.requestAnalyzer('publicsim.analysis.basic.Movement', logger);
            obj.fusionAnalyzer= coordinator.requestAnalyzer('publicsim.analysis.functional.Fusing', logger);
            obj.trackingAnalyzer= coordinator.requestAnalyzer('publicsim.analysis.functional.Tracking', logger);
            
            if length(varargin) == 1
                obj.fusionIdSelect = obj.fusionAnalyzer.getSourceByName(varargin{1});
            else
                obj.fusionIdSelect = [];
            end
            %obj.plotFusedTracksCompare();
        end
        
        function setProjectionTime(obj,projectionTime)
            obj.projectionTime=projectionTime;
        end
        
        function [trackErrors,fusionErrors]=getTrackFusionErrors(obj)
            
            [output, bool, memoizeKey] = obj.getMemoize();
            if bool
                trackErrors = output.trackErrors;
                fusionErrors = output.fusionErrors;
                return;
            end
            
            observableData=obj.movementAnalyzer.getObservablePositions();
            trackingData=obj.trackingAnalyzer.getAllTracksInTimeBySource(...
                min(observableData.times),...
                max(observableData.times));
            trackerIds=[trackingData.sourceId];
            
            trackErrors=[];
            for i=1:numel(trackerIds)
                trackerId=trackerIds(i);
                trackErrors.trackerId(i)=trackerId;
                for j=1:numel(observableData.observableIds)
                    position=observableData.positions(j,:);
                    velocity=observableData.velocities(j,:);
                    acceleration=observableData.accelerations(j,:);
                    time=observableData.times(j);
                    id=observableData.observableIds(j);
                    [trackPosition,~]=obj.trackingAnalyzer.getPosition(time,id,trackerId);
                    if any(isnan(trackPosition))
                        trackErrors.error(i,j)=NaN;
                    else
                        trackErrors.error(i,j)=sqrt(sum((position-trackPosition').^2));
                    end
                    trackErrors.ids(i,j)=id;
                    trackErrors.times(i,j)=time;
                    trackErrors.actual(i,j,:)=position;
                    trackErrors.estimated(i,j,:)=trackPosition;
                end
                
            end
            
            fusionData = obj.fusionAnalyzer.getAllTracksInTimeBySource(...
                min(observableData.times),...
                max(observableData.times));
            
            %% Select Fuser ID
            if ~isempty(obj.fusionIdSelect)
                fusersIds = obj.fusionIdSelect;
            else
                fusersIds=[fusionData.sourceId];
            end
            
            fusionErrors = [];
            %%
            for i=1:numel(fusersIds)
                fuserId=fusersIds(i);
                fusionErrors.fuserIds(i)=fuserId;
                for j=1:numel(observableData.observableIds)
                    position=observableData.positions(j,:);
                    velocity=observableData.velocities(j,:);
                    acceleration=observableData.accelerations(j,:);
                    time=observableData.times(j);
                    id=observableData.observableIds(j);
                    [fusionPosition,fusionObject]=obj.fusionAnalyzer.getPosition(time,id,fuserId);
                    if any(isnan(fusionPosition))
                        fusionErrors.error(i,j)=NaN;
                        fusionErrors.velError(i,j) = NaN;
                        fusionErrors.pCov(i,j) = NaN;
                        fusionErrors.VCov(i,j) = NaN;
                    else
                        fusionErrors.error(i,j)=sqrt(sum((position-fusionPosition').^2));
                        velFused = fusionObject.x(4:6);
                        fusionErrors.velError(i,j) = sqrt(sum((velocity-velFused').^2));
                        fusionErrors.pCov(i,j) = mean(sqrt(eig(fusionObject.P(1:3,1:3))));
                        fusionErrors.vCov(i,j) = mean(sqrt(eig(fusionObject.P(4:6,4:6))));
                    end
                    fusionErrors.ids(i,j)=id;
                    fusionErrors.times(i,j)=time;
                    fusionErrors.actual(i,j,:)=position;
                    fusionErrors.estimated(i,j,:)=fusionPosition;
                    
                    %Projection:
                    [~,fusionObject]=obj.fusionAnalyzer.getPosition(time-obj.projectionTime,id,fuserId);
                    if ~isempty(fusionObject)
                        [x,P]=fusionObject.getPositionAtTime(time);
                        %diagOfP=diag(P);
                        fusionErrors.projected.position.error(i,j)=sqrt(sum((position-x(1:3)').^2));
                        fusionErrors.projected.position.covarianceError(i,j)=mean(sqrt(eig(P(1:3,1:3))));
                        if size(P,1) >= 6
                            fusionErrors.projected.velocity.estimated(i,j,:)=x(4:6);
                            fusionErrors.projected.velocity.error(i,j)=sqrt(sum((velocity-x(4:6)').^2));
                            fusionErrors.projected.velocity.covarianceError(i,j)=mean(sqrt(eig(P(4:6,4:6))));
                        else
                            fusionErrors.projected.velocity.covarianceError=nan;
                        end
                        
                        if size(P,1) >= 9
                            fusionErrors.projected.acceleration.estimated(i,j,:)=x(7:9);
                            fusionErrors.projected.acceleration.error(i,j)=sqrt(sum((acceleration-x(7:9)').^2));
                            fusionErrors.projected.acceleration.covarianceError(i,j)=mean(sqrt(eig(P(7:9,7:9))));
                        else
                            fusionErrors.projected.acceleration.covarianceError(i,j)=nan;
                        end
                    else
                        fusionErrors.projected.position.error(i,j)=nan;
                        fusionErrors.projected.position.covarianceError(i,j)=nan;
                        fusionErrors.projected.velocity.error(i,j)=nan;
                        fusionErrors.projected.velocity.covarianceError(i,j)=nan;
                        fusionErrors.projected.acceleration.error(i,j)=nan;
                        fusionErrors.projected.acceleration.covarianceError(i,j)=nan;
                    end
                end
                
                % Get Mean Errors by fuserID
                unqTrackIds = unique(fusionErrors.ids(i,:));
                for jj = 1:numel(unqTrackIds)
                    
                    [~,indx] = find(fusionErrors.ids(i,:) == unqTrackIds(jj));
                    %
                    %                 fusionErrors.errorPosByTrack(jj,:) = fusionErrors.error(i,indx);
                    %                 fusionErrors.errorVelByTrack(jj,:) = fusionErrors.velError(i,indx);
                    
                    if isempty(indx)
                        fusionErrors.meanPosError(i,jj)=NaN;
                        fusionErrors.meanVelError(i,jj)=Nan;
                        fusionErrors.meanPosCovError(i,jj)=NaN;
                        fusionErrors.meanVelCovError(i,jj)=NaN;
                    else
                        fusionErrors.meanPosError(i,jj) = nanmean(fusionErrors.error(i,indx));
                        fusionErrors.meanVelError(i,jj) = nanmean(fusionErrors.velError(i,indx));
                        
                        fusionErrors.meanPosCovError(i,jj) = nanmean(fusionErrors.pCov(i,indx));
                        fusionErrors.meanVelCovError(i,jj) = nanmean(fusionErrors.vCov(i,indx));
                    end
                end
             
            end
            obj.calculatedFusionErrors = fusionErrors;
            obj.calculatedTrackErrors = trackErrors;
            
            output.trackErrors = trackErrors;
            output.fusionErrors = fusionErrors;
            obj.memoize(output, memoizeKey)
        end
        
        function metric=calculateTimeWithAccuracy(obj,accuracy)
            [metric, bool, memoizeKey] = obj.getMemoize(accuracy);
            if bool
                return;
            end
            if isempty(obj.calculatedFusionErrors)
                obj.getTrackFusionErrors();
            end
            
            fuserErrors=obj.calculatedFusionErrors;
            
            observableIds=unique([fuserErrors.ids]);
            fuserIds=unique([fuserErrors.fuserIds]);
            timeWithAccuracy=zeros(numel(fuserIds),numel(observableIds));
            timeWithObservable=zeros(numel(fuserIds),numel(observableIds));
            for i=1:numel(fuserIds)
                for j=1:numel(observableIds)
                    observableId=observableIds(j);
                    [~,indx] = find(fuserErrors.ids(i,:) == observableId);
                    thresholdMet=fuserErrors.projected.position.error(i,indx) < accuracy & fuserErrors.projected.position.covarianceError(i,indx) < accuracy;
                    thresholdMet(isnan(thresholdMet))=[];
                    timeWithAccuracy(i,j)=sum(thresholdMet);
                    timeWithObservable(i,j)=numel(indx);
                end
            end
            
            metric.timeWithAccuracy=timeWithAccuracy;
            metric.timeWithObservable=timeWithObservable;
            metric.fuserIds=fuserIds;
            metric.observableIds=observableIds;
            
            obj.memoize(metric, memoizeKey, accuracy);
        end
        
        function calcTimeliness(obj)
            if ~isempty(obj.calculatedFusionErrors)
                fusionErrors = obj.calculatedFusionErrors;
            else
                [~,fusionErrors] = obj.getTrackFusionErrors();
            end
            
            unqThrtIds = unique(fusionErrors.ids);
            
            for i = 1:numel(unqThrtIds)
                
                [~,indx] = find(fusionErrors.ids == unqThrtIds(i));
                fusionErrors.posErrorTimeliness(i,:) = (fusionErrors.error(indx) < obj.posThreshold);
                fusionErrors.velErrorTimeliness(i,:) = (fusionErrors.velError(indx) < obj.velThreshold);
                fusionErrors.pCovTimeliness(i,:) = (fusionErrors.pCov(indx) < obj.pcovThreshold);
                fusionErrors.vCovTimeliness(i,:) = (fusionErrors.vCov(indx) < obj.vcovThreshold);
                
                fusionErrors.posMaxWindow(i) = obj.getMaxWindowSize([fusionErrors.posErrorTimeliness(i,:)]);
                fusionErrors.velMaxWindow(i) = obj.getMaxWindowSize([fusionErrors.velErrorTimeliness(i,:)]);
                fusionErrors.pcovMaxWindow(i) = obj.getMaxWindowSize([fusionErrors.pCovTimeliness(i,:)]);
                fusionErrors.vcovMaxWindow(i) = obj.getMaxWindowSize([fusionErrors.vCovTimeliness(i,:)]);
            end
            
            % Need to add output assignment
            
            obj.calculatedFusionErrors = fusionErrors;
            
        end
    
    function maxWindowSize = getMaxWindowSize(obj,binaryArray)
        
        windowSize = 0;
        maxWindowSize = 0;
        resetCounter = 0;
        for i = 1:length(binaryArray)
            resetCounter = 0;
            if binaryArray(i) == 0
                resetCounter = 1;
                windowSize = 0;
                continue
            end
            
            if resetCounter == 0
                windowSize = windowSize + 1;
                if maxWindowSize < windowSize
                    maxWindowSize = windowSize;
                end
            end
        end
    end
    
        
        
        function plotMeanErrors(obj)
            
            % Check if errors are calculated
            
            if ~isempty(obj.calculatedFusionErrors)
                fusionErrors = obj.calculatedFusionErrors;
            else
                [~,fusionErrors] = obj.getTrackFusionErrors();
            end
            
            figure()
            hold
            for i = 1:numel(fusionErrors.fuserIds)
                % plot Pos Errors
                plot(fusionErrors.meanPosError(i,:))
                fuserLegend{i} = sprintf('Fuser %i',fusionErrors.fuserIds(i));
            end
            grid
            xlabel('Time')
            ylabel('Position Error (m)')
            legend(fuserLegend)
            title('Mean Position Fusion Error')
            
            figure()
            hold
            for i = 1:numel(fusionErrors.fuserIds)
                % plot Pos Errors
                plot(fusionErrors.meanVelError(i,:))
            end
            grid
            xlabel('Time')
            ylabel('Velocity Error (m/s)')
            legend(fuserLegend)
            title('Mean Velocity Tracking Error')
        end
        
        
        function plotFusedTracksCompare(obj)
            if ~isempty(obj.calculatedFusionErrors)
                fusion = obj.calculatedFusionErrors;
                track = obj.calculatedTrackErrors;
            else
                [track,fusion] = obj.getTrackFusionErrors();
            end
            
            legEntry = {};
            for i = 1:numel(fusion.fuserIds)
                
                fusionId =  fusion.fuserIds(i);
                
                [trackIds,~]= unique(fusion.ids(i,:));
                
                % plot all tracks by a given fuser
                figure;
                hold all;
                for j = 1:numel(trackIds)
                    trIndex = find(fusion.ids(i,:) == trackIds(j));
                    plot(fusion.times(i,trIndex),fusion.error(i,trIndex));
                    legEntry{end+1} = sprintf('Track %i',trackIds(j));
                end
                xlabel('Time (sec)');
                ylabel('Pos Error');
                grid;
                legend(legEntry);
                title(sprintf('Fused Track Errors by Fuser %d',fusionId));
                hold off;
                
            end
            
            %Plot Fused and Tracker Tracks
            
            for i = 1:numel(fusion.fuserIds)
                
                fusionId =  fusion.fuserIds(i);
                [trackIds,~]= unique(fusion.ids(i,:));
                
                for j = 1:numel(trackIds)
                    figure;
                    hold all;
                    trIndex = find(fusion.ids(i,:) == trackIds(j));
                    
                    %plot fusion Track
                    plot(fusion.times(i,trIndex),fusion.error(i,trIndex),'LineWidth',2)
                    legEntry = {};
                    legEntry{end+1} = sprintf('Fuser %i',fusionId);
                    %Plot Tracker Track
                    for k = 1:numel(track.trackerId)
                        trIndexTracker = find(track.ids(k,:) == trackIds(j));
                        plot(track.times(k,trIndexTracker),track.error(k,trIndexTracker));
                        legEntry{end+1} = sprintf('Tracker %i',track.trackerId(k));
                    end
                    xlabel('Time (sec)');
                    ylabel('Pos Error');
                    grid;
                    legend(legEntry);
                    title(sprintf('Track %i Error Comparison',trackIds(j)));
                    hold off;
                    
                end
                
            end
            
        end
    end
    
    
    methods(Access=private)
        function buildAgentIdToNames(obj)
            allAgents=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.functional.Tracking');
            obj.idToName=containers.Map('KeyType','int64','ValueType','any');
            allIds=[allAgents.id];
            for i=1:numel(allIds)
                obj.idToName(allIds(i))=allAgents(i).value.commonName;
            end
        end
    end
    
end
