classdef NetworkedObserver < publicsim.agents.base.Networked
    %NETWORKEDOBSERVER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        msgTopic
        logTopic
    end
    
    properties(Constant)
        messagingTopic='Observation';
        logTopicKey='observer';
    end
    
    methods
        function obj=NetworkedObserver()
        end
        
        function init(obj)
            obj.logTopic=obj.getLoggingTopic(obj.logTopicKey,'','');
            obj.msgTopic=obj.getDataTopic(obj.messagingTopic,'','');
            obj.subscribeToTopic(obj.msgTopic);
        end
        
        function runAtTime(obj,time)
            [topics,msgs]=obj.getNewMessages();
            if ~isempty(topics)
                for i=1:length(topics)
                    if topics{i}.type ~= obj.messagingTopic
                        obj.disp_WARN('Mismatched topic RX');
                        continue;
                    end
                    msg=msgs{i};
                    logData={time,topics{i},msg};
                    obj.logToTopic(obj.logTopic,logData);
                end
            end
                
        end
    end
    
end

