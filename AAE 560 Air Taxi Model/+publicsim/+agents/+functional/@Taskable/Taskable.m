classdef Taskable < publicsim.agents.functional.Base
    %TASKABLE implements support for taskable agents
    %   Used for integration with funcs.taskers.Taskable. Implementing
    %   agent must have getTaskableStatus and processTaskableCommand
    %   abstracts implemented
    %
    %   setTaskableGroupId(id) sets the subtopic key for both command and
    %   status inputs and outputs
    %
    %   enableTaskable(taskableType,commandCallback,statusFunction)
    %   taskableType as e.g. 'sensor', commandCallback as the function
    %   handle for processing a command, and statusFunction as the function
    %   handle for processing a status request. By default, a taskable
    %   sensor calls this function automatically
    %
    %   
    
    properties
        inputTaskingTopic           %topic that commands are RX over
        outputTaskingStatusTopic    %topic that status is sent over
        taskableType                %string for taskable type
        taskingCallbackCommand      %taskable function handle for command processing
        taskingStatusCommand        %taskable function handle for status processing
        taskableGroupId=1           %subtype for both command and status message topics
    end
    
    properties(Constant)
        TASKABLE_STATUS_LOGGING_KEY='TaskableStatus'; %key for status output topic
        TASKABLE_COMMAND_LOGGING_KEY='TaskableCommand'; %key for command input topic
    end
    
    methods
        
        function obj=Taskable()
        end
        
        function setTaskableGroupId(obj,groupId)
            %set the subtype for message topics
            if ~isempty(obj.inputTaskingTopic)
                warning('Must set taskable ID BEFORE Enabling');
            end
            obj.taskableGroupId=groupId;
            %obj.rebuildTaskableTopics();
        end
        
        function enableTaskable(obj,taskableType,commandCallback,statusFunction)
            %enable taskable agent operations
            obj.taskingCallbackCommand=commandCallback;
            obj.taskingStatusCommand=statusFunction;
            obj.taskableType=taskableType;
            obj.rebuildTaskableTopics();
        end
        
        function rebuildTaskableTopics(obj)
            %rebuild input/output topics
            obj.inputTaskingTopic=obj.getDataTopic(...
                [ publicsim.agents.functional.Tasking.TASKING_MESSAGE_PREFIX obj.taskableType],...
                num2str(obj.taskableGroupId),...
                num2str(obj.id));
            obj.subscribeToTopicWithCallback(obj.inputTaskingTopic,...
                @obj.taskableCommandReceived);
            inputTaskingTopicBroadcast=obj.getDataTopic(...
                [ publicsim.agents.functional.Tasking.TASKING_MESSAGE_PREFIX obj.taskableType],...
                num2str(obj.taskableGroupId),...
                publicsim.agents.functional.Tasking.TASKING_COMMAND_ALL_SUBSUBTYPE);
            obj.subscribeToTopicWithCallback(inputTaskingTopicBroadcast,...
                @obj.taskableCommandReceived);
            
            obj.outputTaskingStatusTopic=obj.getDataTopic(...
                [publicsim.agents.functional.Tasking.TASKING_STATUS_PREFIX obj.taskableType],...
                num2str(obj.taskableGroupId),...
                num2str(obj.id));
        end
        
        function taskableStatusMessageProcess(obj,time,message) %#ok<INUSD>
            %process status message
            
            %message itself is implicit in the command type (send status)
            statusMessage=publicsim.agents.functional.Tasking.TASKING_STATUS_MESSAGE;
            statusMessage.time=time;
            statusMessage.id=obj.id;
            statusMessage.otherData=obj.taskingStatusCommand(time);
            
            obj.publishToTopic(obj.outputTaskingStatusTopic,statusMessage);
            obj.addDefaultLogEntry(obj.TASKABLE_STATUS_LOGGING_KEY,...
                statusMessage);
        end
        
        function taskableCommandMessageProcess(obj,time,message)
            %process command message
            obj.taskingCallbackCommand(time,message.command);
        end
        
        function taskableCommandReceived(obj,time,messages)
            %handle incoming messages
            if ~iscell(messages)
                messages={messages};
            end
            
            for i=1:numel(messages)
                message=messages{i};
                if message.taskType==publicsim.agents.functional.Tasking.TASKING_TYPE_STATUS
                    obj.taskableStatusMessageProcess(time,message);
                elseif message.taskType==publicsim.agents.functional.Tasking.TASKING_TYPE_COMMAND
                    obj.taskableCommandMessageProcess(time,message);
                end
            end
            
        end
    end
    
    methods(Abstract)
        status=getTaskableStatus(obj,time)
        processTaskableCommand(obj,time,command)
    end
        
end

