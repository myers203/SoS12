classdef Networked < publicsim.sim.Callee
    %NETWORKED Agent that participates in a communication network
    %
    % addToNetwork(clientSwitch,dataService) provide a unique clientSwitch at
    % orchestration (connected to the newtork) and the common dataService
    % for adding the agent to the network
    %
    % setNetworkName(name) sets the display name for network graphics
    %
    % topic=getDataTopic(type,subtype,subsubtype) returns a data topic with these
    % types
    %
    % subscribeToTopicWithCallback(topic,funcHandle) calls
    % funcHandle(time,messages{}) whenever a message is received to the
    % topic, where topic comes from getDataTopic
    %
    % [rxTopics,rxData]=getNewMessages() returns cell array of messages, if
    % any, where rxData is the payload and rxTopics is the topic for that
    % payload so that they can be separated by runAtTime
    %
    % publishToTopic(topic,message) sends message to the topic, where topic
    % is from getDataTopic
    
    properties(SetAccess=private)
        clientSwitch %funcs.comms.Switch instance
        dataClient %funcs.comms.DataClient instance
        subscribedTopics %List of topics subscribed to
        logMessagePayloads=0 %[0/1]: store payloads in logs
        logMessageMetrics=0 %[0/1]: store periodic agent-based network metrics
        netName='NETAGENT'; %Name for graphical display in network charts
        transmitId=1; %ID for logging transmitted messages
        
        upstreamNetworkIds=[]; %IDs used for publication topics
        downstreamNetworkIds=[]; %IDs used for implicit subscriptions for other agents topics
        extraSubscriptionIds=[]; %IDs used for extra, explicit subscription
        localNetworkId=1; %Unique local ID used for intra-agent topics
    end
    
    methods
        function obj=Networked()
        end
        
        function init(~)
            %Ignored/overloaded
        end
        
        function runAtTime(obj,time) %#ok<INUSD>
            %Ignored/overloaded
        end
        
        
        function addToNetwork(obj,clientSwitch,dataService)
            %Add the agent to the simluation network
            assert(~isempty(obj.instance),'Must be called after adding to instance');
            if isempty(clientSwitch.instance)
                obj.instance.AddCallee(clientSwitch);
                %warning('Client Switch not added to instance before added to network');
            end
            obj.clientSwitch=clientSwitch;
            obj.dataClient=publicsim.funcs.comms.DataClient(obj,clientSwitch,dataService);
            obj.instance.AddCallee(obj.dataClient);
        end
        
        function setNetworkName(obj,name)
            %set display name for network graphs
            obj.netName=name;
        end
        
        function topic=getDataTopic(obj,type,subtype,subsubtype)
            %returns a data topic based on type/subtype/subsubtype
            topic=obj.dataClient.getTopic(type,subtype,subsubtype);
        end
        
        function subscribeToTopicWithCallback(obj,topic,funcHandle)
            %subscription but with handle instead of runAtTime call
            obj.dataClient.subscribe(topic,funcHandle);
            obj.subscribedTopics{end+1}=topic;
        end
        
        function subscribeToTopic(obj,topic)
            %subscribe to topic (calls runAtTime, agent drains via
            %getNewMessages)
            funcHandle=[];
            obj.dataClient.subscribe(topic,funcHandle);
            obj.subscribedTopics{end+1}=topic;
        end
        
        function publishToTopic(obj,topic,message)
            %sends message to topic
            if obj.logMessagePayloads == 1
                message={message,obj.instance.Scheduler.currentTime};
                obj.logNetworkMessage(topic,message,1);
            end
            obj.dataClient.publish(topic,message);
        end
        
        function [rxTopics,rxData]=getNewMessages(obj)
            %returns messages received, if any
            [rxTopics,rxData]=obj.dataClient.getData();
            if obj.logMessagePayloads == 1
                for i=1:length(rxTopics)
                    tData=rxData{i};
                    rxData{i}=tData{1};
                    obj.logNetworkMessage(rxTopics{i},tData,0);
                end
            end
        end
        
        function logNetworkMessage(obj,topic,inData,transmitted)
            %save message to the log
            logTopic=obj.getLoggingTopic(['MSG:' topic.type],topic.subtype,topic.subsubtype);
            data.hostID=obj.id;
            data.transmitted=transmitted;
            if transmitted == 1
                data.transmitId=obj.transmitId;
                obj.transmitId=obj.transmitId+1;
            else
                data.transmitId=[];
            end
            data.message=inData{1};
            data.txTime=inData{2};
            data.logTime=obj.instance.Scheduler.currentTime;
            data.logVersion=1;
            obj.logToTopic(logTopic,data);
        end
        
        function addUpstreamNetworkId(obj,id)
            %adds upstream network ID
            obj.upstreamNetworkIds(end+1)=id;
        end
        
        function addDownstreamNetworkId(obj,id)
            %adds downstream network ID
            obj.downstreamNetworkIds(end+1)=id;
        end
        
        function addExplicitSubsciptionId(obj,id)
            %adds explicit subscription ID
            warning('Using deprecated method!');
            obj.addExplicitSubscriptionId(id)
        end
        
        function addExplicitSubscriptionId(obj,id)
            %adds explicit subscription ID
            warning('Using deprecated method!');
            obj.extraSubscriptionIds(end+1)=id;
        end
        
        function setLocalNetworkId(obj,id)
            %sets the local network id
            obj.localNetworkId=id;
        end
        
        function id=getLocalNetworkId(obj)
            %gets the local network id
            id=obj.localNetworkId;
        end
        
        function callee=findCalleeWithLocalNetworkId(obj,targetNetworkId)
            calleeList=obj.instance.getAllCallees();
            for i=1:numel(calleeList)
                callee=calleeList{i};
                if ~isa(callee,'publicsim.agents.base.Networked')
                    continue;
                end
                if callee.localNetworkId==targetNetworkId
                    return;
                end
            end
            callee=[];
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

