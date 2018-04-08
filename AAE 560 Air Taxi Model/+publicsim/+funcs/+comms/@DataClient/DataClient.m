classdef DataClient < publicsim.sim.Callee
    %DATACLIENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        clientSwitch
        parent
        dataService
        rxMessageList={}
        callbackRegistry
    end
    
    properties(Constant)
        CALLBACK_ENTRY=struct('topic',[],'callbackFunction',[]);
    end
    
    methods
        function obj=DataClient(parent,clientSwitch,dataService)
            clientSwitch.setParent(obj);
            obj.clientSwitch=clientSwitch;
            obj.dataService=dataService;
            obj.parent=parent;
        end
        
        function topic=getTopic(obj,type,subtype,subsubtype)
            topic=obj.dataService.getTopic(type,subtype,subsubtype);
        end
        
        function publish(obj,topic,message)
            obj.dataService.publishMessageToTopic(obj,topic,message);
        end
        
        function subscribe(obj,topic,funcHandle)
            if ~isempty(funcHandle)
                %Add a callback as time,message
                newCallback=obj.CALLBACK_ENTRY;
                newCallback.topic=topic;
                newCallback.callbackFunction=funcHandle;
                if isempty(obj.callbackRegistry)
                    obj.callbackRegistry=newCallback;
                else
                    obj.callbackRegistry(end+1)=newCallback;
                end
            end
            obj.dataService.subscribeToTopic(obj,topic);
        end
        
        function sendData(obj,topic,data,dest)
            obj.clientSwitch.sendMessage({topic,data},dest);
        end
        
        function [topic,message]=getData(obj)
            if isempty(obj.rxMessageList)
                topic={};
                message={};
                return;
            end
            topic=cell(length(obj.rxMessageList),1);
            message=cell(length(obj.rxMessageList),1);
            for i=1:length(obj.rxMessageList)
                data=obj.rxMessageList{i};
                topic{i}=data{1};
                message{i}=data{2};
                if isa(message{i},'publicsim.funcs.comms.Message')
                    message{i}=message{i}.getPayload();
                end
            end
            obj.rxMessageList={};
        end
        
        function [message] = getDataByTopic(obj,topic)
            if isempty(obj.rxMessageList)
                message={};
                return;
            end
            message={};
            keepIdx=[];
            for i=1:length(obj.rxMessageList)
                data=obj.rxMessageList{i};
                rxTopic=data{1};
                if obj.compareTopics(topic,rxTopic)
                    keepIdx(end+1)=i; %#ok<AGROW>
                    newData=data{2};
                    if isa(newData,'publicsim.funcs.comms.Message')
                        newData=newData.getPayload();
                    end
                    message{end+1}=newData; %#ok<AGROW>
                end
            end
            
            obj.rxMessageList(keepIdx)=[];
            
        end
        
        function runAtTime(obj,time)
            msgQueue=obj.clientSwitch.getMessageQueue();
            for i=1:length(msgQueue)
                obj.rxMessageList{end+1}=msgQueue{i};
            end
            if ~isempty(msgQueue)
                for i=1:numel(obj.callbackRegistry)
                    topic=obj.callbackRegistry(i).topic;
                    callback=obj.callbackRegistry(i).callbackFunction;
                    messages=obj.getDataByTopic(topic);
                    if ~isempty(messages)
                        callback(time,messages);
                    end
                end
                obj.parent.runAtTime(time);
            end
        end
    end
    
    methods(Static,Access=private)
        function matched=compareTopics(baseTopic,testTopic)
            matched=0;
            if ~isequal(baseTopic.type,testTopic.type)
                return;
            end
            if ~isempty(baseTopic.subtype) && ~isequal(baseTopic.subtype,testTopic.subtype)
                return;
            end
            if ~isempty(baseTopic.subsubtype) && ~isequal(baseTopic.subsubtype,testTopic.subsubtype)
                return;
            end
            matched=1;
        end
    end
    
end

