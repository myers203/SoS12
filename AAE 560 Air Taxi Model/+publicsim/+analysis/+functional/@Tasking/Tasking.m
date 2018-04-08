classdef Tasking < publicsim.analysis.CoordinatedAnalyzer
    %SENSING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        bufferHeight = 5;
        incrementSpacing = 10;
    end
    
    properties(SetAccess=protected)
        logger
        allTasking
        taskableNames
        taskerNames
    end
    
    properties(Constant)
        TASKER_INFO = struct('name',[],'plotHeight',[]);
    end
    
    methods
        
        function obj=Tasking(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.getAllTasking();
            obj.getTaskableNames();
            obj.getTaskerNames();
        end
        
        function plotTaskingByTime(obj)
            if isempty(obj.allTasking)
                warning('No tasking data available.');
                return
            end
            taskableIds = [obj.allTasking.taskableId];
            taskingTimes = [obj.allTasking.time];
            
            obj.generateTaskerPlot(taskableIds,taskingTimes,'All Tasking Messages Sent');
        end
        
        function plotTaskingByTasker(obj)
            if isempty(obj.allTasking)
                return
            end
            taskerIds = [obj.allTasking.taskerId];
            taskableIds = [obj.allTasking.taskableId];
            taskingTimes = [obj.allTasking.time];
            
            % same as tasking by time, except for individual tasking agents
            uniqueTaskerIds = unique(taskerIds);
            
            for i = uniqueTaskerIds
                currentIdxs = taskerIds == i;
                currentTaskableIds = taskableIds(currentIdxs);
                currentTaskingTimes = taskingTimes(currentIdxs);
                currentTaskerName = [obj.taskerNames([obj.taskerNames.id]==i).commonName ' - ' mat2str(i)];
                
                obj.generateTaskerPlot(currentTaskableIds,currentTaskingTimes,['Tasking Messages Sent by ',currentTaskerName]);
            end
            
            
        end
        
        function plotCommandCountByTaskable(obj)
            % How many commands were in each tasking command.
            if isempty(obj.allTasking)
                return
            end
            
            taskableIds = [obj.allTasking.taskableId];
            
            % same as tasking by time, except for individual tasking agents
            uniqueTaskableIds = unique(taskableIds);
            
            for i = uniqueTaskableIds
                currentIdxs = taskableIds == i;
                
                currentTaskableName = [obj.taskableNames([obj.taskableNames.id]==i).commonName ' - ' mat2str(i)];
                
                obj.generateTaskableCommandPlot(currentIdxs,['Command Count for Tasking Messages to ',currentTaskableName]);
            end
            
        end
        
        function generateTaskableCommandPlot(obj, currentIdxs, plotTitle)
            
            taskings = obj.allTasking(currentIdxs);
            
            taskingTimes = [obj.allTasking.time];
            taskingTimes = taskingTimes(currentIdxs);
            
            nCommands = nan(numel(taskings),1);
            for i = 1:numel(taskingTimes)
                nCommands(i) = numel(taskings(i).command);
            end
            
            figure()
            plot(taskingTimes,nCommands,'ok');
            axis([0,taskingTimes(end)+5,0,max(nCommands)+5]);
            ylabel('Number of Commands per Tasking Message');
            xlabel('Time (s)');
            title(plotTitle);
            set(gcf,'color','w');
        end
        
        function generateTaskerPlot(obj,taskableIds, taskingTimes, plotTitle)
            uniqueTaskables = unique(taskableIds);
            
            taskerData = containers.Map('keyType','double','valueType','any');
            
            yTicks = nan(numel(uniqueTaskables),1);
            yTickLabels = cell(1,numel(uniqueTaskables));
            for i = 1:numel(uniqueTaskables)
                newTaskerInfo = obj.TASKER_INFO;
                taskerIdx = [obj.taskableNames.id]==uniqueTaskables(i);
                newTaskerInfo.name = [obj.taskableNames(taskerIdx).commonName ' - ' mat2str(uniqueTaskables(i))];
                newTaskerInfo.plotHeight = obj.bufferHeight+obj.incrementSpacing*(i-1);
                yTicks(i) = newTaskerInfo.plotHeight;
                yTickLabels{i} = newTaskerInfo.name;
                taskerData(uniqueTaskables(i)) = newTaskerInfo;
            end
            
            taskerVect = nan(numel(taskableIds),1);
            for i = 1:numel(taskableIds)
                taskerVect(i) = taskerData(taskableIds(i)).plotHeight;
            end
            
            figure()
            plot(taskingTimes,taskerVect,'xk');
            set(gca,'YTickLabel',yTickLabels,'YTick',yTicks);
            axis([0,taskingTimes(end)+5,0,yTicks(end)+5]);
            ylabel('Taskable Names');
            xlabel('Time (s)');
            title(plotTitle);
            set(gcf,'color','w');
        end
        
    end
    
    methods(Access=private)
        
        function getAllTasking(obj)
            taskingData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.functional.Tasking',{publicsim.agents.functional.Tasking.TASKING_LOGGING_KEY});
            if isempty(taskingData.(publicsim.agents.functional.Tasking.TASKING_LOGGING_KEY))
                warning('No tasking data loaded!');
                return
            end
            rawTaskingData=[taskingData.(publicsim.agents.functional.Tasking.TASKING_LOGGING_KEY).value];
            obj.allTasking=rawTaskingData;
        end
        
        function getTaskableNames(obj)
            taskables=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.functional.Taskable');
            taskableProperties = struct('id',[],'commonName',[]);
            for i=1:numel(taskables)
                % Record the taskables.  Note that, since this is a generic post processor, we don't want to do anything like:
                % isa(taskables(i).value.sensor,'publicsim.funcs.sensors.PointableAzElRSensor') &&
                if ~any([taskableProperties.id]==taskables(i).id)
                    taskableProperties(end+1).id=taskables(i).id;  %#ok<AGROW>
                    commonName = taskables(i).value.commonName;
                    if isempty(commonName)
                        commonName = 'Unnamed';
                    end
                    taskableProperties(end).commonName = commonName;
                end
            end
            taskableProperties(1) = []; % the first one was empty but is required to cat IDs.
            obj.taskableNames = taskableProperties;
        end
        
        function getTaskerNames(obj)
            taskers=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.functional.Tasking');
            taskerProperties = struct('id',[],'commonName',[]);
            for i=1:numel(taskers)
                % Record the taskables.  Note that, since this is a generic post processor, we don't want to do anything like:
                % isa(taskables(i).value.sensor,'publicsim.funcs.sensors.PointableAzElRSensor') &&
                if ~any([taskerProperties.id]==taskers(i).id)
                    taskerProperties(end+1).id=taskers(i).id;  %#ok<AGROW>
                    commonName = taskers(i).value.commonName;
                    if isempty(commonName) % This particular agent does not have a specified common name.
                        commonName = 'Unnamed';
                    end
                    taskerProperties(end).commonName = commonName;
                end
            end
            taskerProperties(1) = []; % the first one was empty but is required to cat IDs.
            obj.taskerNames = taskerProperties;
        end
    end
    
end

