classdef Detections < publicsim.analysis.CoordinatedAnalyzer
    %DETECTIONS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        sensingAnalyzer
        sensorAzElRData
        movementAnalyzer
        movementAzElRData
    end
    
    properties(Constant)
        AZ_EL_R_TITLES={'Azimuth (deg)','Elevation (deg)','Range (m)'};
        AZ_EL_R_BOUNDFIELD={'azimuth_bounds','elevation_bounds',[]};
    end
    
    methods
        
        function obj=Detections(logger, coordinator, varargin)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.sensingAnalyzer = coordinator.requestAnalyzer('publicsim.analysis.functional.Sensing', logger);
            obj.movementAnalyzer = coordinator.requestAnalyzer('publicsim.analysis.basic.Movement', logger);
            obj.buildAzElR();
        end
        
        function plotAllAzElRByObjectAndSensor(obj)
            for i=1:numel(obj.sensorAzElRData)
                sensorData=obj.sensorAzElRData{i};
                observableData=obj.movementAzElRData{i};
                objectIds=unique(observableData.observableIds);
                for j=1:numel(objectIds)
                    figure;
                    for k=1:3 %Az/El/R
                        actuals.data=observableData.observableAzElR(...
                            observableData.observableIds==objectIds(j),...
                            k);
                        actuals.time=observableData.observableTimes(...
                            observableData.observableIds==objectIds(j));
                        senses.data=sensorData.measurementAzElR(...
                            sensorData.ids==objectIds(j),...
                            k);
                        senses.times=sensorData.time(...
                            sensorData.ids==objectIds(j));
                        
                        subplot(3,1,k);
                        
                        hold on;
                        plot(senses.times,senses.data,'x');
                        [actuals.time,idx]=sort(actuals.time);
                        actuals.data=actuals.data(idx);
                        plot(actuals.time,actuals.data,'--');
                        ylabel(obj.AZ_EL_R_TITLES{k});
                        %bound lines:
                        if ~isempty(obj.AZ_EL_R_BOUNDFIELD{k})
                            bounds=sensorData.sensorObj.(obj.AZ_EL_R_BOUNDFIELD{k});
                            minTime=min(actuals.time);
                            maxTime=max(actuals.time);
                            x=[minTime maxTime];
                            y=[bounds(1) bounds(2); bounds(1) bounds(2)];
                            plot(x,y,'k-','LineWidth',1.5);
                        end
                        if k==1
                            title(['Sensor-' num2str(sensorData.sensorId) ' Object-' num2str(objectIds(j))]);
                            legend('Detections','Object');
                        end
                    end
                    xlabel('Time (s)');
                end
            end
            
        end
        
        function plotAllAzElRBySensor(obj)
            for i=1:numel(obj.sensorAzElRData)
                sensorData=obj.sensorAzElRData{i};
                observableData=obj.movementAzElRData{i};
                objectIds=unique(observableData.observableIds);
                
                figure;
                for k=1:3 %Az/El/R
                    subplot(3,1,k);
                    hold on;
                    for j=1:numel(objectIds)
                        actuals.data=observableData.observableAzElR(...
                            observableData.observableIds==objectIds(j),...
                            k);
                        actuals.time=observableData.observableTimes(...
                            observableData.observableIds==objectIds(j));
                        senses.data=sensorData.measurementAzElR(...
                            sensorData.ids==objectIds(j),...
                            k);
                        senses.times=sensorData.time(...
                            sensorData.ids==objectIds(j));
                        senses.errors=sensorData.errors_AZELR(sensorData.ids==objectIds(j),...
                            k);
                        
                        ax = gca;
                        ax.ColorOrderIndex = j;
                        plot(senses.times,senses.data,'x');
                        ax.ColorOrderIndex = j;
                        plot(senses.times,senses.errors+senses.data,'o');
                        ax.ColorOrderIndex = j;
                        plot(senses.times,-1*senses.errors+senses.data,'o');
                        [actuals.time,idx]=sort(actuals.time);
                        actuals.data=actuals.data(idx);
                        ax = gca;
                        ax.ColorOrderIndex = j;
                        plot(actuals.time,actuals.data,'--');
                        ylabel(obj.AZ_EL_R_TITLES{k});
                        %bound lines:
                        
                    end
                    if ~isempty(obj.AZ_EL_R_BOUNDFIELD{k})
                        bounds=sensorData.sensorObj.(obj.AZ_EL_R_BOUNDFIELD{k});
                        minTime=min(actuals.time);
                        maxTime=max(actuals.time);
                        x=[minTime maxTime];
                        y=[bounds(1) bounds(2); bounds(1) bounds(2)];
                        plot(x,y,'k-','LineWidth',1.5);
                    end
                    if k==1
                        title(['Sensor-' num2str(sensorData.sensorId)]);
                        legendString=[];
                        for j=1:numel(objectIds)
                            legendString=[legendString ...
                                '''Object-' num2str(objectIds(j)) ...
                                ''','''',']; %#ok<AGROW>
                        end
                        legendString(end)=[];
                        eval(['legend(' legendString ');']);
                    end
                    
                end
                xlabel('Time (s)');
            end
            
        end
    end
    
    methods(Access=private)
        function buildAzElR(obj)
            sensorDatas=obj.sensingAnalyzer.getObservationsBySensor;
            observableData=obj.movementAnalyzer.getObservablePositions();
            earth=publicsim.util.Earth();
            earth.setModel('elliptical');
            for i=1:numel(sensorDatas)
                sensorData=sensorDatas(i);
                measurementAzElR=zeros(size(sensorData.measurements,1),3);
                for j=1:numel(sensorData.ids)
                    [measurementAzElR(j,1),measurementAzElR(j,2),measurementAzElR(j,3)]=...
                        earth.convert_ecef2azelr(sensorData.sensorPosition(j,:),sensorData.measurements(j,:));
                end
                sensorData.measurementAzElR=measurementAzElR;
                
                %Build cubic spline model of sensor positions
                %splineInterpolater=publicsim.util.SplineInterpolater(sensorData.time,sensorData.sensorPosition);
                
                if(size(unique(sensorData.sensorPosition,'rows'),1)~=1)
                    warning('Need to add support for moving sensors'); % TODO
                    return;
                end
                
                sensorPosition=unique(sensorData.sensorPosition,'rows');
                observableAzElR=zeros(numel(observableData.observableIds),3);
                for j=1:numel(observableData.observableIds)
                        [observableAzElR(j,1),observableAzElR(j,2),observableAzElR(j,3)]=...
                            earth.convert_ecef2azelr(sensorPosition,observableData.positions(j,:));
                end
                %obj.movementAzElRData{i}.sensorId=sensorData.sensorId;
                sensorObservableData.observableIds=observableData.observableIds;
                sensorObservableData.observableAzElR=observableAzElR;
                sensorObservableData.observableTimes=observableData.times;
                obj.movementAzElRData{i}=sensorObservableData;
                
                obj.sensorAzElRData{i}=sensorData;
            end
        end
    end
    
end

