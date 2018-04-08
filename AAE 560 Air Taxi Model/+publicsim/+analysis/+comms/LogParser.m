function [  ] = LogParser( log )
%LOGPARSER Summary of this function goes here
%   Detailed explanation goes here

%{
log_path = './tmp/lmc/scenario1';
log=publicsim.sim.Logger(log_path);
log.restore();
publicsim.analysis.comms.LogParser(log);
%}

msgEntries=loadMsgData(log);

msgTopics=msgEntries.getAllTopics();
masterTopics=cell(numel(msgTopics),1);
for i=1:numel(msgTopics)
    topic=msgTopics{i};
    C=strsplit(topic,'/');
    masterTopics{i}=C{1};
end

masterTopics=unique(masterTopics);

%Get latency and data by topic
dt=1; %1 second windows
for i=1:numel(masterTopics)
    topic=masterTopics{i};
    allEntries=msgEntries.getChildObjects(topic);
    allEntriesStruct=allEntries{1};
    Afields=fieldnames(allEntriesStruct);
    for k=2:numel(allEntries)
        for j=1:numel(Afields)
            allEntriesStruct.(Afields{j})=[allEntriesStruct.(Afields{j}) allEntries{k}.(Afields{j})];
        end
    end
        
end

end

function msgEntries=loadMsgData(log)
    allTopics=log.getAllTopics();
    msgTopics={};
    for i=1:numel(allTopics)
        topic=allTopics{i};
        if strncmp(topic.type,'MSG:',4)==1
            msgTopics{end+1}=topic; %#ok<AGROW>
        end
    end

    msgEntries=publicsim.funcs.groups.TopicGroup();
    for i=1:numel(msgTopics)
        [~,data]=log.readFromTopic(msgTopics{i});
        data=data{1};
        entryTopic=[msgTopics{i}.type(5:end) '/' msgTopics{i}.subtype '/' msgTopics{i}.subsubtype];
        if entryTopic(end)=='/'
            entryTopic(end)=[];
        end
        if entryTopic(end)=='/'
            entryTopic(end)=[];
        end
        for k=1:numel(data)
            entry=data{k};
            msg.latency=getLatency(entry);
            msg.size=publicsim.funcs.comms.PointToPoint.calcMessageSize(entry.message);
            msg.time=entry.logTime;
            msg.id=[num2str(i) '-' num2str(k) ';'];
            if entry.transmitted==1
                msg.sendid=entry.hostID;
                msg.recvid=NaN;
            else
                msg.recvid=entry.hostID;
                msg.sendid=NaN;
            end
            msgEntries.appendToTopic(entryTopic,msg);
        end
    end
end

function latency=getLatency(logEntry)
    latency=NaN;
    if logEntry.logVersion==1
        latency=logEntry.logTime-logEntry.logTime;
    end
    
end
