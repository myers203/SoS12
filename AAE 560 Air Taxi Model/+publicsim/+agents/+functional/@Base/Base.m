classdef Base < publicsim.agents.base.Networked
    %BASE Common functional agent code
    %   
    
    properties(SetAccess=protected)
        outputMessageTypes
        defaultMessageType
    end
    
    methods
        
        function obj=Base()
        end
        
        function publishToTopic(obj,topic,data)
            messageType=[];
            if ~isempty(obj.outputMessageTypes) && isKey(obj.outputMessageTypes,topic.type)
                messageType=obj.outputMessageTypes(topic.type);
            elseif ~isempty(obj.defaultMessageType)
                messageType=obj.defaultMessageType;
            end
            
            if ~isempty(messageType)
                newMessage=eval(messageType);
                newMessage.setPayload(data);
                publishToTopic@publicsim.agents.base.Networked(obj,topic,newMessage);
            else
                publishToTopic@publicsim.agents.base.Networked(obj,topic,data);
            end

        end
        
        function addMessageType(obj,topicKey,type)
            if isempty(obj.outputMessageTypes)
                obj.outputMessageTypes=containers.Map('KeyType','char','ValueType','any');
            end
            
            obj.outputMessageTypes(topicKey)=type;
        end
        
        function setDefaultMessageType(obj,type)
            obj.defaultMessageType=type;
        end
        
    end
    
end

