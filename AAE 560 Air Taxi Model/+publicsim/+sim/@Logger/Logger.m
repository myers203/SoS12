classdef Logger < handle
    %LOGGER File I/O handler for log reading and writing
    %   The logger manages all disk-based storage of information for the
    %   simulation. Loggables should interface with the logger for r/w
    
    properties
        showLinesInDisp=1; %Show traceback of line displaying warning
    end
    
    properties(SetAccess=private)
        rootPath %Root file path where all log files are stored
    end
    
    
    properties(Access=private,Transient=true)
        topicMap %Map between topics and files
        nextTopicIdx=0; %progressive index for the topic map
        blockNewTopics=0; %in read-only mode, do not create new topics automatically
    end
    
    properties(Constant=true)
        log_DEBUG=5
        log_INFO=4
        log_WARN=3
        log_ERROR=2
        log_FATAL=1
        entryBufferSize=300 %number of writes before a flush to the disk
    end
    
    methods
        function obj = Logger(rootPath)
            %Creates a new logger--for use by Instance
            obj.rootPath=rootPath;
            if ~(exist(rootPath,'dir'))
                mkdir(rootPath);
            end
            obj.topicMap=containers.Map('KeyType','char','ValueType','any');
        end
        
        function fini(obj)
            %Close and save all partial topics
            topicList=values(obj.topicMap);
            for i=1:length(topicList)
                topic_data=topicList{i};
                topic=topic_data.topic;
                obj.flushTopic(topic);
            end
            savedTopicMap=obj.topicMap; 
            save([obj.rootPath '/topic_root.mat'],'savedTopicMap','-v7');
        end
        
        function topics=getAllTopics(obj)
            %Gets list of all used topics 
            valueList=values(obj.topicMap);
            topics=cell(length(valueList),1);
            for i=1:length(valueList)
                topic_data=valueList{i};
                topics{i}=topic_data.topic;
            end
        end
                
        
        function restore(obj)
            %loads from the disk the list of topics and disables writing to
            %the data
            dataIn=load([obj.rootPath '/topic_root.mat']);
            obj.topicMap=dataIn.savedTopicMap;
            obj.blockNewTopics=1;
        end
        
        function [topics,entries]=readFromTopic(obj,topic)
            %Retreives information stored to the particular topic key
            allTopics=obj.getAllTopics();
            topics={};
            for i=1:length(allTopics)
                testTopic=allTopics{i};
                if isequal(testTopic.type,topic.type)
                    if isequal(testTopic.subtype,topic.subtype) || isempty(topic.subtype)
                        if isequal(testTopic.subsubtype,topic.subsubtype) || isempty(topic.subsubtype)
                            topics{end+1}=testTopic; %#ok<AGROW>
                        end
                    end
                end
            end
            
            entries=cell(length(topics),1);
            for i=1:length(topics)
                testTopic=topics{i};
                entries{i}=obj.getEntriesFromFile(testTopic);
            end
        
        end
        
        function entries=getEntriesFromFile(obj,topic)
            %Each file corresponds to a different topic, and this reads the
            %entries for that topic from the file
            entries={};
            topic_key=evalc('topic');
            assert(isKey(obj.topicMap,topic_key),'Reading from Non-Existant Topic!');
            topic_data=obj.topicMap(topic_key);
            inputData=load([topic_data.fileID '.mat']);
            assert(isequal(topic,inputData.topic),'File Mismatch!');
            for i=1:topic_data.lastEntryIdx-1
                entry_name=sprintf('entry_%4.4d',i);
                file_name=[topic_data.fileID '_' entry_name '.bin'];
                %fid=fopen(file_name,'r');
                %data=fread(fid);
                %fclose(fid);
                tmpData=load(file_name,'-mat');
                newEntries=getArrayFromByteStream(tmpData.data);
                entries=[entries; newEntries]; %#ok<AGROW>
            end
        end
        
        function topic = getTopic(obj,type,subtype,subsubtype)
            %Returns a topic handle and creates a topic entry in the topic
            %map so future references to the topic go to the same file
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
            if ~isKey(obj.topicMap,topic_key) && obj.blockNewTopics == 0
                topic_data.topic=topic;
                topic_idx=obj.nextTopicIdx+1;
                obj.nextTopicIdx=topic_idx;
                fileID=sprintf('%s/topic_%3.3d',obj.rootPath,topic_idx);
                topic_data.fileID=fileID;
                topic_data.topicIdx=topic_idx;
                topic_data.lastEntryIdx=0;
                topic_data.entryBuffer=cell(obj.entryBufferSize,1);
                topic_data.lastBufferIdx=0;
                save([fileID '.mat'],'topic','-v7');
                obj.topicMap(topic_key)=topic_data;
            end
        end
        
        function writeToTopic(obj,topic,data)
            %write data to the pre-created topic
            topic_key=evalc('topic');
            assert(isKey(obj.topicMap,topic_key),'Writing to Non-Existant Topic!');
            topic_data=obj.topicMap(topic_key);
            bufferIdx=topic_data.lastBufferIdx+1;
            topic_data.lastBufferIdx=bufferIdx;
            topic_data.entryBuffer{bufferIdx}=data;
            obj.topicMap(topic_key)=topic_data;
            if bufferIdx == obj.entryBufferSize
                obj.flushTopic(topic);
            end
            
        end
        
        function flushTopic(obj,topic) %#ok<INUSD,*NASGU>
            %Writes the topic to the disk
            topic_key=evalc('topic');
            assert(isKey(obj.topicMap,topic_key),'Writing to Non-Existant Topic!');
            topic_data=obj.topicMap(topic_key);
            entryIdx=topic_data.lastEntryIdx+1;
            topic_data.lastEntryIdx=entryIdx;
            if (topic_data.lastBufferIdx ~= obj.entryBufferSize)
                data=topic_data.entryBuffer(1:topic_data.lastBufferIdx); %#ok<*NASGU>
            else
                data=topic_data.entryBuffer; %#ok<*NASGU>
            end
            topic_data.lastBufferIdx=0;
            topic_data.entryBuffer=cell(obj.entryBufferSize,1);
            obj.topicMap(topic_key)=topic_data;
            
            entry_name=sprintf('entry_%4.4d',entryIdx);
            file_name=[topic_data.fileID '_' entry_name '.bin'];
            %newData.(entry_name) = data; %#ok
            data=getByteStreamFromArray(data);
            save(file_name,'data','-v6','-mat');
            %eval([entry_name '=data;']);
            %fid=fopen(file_name,'W');
            %fwrite(fid,data);
            %fclose(fid);
            %tic;
            %save(file_name,entry_name,'-append');
            %saveTime=toc;

            %save(topic_data.fileID, '-struct', 'newData', '-append');
        end
        
    end
    
    methods(Static)
        
        function test_Logger()
            import publicsim.*;
            tlog=sim.Logger('./tmp/test');
            t1=tlog.getTopic('TypeA','SubTypeB','');
            t2=tlog.getTopic('TypeA','','');
            junkData=rand(10,10);
            tic
            for i=1:10000
                tlog.writeToTopic(t1,junkData);
            end
            for i=1:100
                tlog.writeToTopic(t2,junkData);
            end
            t=toc;
            disp(['Time to Save: ' num2str(t)]);
            tlog.fini();
            
            clear tlog;
            
            tic;
            tlog=sim.Logger('./tmp/test');
            tlog.restore();
            tlist=tlog.getAllTopics();
            [topics,entries]=tlog.readFromTopic(t1);
            assert(isequal(length(topics),1),'Error Loading Data');
            assert(isequal(length(entries),1),'Error Loading Data');
            assert(isequal(length(entries{1}),10000),'Error Loading Data');
            assert(isequal(entries{1}{5},junkData),'Error Loading Data');
            
            [topics,entries]=tlog.readFromTopic(t2);
            assert(isequal(length(topics),2),'Error Loading Data');
            assert(isequal(length(entries),2),'Error Loading Data');
            assert(isequal(10100,length(entries{1})+length(entries{2})),'Error Loading Data');
            t=toc;
            disp(['Time to Load: ' num2str(t)]);
            
            disp('Passed Logging Tests');
            
        end
    end
    
    
end

