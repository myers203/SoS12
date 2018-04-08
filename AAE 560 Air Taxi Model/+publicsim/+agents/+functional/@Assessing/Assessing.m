classdef Assessing < publicsim.agents.base.Periodic & publicsim.agents.functional.Base & publicsim.agents.hierarchical.Child
    %ASSESSING provides agent operations for assessors
    %   The assessing functional incorporates an assessor function and
    %   links it to data sources and publishes its results. Inputs to this
    %   functional should publish to the subtype of the groupId
    %
    %   enableAssessing(assessorFunction,assessorType) where
    %   assessorFunction is a string name for a particular
    %   publicsim.funcs.assessors.Assessor and assessorType is a string key
    %   for the type of information to output (e.g., 'track')
    %
    %   setAssessingGroupId(id) sets the subtype of the output and the
    %   input messages to the particular ID. 
    
    properties(SetAccess=private)
        assessorFunction    %instance of funcs.assessors.Assessor
        assessorType        %string name for assessor function
        assessingGroupId=1; %ID for message subtype
        assessmentsTopic    %data topic for assessments
        assessmentsInputTopic %data topic for input information
    end
    
    properties(SetAccess=protected)
        assessingInputMessageType=publicsim.agents.functional.Fusing.FUSING_MESSAGE_TYPE; %type of message to subscribe to for input data
    end
    
    properties(Constant)
        ASSESSING_LOGGING_KEY='Assessment'   %key for storing to disk
        ASSESSING_MESSAGE_PREFIX='Assessed-' %prefix for data output type
        %ASSESSING_INPUT_MESSAGE_PREFIX='ASSESS-INP-'
        ASSESSING_MESSAGE=struct(... %Message structure for assessments
            'time',[],...
            'ids',[],...
            'priorities',[],...
            'otherData',[]);               
        ASSESSING_INPUT_MESSAGE=struct(... %Message structure for input data
            'time',[],...
            'ids',[],...
            'otherData',[]);                
    end
    
    methods
        
        function obj=Assessing()
        end
        
        function setAssessingGroupId(obj,id)
            %sets the group ID for the assessment output subtype
            obj.assessingGroupId=id;
            if ~isempty(obj.assessmentsTopic)
                obj.rebuildAssessingTopics();
            end
        end
        
        function enableAssessing(obj,assessorFunction,assessorType)
            %enable assessment functionality
            obj.assessorFunction = eval([assessorFunction '();']);
            obj.assessorType=assessorType;
            obj.rebuildAssessingTopics();
            obj.scheduleAtTime(0,@obj.generatePeriodicAssessments);
        end
        
        function rebuildAssessingTopics(obj)
            %re-create data topics, important if ID's change
            obj.assessmentsTopic=obj.getDataTopic(...
                [obj.ASSESSING_MESSAGE_PREFIX obj.assessorType],...
                num2str(obj.assessingGroupId),...
                num2str(obj.id));
            obj.assessmentsInputTopic=obj.getDataTopic(...
                obj.assessingInputMessageType,...
                num2str(obj.assessingGroupId),...
                '');
            obj.subscribeToTopicWithCallback(obj.assessmentsInputTopic,...
                @obj.assessmentInputHandler);
        end
        
        function assessmentInputHandler(obj,time,messages)
            %handle incoming data
            if ~iscell(messages)
                messages={messages};
            end
            
            for i=1:numel(messages)
                message=messages{i};
                if ~isfield(message,'otherData') %assume its a track for now
                    otherData=[];
                    for j=1:numel(message.trackSerialObjects)
                        otherData.serializedTracks{j}=message.trackSerialObjects{j}{2};
                        splitString=strsplit(message.filterType,'(');
                        otherData.trackTypes{j}=splitString{1};
                    end
                    message.otherData=otherData;
                end
                obj.assessorFunction.updateAssessorData(...
                    message.time,...
                    message.ids,...
                    message.otherData);
            end
            
            %reactive assessment outputs
            obj.generateAssessments(time);
        end
        
        function generateAssessments(obj,time)
            %create output assessments from input data
            [ids,priorities,otherData]=...
                obj.assessorFunction.getPriorities(time);
            
            if isempty(priorities) % Not really a reason to log a message if there's nothing in it.
                return
            end
            
            assessingMessage=obj.ASSESSING_MESSAGE;
            assessingMessage.time=time;
            assessingMessage.ids=ids;
            assessingMessage.priorities=priorities;
            assessingMessage.otherData=otherData;
            
            obj.publishToTopic(obj.assessmentsTopic,assessingMessage);
            obj.addDefaultLogEntry(obj.ASSESSING_LOGGING_KEY,...
                assessingMessage);
        end
        
        function generatePeriodicAssessments(obj,time)
            %periodically generate assessments
            obj.generateAssessments(time);
            
            waitTime=obj.assessorFunction.getWaitTime();
            obj.scheduleAtTime(time+waitTime,@obj.generatePeriodicAssessments);
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

