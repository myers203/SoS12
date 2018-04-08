classdef DataService < handle
    %DATASERVICE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        publishedTopics;
    end
    
    methods
        
        function obj=DataService()
            obj.publishedTopics=containers.Map('KeyType','char','ValueType','any');
        end
        
        function publishMessageToTopic(obj,dataClient,topic,message)
            orig_topic=topic;
            topic_key=evalc('topic');
            assert(isKey(obj.publishedTopics,topic_key),'Published Data to Non-existant Topic!');
            topic_data=obj.publishedTopics(topic_key);
            subscribers=topic_data.subscriberList;
            if ~isempty(topic.subsubtype)
                topic.subsubtype=[];
                topic_key=evalc('topic');
                if isKey(obj.publishedTopics,topic_key)
                    topic_data=obj.publishedTopics(topic_key);
                    subscribers=[subscribers,topic_data.subscriberList];
                end
            end
            if ~isempty(topic.subtype)
                topic.subtype=[];
                topic_key=evalc('topic');
                if isKey(obj.publishedTopics,topic_key)
                    topic_data=obj.publishedTopics(topic_key);
                    subscribers=[subscribers,topic_data.subscriberList];
                end
            end
            %Eliminate duplicates
            subscriberIdList=zeros(length(subscribers),1);
            for i=1:length(subscribers)
                subscriberIdList(i)=subscribers{i}.id;
            end
            [~,uniqueIdxs,~]=unique(subscriberIdList);
            obj.sendDataToTopic(dataClient,orig_topic,message,subscribers(uniqueIdxs));
            
        end
        
        function sendDataToTopic(obj,dataClient,topic,message,subscribers)
            topic_key=evalc('topic');
            if ~isKey(obj.publishedTopics,topic_key)
                return;
            end
            topic_data=obj.publishedTopics(topic_key);
            for i=1:length(subscribers)
                destDataClient=subscribers{i};
                destId=destDataClient.clientSwitch.myDestId;
                dataClient.sendData(topic,message,destId);
            end
            topic_data.lastMessage=message;
            topic_data.lastMessageSender=dataClient;
            obj.publishedTopics(topic_key)=topic_data;
        end
        
        function subscribeToTopic(obj,dataClient,topic)
            assert(~isempty(topic),'Called Topic Subscribe with Empty Topic!');
            topic_key=evalc('topic');
            if ~isKey(obj.publishedTopics,topic_key)
                obj.getTopic(topic.type,topic.subtype,topic.subsubtype);
            end
            topic_data=obj.publishedTopics(topic_key);
            if ~any(find(topic_data.subscriberList==dataClient))
                topic_data.subscriberList{end+1}=dataClient;
                if ~isempty(topic_data.lastMessage)
                    topic_data.lastMessageSender.sendData(topic,...
                        topic_data.lastMessage,...
                        dataClient.clientSwitch.myDestId);
                end
                obj.publishedTopics(topic_key)=topic_data;
            end
        end
        
        function topic=getTopic(obj,type,subtype,subsubtype)
            if isequal(subtype,'')
                subtype=[];
            end
            if isequal(subsubtype,'')
                subsubtype=[];
            end
            topic.type=type;
            topic.subtype=subtype;
            topic.subsubtype=subsubtype;
            topic_key=evalc('topic');
            if ~isKey(obj.publishedTopics,topic_key)
                topic_data.topic=topic;
                topic_data.lastMessage=[];
                topic_data.lastMessageSender=[];
                topic_data.subscriberList={};
                obj.publishedTopics(topic_key)=topic_data;
            end
        end
        
        
    end
    
    %%%%% TEST FUNCTIONS %%%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.comms.DataService.test_dataService';
        end
    end
    
    
    methods(Static)
        
        function matching=test_getMatchingMessages(topic,topics,messages)
            matching={};
            for i=1:length(topics)
                t=topics{i};
                if isequal(t,topic)
                    matching{end+1}=messages{i}; %#ok<AGROW>
                end
            end
        end
        
        function test_dataService()
            import publicsim.*;
            network=funcs.comms.Network.test_routing();
            tsim=publicsim.sim.Instance('./tmp');
            dataService=funcs.comms.DataService();
            src=9;
            dest=12;
            srcSw=network.switches(src);
            destSw=network.switches(dest);
            
            topics{1}=dataService.getTopic('TypeA','SubTypeA','SubSubTypeA');
            topics{2}=dataService.getTopic('TypeA','SubTypeA','SubSubTypeB');
            topics{3}=dataService.getTopic('TypeA','SubTypeA',[]);
            topics{4}=dataService.getTopic('TypeA','SubTypeB',[]);
            topics{5}=dataService.getTopic('TypeB','SubTypeA',[]);
            topics{6}=dataService.getTopic('TypeB',[],[]);
            
            
            topic_list=[1 3 6];
            src_dsc=tests.funcs.comms.DataServiceCallee(srcSw,dataService,topics,topic_list);
            topic_list=[1 2 5];
            dest_dsc=tests.funcs.comms.DataServiceCallee(destSw,dataService,topics,topic_list);
            
            
            switchKeys=keys(network.switches);
            for i=1:length(switchKeys)
                tsim.AddCallee(network.switches(switchKeys{i}));
            end
            tsim.AddCallee(src_dsc);
            tsim.AddCallee(dest_dsc);
            
            tsim.runUntil(0,Inf);
            
            %Topic 1:
            %Both send and receive
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{1},src_dsc.topicHistory,src_dsc.messageList);
            for i=1:length(msgs)
                data=msgs{i};
                data_sender=data{1};
                data_topic=data{2};
                assert(data_sender==dest_dsc.id,'Failed Topic Test');
                assert(data_topic==1,'Failed Topic Test');
            end
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{1},dest_dsc.topicHistory,dest_dsc.messageList);
            for i=1:length(msgs)
                data=msgs{i};
                data_sender=data{1};
                data_topic=data{2};
                assert(data_sender==src_dsc.id,'Failed Topic Test');
                assert(data_topic==1,'Failed Topic Test');
            end
            
            %Topic 2:
            %dest sends and src receives
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{2},src_dsc.topicHistory,src_dsc.messageList);
            for i=1:length(msgs)
                data=msgs{i};
                data_sender=data{1};
                data_topic=data{2};
                assert(data_sender==dest_dsc.id,'Failed Topic Test');
                assert(data_topic==2,'Failed Topic Test');
            end
            
            %Topic 3:
            %src sends and no one receives
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{3},dest_dsc.topicHistory,dest_dsc.messageList);
            assert(isempty(msgs),'Failed Topic Test');
            
            %Topic 4:
            %Unused?
            
            %Topic 5:
            %Dest sends and src receives
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{5},src_dsc.topicHistory,src_dsc.messageList);
            for i=1:length(msgs)
                data=msgs{i};
                data_sender=data{1};
                data_topic=data{2};
                assert(data_sender==dest_dsc.id,'Failed Topic Test');
                assert(data_topic==5,'Failed Topic Test');
            end
            
            %Topic 6 no one receives
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{6},src_dsc.topicHistory,src_dsc.messageList);
            assert(isempty(msgs),'Failed Topic Test');
            msgs=funcs.comms.DataService.test_getMatchingMessages(topics{6},dest_dsc.topicHistory,dest_dsc.messageList);
            assert(isempty(msgs),'Failed Topic Test');
            
        end
        
    end
    
end

