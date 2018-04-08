classdef DataServiceCallee < publicsim.sim.Callee
    %DATASERVICECALLEE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        messageList={};
        messageTimes={};
        topicHistory={};
        sentTopics={};
        sentMessages={};
        dataClient;
        stopTime=100;
        sendPeriod=1;
        lastSendTime=-Inf;
        topics={};
        topic_list;
    end
    
    methods
        
        function obj=DataServiceCallee(clientSwitch,dataService,all_topics,topic_list)
            import publicsim.*;
            obj.dataClient=funcs.comms.DataClient(obj,clientSwitch,dataService);
            obj.topics=all_topics;
            obj.topic_list=topic_list;

            for i=1:length(topic_list)
                obj.dataClient.subscribe(obj.topics{topic_list(i)});
            end
        end
        
        function init(obj)
            obj.scheduleAtTime(0);
            obj.instance.AddCallee(obj.dataClient);
            obj.dataClient.init();
        end
        
        function runAtTime(obj,time)

            if (obj.lastSendTime+obj.sendPeriod)<=time && time < obj.stopTime
                obj.lastSendTime=time;
                obj.scheduleAtTime(time+obj.sendPeriod)
                junkData=randi(4,4);
                
                for i=1:length(obj.topic_list)
                    data={obj.id,obj.topic_list(i),junkData};
                    obj.dataClient.publish(obj.topics{obj.topic_list(i)},data);
                    obj.sentTopics{end+1}=obj.topics{obj.topic_list(i)};
                    obj.sentMessages{end+1}=data;
                end
            end
            
            [rxTopics,rxData]=obj.dataClient.getData();
            for i=1:length(rxTopics)
                obj.messageTimes{end+1}=time;
                obj.messageList{end+1}=rxData{i};
                obj.topicHistory{end+1}=rxTopics{i};
            end
        end
        
    end
    
end

