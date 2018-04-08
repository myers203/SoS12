classdef TrackingPerformance < publicsim.analysis.CoordinatedAnalyzer
    %DETECTIONS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        sensingAnalyzer
        movementAnalyzer
        trackingAnalyzer
        idToName
        logger
        calculatedTrackErrors
        projectionTime=15;
        meanErrors
    end
    
    properties
        posThreshold = 30;
        velThreshold = 40;
        pcovThreshold = 50;
        vcovThreshold = 60;
    end
    
    
    properties(Constant)
        AZ_EL_R_TITLES={'Azimuth (deg)','Elevation (deg)','Range (m)'};
        AZ_EL_R_BOUNDFIELD={'azimuth_bounds','elevation_bounds',[]};
    end
    
    methods
        
        function obj=TrackingPerformance(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.buildAgentIdToNames();
            obj.sensingAnalyzer = coordinator.requestAnalyzer('publicsim.analysis.functional.Sensing', logger);
            obj.movementAnalyzer = coordinator.requestAnalyzer('publicsim.analysis.basic.Movement', logger);
            obj.trackingAnalyzer = coordinator.requestAnalyzer('publicsim.analysis.functional.Tracking', logger);
        end
        
        function setProjectionTime(obj,projectionTime)
            obj.projectionTime=projectionTime;
        end
        
        
        function trackErrors=getTrackErrors(obj)
            [trackErrors, bool, memoizeKey] = obj.getMemoize();
            if bool
                return;
            end
            
            if ~isempty(obj.calculatedTrackErrors)
                trackErrors=obj.calculatedTrackErrors;
            else
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
                        trackErrors.position.actual(i,j,:)=position;
                        trackErrors.velocity.actual(i,j,:)=velocity;
                        trackErrors.acceleration.actual(i,j,:)=acceleration;
                        
                        time=observableData.times(j);
                        id=observableData.observableIds(j);
                        [trackPosition,trackObject]=obj.trackingAnalyzer.getPosition(time,id,trackerId);
                        if any(isnan(trackPosition))
                            trackErrors.position.error(i,j)=NaN;
                            trackErrors.staleness(i,j)=NaN;
                        else
                            trackErrors.position.error(i,j)=sqrt(sum((position-trackPosition').^2));
                            trackErrors.staleness(i,j)=time-trackObject.t;
                        end
                        trackErrors.position.estimated(i,j,:)=trackPosition;
                        
                        
                        
                        if ~isempty(trackObject)
                            [x,P]=trackObject.getPositionAtTime(time);
                            %diagOfP=diag(P);
                            trackErrors.position.covarianceError(i,j)=mean(sqrt(eig(P(1:3,1:3))));
                            if size(P,1) >= 6
                                trackErrors.velocity.estimated(i,j,:)=x(4:6);
                                trackErrors.velocity.error(i,j)=sqrt(sum((velocity-x(4:6)').^2));
                                trackErrors.velocity.covarianceError(i,j)=mean(sqrt(eig(P(4:6,4:6))));
                            else
                                trackErrors.velocity.covarianceError=nan;
                            end
                            
                            if size(P,1) >= 9
                                trackErrors.acceleration.estimated(i,j,:)=x(7:9);
                                trackErrors.acceleration.error(i,j)=sqrt(sum((acceleration-x(7:9)').^2));
                                trackErrors.acceleration.covarianceError(i,j)=mean(sqrt(eig(P(7:9,7:9))));
                            else
                                trackErrors.acceleration.covarianceError(i,j)=nan;
                            end
                        else
                            trackErrors.position.covarianceError(i,j)=nan;
                            trackErrors.velocity.error(i,j)=nan;
                            trackErrors.velocity.covarianceError(i,j)=nan;
                            trackErrors.acceleration.error(i,j)=nan;
                            trackErrors.acceleration.covarianceError(i,j)=nan;
                        end
                        
                        trackErrors.ids(i,j)=id;
                        trackErrors.times(i,j)=time;
                        
                        %Projection:
                        [~,trackObject]=obj.trackingAnalyzer.getPosition(time-obj.projectionTime,id,trackerId);
                        if ~isempty(trackObject)
                            [x,P]=trackObject.getPositionAtTime(time);
                            %diagOfP=diag(P);
                            trackErrors.projected.position.error(i,j)=sqrt(sum((position-x(1:3)').^2));
                            trackErrors.projected.position.covarianceError(i,j)=mean(sqrt(eig(P(1:3,1:3))));
                            if size(P,1) >= 6
                                trackErrors.projected.velocity.estimated(i,j,:)=x(4:6);
                                trackErrors.projected.velocity.error(i,j)=sqrt(sum((velocity-x(4:6)').^2));
                                trackErrors.projected.velocity.covarianceError(i,j)=mean(sqrt(eig(P(4:6,4:6))));
                            else
                                trackErrors.projected.velocity.covarianceError=nan;
                            end
                            
                            if size(P,1) >= 9
                                trackErrors.projected.acceleration.estimated(i,j,:)=x(7:9);
                                trackErrors.projected.acceleration.error(i,j)=sqrt(sum((acceleration-x(7:9)').^2));
                                trackErrors.projected.acceleration.covarianceError(i,j)=mean(sqrt(eig(P(7:9,7:9))));
                            else
                                trackErrors.projected.acceleration.covarianceError(i,j)=nan;
                            end
                        else
                            trackErrors.projected.position.error(i,j)=nan;
                            trackErrors.projected.position.covarianceError(i,j)=nan;
                            trackErrors.projected.velocity.error(i,j)=nan;
                            trackErrors.projected.velocity.covarianceError(i,j)=nan;
                            trackErrors.projected.acceleration.error(i,j)=nan;
                            trackErrors.projected.acceleration.covarianceError(i,j)=nan;
                        end
                        
                    end
                    
                    % Get Mean Errors by trackerID
                    unqTrackIds = unique(observableData.observableIds);
                    for jj = 1:numel(unqTrackIds)
                        
                        [~,indx] = find(trackErrors.ids(i,:) == unqTrackIds(jj));
                        
                        if isempty(indx)
                            trackErrors.meanPosError(i,jj)=NaN;
                            trackErrors.meanVelError(i,jj)=Nan;
                            trackErrors.meanPosCovError(i,jj)=NaN;
                            trackErrors.meanVelCovError(i,jj)=NaN;
                        else
                            trackErrors.meanPosError(i,jj) = nanmean(trackErrors.position.error(i,indx));
                            trackErrors.meanVelError(i,jj) = nanmean(trackErrors.velocity.error(i,indx));
                            
                            trackErrors.meanPosCovError(i,jj) = nanmean(trackErrors.position.covarianceError(i,indx));
                            trackErrors.meanVelCovError(i,jj) = nanmean(trackErrors.velocity.covarianceError(i,indx));
                        end
                        
                    end
                    
                end
                
                obj.calculatedTrackErrors=trackErrors;
            end
            
            obj.memoize(trackErrors, memoizeKey);
        end
        
        function metric=calculateTimeWithAccuracy(obj,accuracy)
            
            [metric, bool, memoizeKey] = obj.getMemoize(accuracy);
            if bool
                return;
            end
            
            trackErrors=obj.getTrackErrors();
            
            observableIds=unique([trackErrors.ids]);
            trackerIds=unique([trackErrors.trackerId]);
            timeWithAccuracy=zeros(numel(trackerIds),numel(observableIds));
            timeWithObservable=zeros(numel(trackerIds),numel(observableIds));
            for i=1:numel(trackerIds)
                for j=1:numel(observableIds)
                    observableId=observableIds(j);
                    [~,indx] = find(trackErrors.ids(i,:) == observableId);
                    thresholdMet=trackErrors.projected.position.error(i,indx) < accuracy & trackErrors.projected.position.covarianceError(i,indx) < accuracy;
                    thresholdMet(isnan(thresholdMet))=[];
                    timeWithAccuracy(i,j)=sum(thresholdMet);
                    timeWithObservable(i,j)=numel(indx);
                end
            end
            
            metric.timeWithAccuracy=timeWithAccuracy;
            metric.timeWithObservable=timeWithObservable;
            metric.trackerIds=trackerIds;
            metric.observableIds=observableIds;
            
            obj.memoize(accuracy, memoizeKey);
        end  
        
        function calcTimeliness(obj)
            if ~isempty(obj.calculatedTrackErrors)
                trackErrors = obj.calculatedTrackErrors;
            else
                [~,trackErrors] = obj.getTrackErrors();
            end
            
            unqThrtIds = unique(trackErrors.ids);
            
            for i = 1:numel(unqThrtIds)
                
                [~,indx] = find(trackErrors.ids == unqThrtIds(i));
                trackErrors.posErrorTimeliness(i,:) = (trackErrors.position.error(indx) < obj.posThreshold);
                trackErrors.velErrorTimeliness(i,:) = (trackErrors.velocity.error(indx) < obj.velThreshold);
                trackErrors.pCovTimeliness(i,:) = (trackErrors.position.covarianceError(indx) < obj.pcovThreshold);
                trackErrors.vCovTimeliness(i,:) = (trackErrors.velocity.covarianceError(indx) < obj.vcovThreshold);
                
                trackErrors.posMaxWindow(i) = obj.getMaxWindowSize([trackErrors.posErrorTimeliness(i,:)]);
                trackErrors.velMaxWindow(i) = obj.getMaxWindowSize([trackErrors.velErrorTimeliness(i,:)]);
                trackErrors.pcovMaxWindow(i) = obj.getMaxWindowSize([trackErrors.pCovTimeliness(i,:)]);
                trackErrors.vcovMaxWindow(i) = obj.getMaxWindowSize([trackErrors.vCovTimeliness(i,:)]);
            end
            
            % Need to add output assignment
            
            obj.calculatedTrackErrors = trackErrors;
            
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
            
            if ~isempty(obj.calculatedTrackErrors)
                trackErrors = obj.calculatedTrackErrors;
            else
                trackErrors = obj.getTrackErrors();
            end
            
            figure()
            hold
            for i = 1:numel(trackErrors.trackerId)
                % plot Pos Errors
                plot(trackErrors.meanPosError(i,:))
                trackerLegend{i} = sprintf('Tracker %i',trackErrors.trackerId(i));
            end
            grid
            xlabel('Time')
            ylabel('Position Error (m)')
            legend(trackerLegend)
            title('Mean Position Tracking Error')
            
            figure()
            hold
            for i = 1:numel(trackErrors.trackerId)
                % plot Pos Errors
                plot(trackErrors.meanVelError(i,:))
            end
            grid
            xlabel('Time')
            ylabel('Velocity Error (m/s)')
            legend(trackerLegend)
            title('Mean Velocity Tracking Error')
        end        function plotProjectedErrors(obj)
            trackErrors=obj.getTrackErrors();
            colorOrder=get(groot,'DefaultAxesColorOrder');
            for i=1:numel(trackErrors.trackerId)
                projectedErrors=trackErrors.projected.position.error(i,:);
                projectedErrorsCov=trackErrors.projected.position.covarianceError(i,:);
                trackerId=trackErrors.trackerId(i);
                times=trackErrors.times(i,:);
                ids=trackErrors.ids(i,:);
                figure;
                title(['Projected Errors for Trk-' num2str(trackerId) ' ' obj.idToName(trackerId)]);
                hold on;
                uids=unique(ids);
                for j=1:numel(uids)
                    x=times(ids==uids(j));
                    y=projectedErrors(ids==uids(j));
                    [x,idx]=sort(x);
                    y=y(idx);
                    plot(x,...
                        y,'Color',colorOrder(j,:));
                end
                for j=1:numel(uids)
                    x=times(ids==uids(j));
                    y=projectedErrorsCov(ids==uids(j));
                    [x,idx]=sort(x);
                    y=y(idx);
                    plot(x,...
                        y,'--','LineWidth',1.5,'Color',colorOrder(j,:));
                end
                hold off;
                %set(gca, 'YScale', 'log')
                xlabel('Time');
                ylabel('Error (m)');
            end
        end
        
        function plotCovarianceErrorsByTracker(obj)
            trackErrors=obj.getTrackErrors();
            
            %Position Error Plots
            for i=1:numel(trackErrors.trackerId)
                trackerId=trackErrors.trackerId(i);
                times=trackErrors.times(i,:);
                ids=trackErrors.ids(i,:);
                figure;
                subplot(3,1,1);
                hold all;
                title(['Errors for Trk-' num2str(trackerId) ' ' obj.idToName(trackerId)]);
                errors=trackErrors.position.error(i,:);
                covErrors=trackErrors.position.covarianceError(i,:);
                tr=errors./covErrors;
                obj.subplotErrors(tr,times,ids);
                ylabel('Position TR');
                hold off;
                subplot(3,1,2);
                hold all;
                errors=trackErrors.velocity.error(i,:);
                covErrors=trackErrors.velocity.covarianceError(i,:);
                tr=errors./covErrors;
                obj.subplotErrors(tr,times,ids);
                ylabel('Velocity TR');
                hold off;
                subplot(3,1,3);
                hold all;
                errors=trackErrors.acceleration.error(i,:);
                covErrors=trackErrors.acceleration.covarianceError(i,:);
                tr=errors./covErrors;
                obj.subplotErrors(tr,times,ids);
                hold off;
                ylabel('Accel. TR');
                xlabel('Time (s)');
            end
        end
        
        function plotErrorByTracker(obj)
            trackErrors=obj.getTrackErrors();
            
            %Position Error Plots
            for i=1:numel(trackErrors.trackerId)
                trackerId=trackErrors.trackerId(i);
                errors=trackErrors.position.error(i,:);
                times=trackErrors.times(i,:);
                ids=trackErrors.ids(i,:);
                figure;
                subplot(3,1,1);
                hold all;
                title(['Errors for Trk-' num2str(trackerId) ' ' obj.idToName(trackerId)]);
                obj.subplotErrors(errors,times,ids);
                ylabel('Position (m)');
                hold off;
                subplot(3,1,2);
                hold all;
                errors=trackErrors.velocity.error(i,:);
                obj.subplotErrors(errors,times,ids);
                ylabel('Velocity (m/s)');
                hold off;
                subplot(3,1,3);
                hold all;
                errors=trackErrors.acceleration.error(i,:);
                obj.subplotErrors(errors,times,ids);
                hold off;
                ylabel('Accel. (m/s^2)');
                xlabel('Time (s)');
            end
        end
        
        function trackingDebug(obj)
            % Plot track estimates, sensor detections and actual moveable
            % positions
            
            allErrors = getTrackErrors(obj);
            sensorDetections = obj.sensingAnalyzer.getObservationsBySensor();
            
            for i=1:numel(allErrors.trackerId)
                trackerId=allErrors.trackerId(i);
                estPosition=squeeze(allErrors.estimated(i,:,:));
                actPosition=squeeze(allErrors.actual(i,:,:));
                times=allErrors.times(i,:);
                ids=allErrors.ids(i,:);
                %                 figure;
                %                 hold all;
                uids=unique(ids);
                for j=1:numel(uids)
                    
                    %                     for senId = 1:numel(sensorDetections)
                    %
                    %                         indx = find(sensorDetections(senId).ids==uids(j));
                    %                         sent(:,senId) = sensorDetections(senId).time(indx,1);
                    %                         senx(:,senId) = sensorDetections(senId).measurements(indx,1);
                    %                         seny(:,senId) = sensorDetections(senId).measurements(indx,2);
                    %                         senz(:,senId) = sensorDetections(senId).measurements(indx,3);
                    %
                    %                     end
                    
                    t_ids=times(ids==uids(j));
                    estx = estPosition(ids==uids(j),1);
                    esty = estPosition(ids==uids(j),1);
                    estz = estPosition(ids==uids(j),1);
                    %actual
                    actx = actPosition(ids==uids(j),1);
                    acty = actPosition(ids==uids(j),1);
                    actz = actPosition(ids==uids(j),1);
                    
                    %StartPlots
                    
                    figure()
                    hold
                    grid
                    plot(t_ids,estx,'x')
                    plot(t_ids,actx,'o')
                    legendstr = [];
                    for senId = 1:numel(sensorDetections)
                        indx = find(sensorDetections(senId).ids==uids(j));
                        sent = sensorDetections(senId).time(indx,1);
                        senx = sensorDetections(senId).measurements(indx,1);
                        
                        plot(sent,senx,'d')
                        
                        temp = mat2str(sprintf('Sensor %i',sensorDetections(senId).sensorId));
                        if isempty(legendstr)
                            legendstr = temp;
                        else
                            legendstr = strcat(legendstr,',',temp);
                        end
                    end
                    
                    legend('Estimated','Actual',legendstr)
                    xlabel('Time')
                    ylabel('ECEF(x)')
                    title(sprintf('TrackID %i -- ECEF Debug x',uids(j)))
                    hold off
                    
                    figure()
                    hold
                    grid
                    plot(t_ids,esty,'x')
                    plot(t_ids,acty,'o')
                    for senId = 1:numel(sensorDetections)
                        indx = find(sensorDetections(senId).ids==uids(j));
                        sent = sensorDetections(senId).time(indx,1);
                        seny = sensorDetections(senId).measurements(indx,2);
                        plot(sent,seny,'d')
                        
                    end
                    legend('Estimated','Actual',legendstr)
                    xlabel('Time')
                    ylabel('ECEF(y)')
                    title(sprintf('TrackID %i -- ECEF Debug y',uids(j)))
                    hold off
                    
                    figure()
                    hold
                    grid
                    plot(t_ids,estz,'x')
                    plot(t_ids,actz,'o')
                    for senId = 1:numel(sensorDetections)
                        indx = find(sensorDetections(senId).ids==uids(j));
                        sent = sensorDetections(senId).time(indx,1);
                        senz = sensorDetections(senId).measurements(indx,3);
                        plot(sent,senz,'d')
                        
                    end
                    legend('Estimated','Actual',legendstr)
                    xlabel('Time')
                    ylabel('ECEF(z)')
                    title(sprintf('TrackID %i -- ECEF Debug z',uids(j)))
                    hold off
                    
                end
                
                
            end
            
            
        end
        
        
        
    end
    
    methods(Static)
        
        function subplotErrors(errors,times,ids)
            uids=unique(ids);
            for j=1:numel(uids)
                x=times(ids==uids(j));
                y=errors(ids==uids(j));
                [x,idx]=sort(x);
                y=y(idx);
                plot(x,...
                    y);
            end
            if isnan(median(errors))
                set(gca, 'YScale', 'log')
            else
                plotMax=median(errors);
                if plotMax == 0
                    plotMax=mean(errors);
                end
                plotMax=min(plotMax*5,max(errors));
                if plotMax==0
                    plotMax=1;
                end
                ylim([0 plotMax]);
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

