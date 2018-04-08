classdef Tasking < publicsim.agents.base.Periodic & publicsim.agents.functional.Base
    %TASKING agent implementation of funcs.taskers.Tasker
    %
    %   setTaskingGroupId(id) sets the subtype for all tasking commands
    %
    %   enableTasking(taskingFunction,taskingClass,assessingClass) where
    %   the taskingFunction is a string or a
    %   publicsim.funcs.taskers.Tasker, the taskingClass is a string key
    %   for the type of commands, and the assessingClass is a string for
    %   the type of assessment ('track', etc.)
    %
    %   
    
    properties(SetAccess=private)
        taskingFunction         %publicsim.funcs.tasking.Tasker instance
        taskableClass           %type of commands / key for message type
        taskingTopicAll         %topic for broadcast to taskables
        taskingStatusTopic      %topic for receiving status updates
        taskingAssessmentTopic  %topic for subscribing to assessments
        taskingStatusPeriod=5;  %frequency of command generation
        taskingGroupId=1;       %subtype for all tasking topics 
        taskingReactive=0;      %enable tasking every time there is an update
        assessingClass          %string type of assessments
    end
    
    properties(Constant)
        TASKING_LOGGING_KEY='TASKING'; %key for disk storage
        TASKING_MESSAGE=struct(...      %tasking message
            'time',[],...
            'taskType',[],...
            'command',[]);
        TASKING_STATUS_MESSAGE=struct(...   %status message
            'time',[],...
            'id',[],...
            'otherData',[]);
        TASKING_MESSAGE_PREFIX='TASKING-';  %prefix for topic type
        TASKING_STATUS_PREFIX='TASKING_STATUS-'; %prefix for topic type
        TASKING_COMMAND_ALL_SUBSUBTYPE='-1'; %broadcast message subsubtype
        TASKING_TYPE_STATUS=1;
        TASKING_TYPE_COMMAND=2;
    end
    
    methods
        function obj=Tasking()
        end
        
        function setTaskingGroupId(obj,id)
            %sets the subtype for tasking commands
            if ~isempty(obj.taskingTopicAll)
                warning('Must set ID BEFORE enableTasking');
            end
            obj.taskingGroupId=id;
            %obj.rebuildTaskingTopics();
        end
        
        function setReactive(obj,value)
            obj.taskingReactive=value;
        end
        
        function enableTasking(obj,taskingFunction,taskingClass,assessingClass)
            %enable tasking functionality
            if isa(taskingFunction,'publicsim.funcs.taskers.Tasker')
                obj.taskingFunction=taskingFunction;
            else
                obj.taskingFunction = eval([taskingFunction '();']);
                assert(isa(obj.taskingFunction,'publicsim.funcs.taskers.Tasker'),...
                    'Must use Tasker abstract');
            end
            if isa(obj.taskingFunction,'publicsim.funcs.Loggable')
                obj.taskingFunction.attachLoggableCallee(obj)
            end
            obj.taskableClass=taskingClass;
            obj.assessingClass=assessingClass;
            obj.rebuildTaskingTopics();
            obj.scheduleAtTime(0,@obj.taskingStatusUpdateRequest);
            obj.scheduleAtTime(0,@obj.periodicTasking);
        end
        
        function topic=getTaskingTopicForTaskable(obj,taskableId)
            %Translates taskable ID into a topic for messaging
            topic=obj.getDataTopic(...,
                [obj.TASKING_MESSAGE_PREFIX obj.taskableClass],...
                num2str(obj.taskingGroupId),...
                num2str(taskableId));
        end
        
        function rebuildTaskingTopics(obj)
            %create data topics
            obj.taskingTopicAll=obj.getDataTopic(...
                [obj.TASKING_MESSAGE_PREFIX obj.taskableClass],...
                num2str(obj.taskingGroupId),...
                '-1');
            
            obj.taskingStatusTopic=obj.getDataTopic(...
                [obj.TASKING_STATUS_PREFIX obj.taskableClass],...
                num2str(obj.taskingGroupId),...
                '');
            obj.subscribeToTopicWithCallback(obj.taskingStatusTopic,...
                @obj.taskingStatusUpdateHandler);
            
            obj.taskingAssessmentTopic=obj.getDataTopic(...
                [publicsim.agents.functional.Assessing.ASSESSING_MESSAGE_PREFIX obj.assessingClass],...
                num2str(obj.taskingGroupId),...
                '');
            obj.subscribeToTopicWithCallback(obj.taskingAssessmentTopic,...
                @obj.taskingAssessmentUpdateHandler);
        end
        
        function sendTaskingCommands(obj,time)
            %periodic tasking
            [commands,ids]=obj.taskingFunction.getTasking(time);
            
            commandMessages=cell(numel(ids),1);
            for i=1:numel(ids)
                commandMessage=obj.TASKING_MESSAGE;
                commandMessage.command=commands{i};
                commandMessage.taskType=obj.TASKING_TYPE_COMMAND;
                commandMessage.time=time;
                commandMessage.taskableId = ids(i);
                commandMessage.taskerId = obj.id;
            
                taskingTopic=obj.getTaskingTopicForTaskable(ids(i));
                obj.publishToTopic(taskingTopic,commandMessage);
                commandMessages{i}=commandMessage;
                obj.addDefaultLogEntry(obj.TASKING_LOGGING_KEY,...
                    commandMessage);
            end
        end
        
        function periodicTasking(obj,time)
            
            obj.sendTaskingCommands(time);
            waitTime=obj.taskingFunction.getWaitTime();
            obj.scheduleAtTime(time+waitTime,@obj.periodicTasking);
        end
        
        function taskingAssessmentUpdateHandler(obj,time,messages)
            %handle assessment information
            if ~iscell(messages)
                messages={messages};
            end
            
            anyUpdates=0;
            for i=1:numel(messages)
                message=messages{i};
                obj.taskingFunction.addNewAssessments(message.ids,...
                    message.priorities,message.otherData);
                anyUpdates=1;
            end
            
            if anyUpdates == 1 && obj.taskingReactive==1
                obj.sendTaskingCommands(time);
            end
            
        end
        
        function taskingStatusUpdateRequest(obj,time)
            %request statuses
            updateRequest=obj.TASKING_MESSAGE;
            updateRequest.time=time;
            updateRequest.command=[];
            updateRequest.taskType=obj.TASKING_TYPE_STATUS;
            obj.publishToTopic(obj.taskingTopicAll,updateRequest);
            
            obj.scheduleAtTime(time+obj.taskingStatusPeriod,@obj.taskingStatusUpdateRequest);
        end
        
        function taskingStatusUpdateHandler(obj,~,messages)
            %handles tasking status updates
            if ~iscell(messages)
                messages={messages};
            end
            
            for i=1:numel(messages)
                message=messages{i};
                obj.taskingFunction.addTaskableAsset(message.time,message.id,...
                    message.otherData);
            end
            
        end
        
        
    end
    
    methods(Static)
        function child=enableChildTasking(obj,taskingFunction,taskableClass)
            %template for adding a tasking child
            assert(isa(obj,'publicsim.sim.Callee'),'Must be called from a Callee');
            %Redundant but put in to provide extra clues
            assert(isa(obj,'publicsim.agents.hierarchical.Parent'),'Must be called from a Parent');
            child=eval([taskingFunction '();']);
            assert(isa(child,'publicsim.funcs.taskers.Tasker'),'Child must inherit from Tasker');
            assert(isa(child,'publicsim.agents.hierarchical.Child'),'Child must be type Child');
            obj.addChild(child);
            child.enableTasking(child,taskableClass);
        end
    end
    
        %%%% TEST METHDOS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests = {};
        end
    end
end

