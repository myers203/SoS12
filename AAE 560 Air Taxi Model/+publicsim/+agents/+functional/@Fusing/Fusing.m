classdef Fusing < publicsim.agents.hierarchical.Child & publicsim.agents.functional.Base
    %FUSING functional provides information fusion function support
    %  supports funcs.fusers.Fuser. 
    %
    %   enableFusing(inputFuserType,inputFuserAlgorithm) enables fusing
    %   functionality; inputFuserAlgorithm is a string for a
    %   publicsim.funcs.fusing.Fuser, inputFuserType is one of the
    %   FUSER_TYPE_ constants
    %
    %   addFusingSourceId(sourceId) adds a subscription to sourceId as a
    %   subtype for input messages of type inputFuserType; for multiple
    %   sources, call this function multiple times
    %
    %   setFusingOutputGroupId(groupId) sets the publication subtype for
    %   the fusion messages
    
    properties
        fuser                   %publicsim.funcs.fuser.Fuser instance
        fuserType=publicsim.agents.functional.Fusing.FUSER_TYPE_OSM; %string type for fuser for output labeling
        fuserSourceType         %type of fuser (e.g., track or measurement)
        fuserSourceIds=[];      %source subtype ID for which to subscribe
        fuserOutputTopic        %data topic for output data
        fuserOutputGroupId=1    %subtype for output data topic
        fuserOutputPeriod=5;    %perioid for fusing output generation
        usePeriodicOutputs=0;   %on-demand as updated or periodic only
        trackUpdatedMap;        %Method for preventing re-TX of stale tracks
        fuserSourceTypeMap;
    end
    
    properties(Constant)
        FUSER_TYPE_OSM=1;       %type OSM
        FUSER_TYPE_TRACK=2;     %type Track
        FUSER_ALGORITHM_OSM='publicsim.funcs.trackers.BasicKalman(9)'; %default OSM fuser
        FUSER_ALGORITHM_TRACK='publicsim.funcs.fusers.MultiFuser(''publicsim.funcs.fusers.T2TFwoMnf'')'; %default track fuser
        FUSER_ALGORITHM_SELECTION_ONLY = 'publicsim.funcs.fusers.T2TSelector()'; %default selection fuser
        FUSER_SOURCE_OSM='Observation'; %string type for subscription when fusing osm
        FUSER_SOURCE_TRACK='Track'; %string type for subscription when fusing tracks
        FUSING_LOGGING_KEY='Fusing'; %key for disk storage
        FUSING_OUTPUT_MESSAGE=struct('time',[],'ids',[],... %output message
            'otherData',[]); 
        FUSING_MESSAGE_TYPE='FusedTracks'; %output message type
        FUSER_MESSAGE_DEFAULT=-1;
    end
    
    methods
        
        function obj=Fusing()
        end
        
        function enableFusing(obj,inputFuserType,inputFuserAlgorithm)
            %turn on fusing functionality
            if nargin >= 2 && ~isempty(inputFuserType)
                obj.fuserType=inputFuserType;
            end
            if nargin >= 3 && ~isempty(inputFuserAlgorithm)
                fuserAlgorithm=inputFuserAlgorithm;
            elseif obj.fuserType==obj.FUSER_TYPE_OSM
                fuserAlgorithm=obj.FUSER_ALGORITHM_OSM; %#ok<NASGU>
                error('OSM Fusing Not Implemented');
            else % obj.fuserType==obj.FUSER_TYPE_TRACK
                fuserAlgorithm=obj.FUSER_ALGORITHM_TRACK;
            end
            if obj.fuserType==obj.FUSER_TYPE_OSM
                obj.fuserSourceType=obj.FUSER_SOURCE_OSM;
            else
                obj.fuserSourceType=obj.FUSER_SOURCE_TRACK;
            end
            obj.fuser=eval(fuserAlgorithm);
            obj.addFusingSourceId(obj.groupId);
            obj.rebuildFusingTopics();
            obj.trackUpdatedMap=containers.Map('KeyType','int64','ValueType','any');
            obj.scheduleAtTime(0,@obj.fusingPeriodicOutput);
        end
        
        function overrideFusingAlgorithm(obj,algorithmString)
            obj.fuser=eval(algorithmString);
        end
        
        function addFusingSourceId(obj,sourceId,sourceMessageType)
            %add a subtype key to the list of sources for subscription
            obj.fuserSourceIds(end+1)=sourceId;
            obj.fuserSourceIds=unique(obj.fuserSourceIds);
            if isempty(obj.fuserSourceTypeMap)
                obj.fuserSourceTypeMap=containers.Map('KeyType','int64','ValueType','any');
            end
            if nargin >= 3 && ~isempty(sourceMessageType)
                obj.fuserSourceTypeMap(sourceId)=sourceMessageType;
            else
                obj.fuserSourceTypeMap(sourceId)=obj.FUSER_MESSAGE_DEFAULT;
            end
        end
        
        function setFusingOutputGroupId(obj,groupId)
            %set the output group id
            obj.fuserOutputGroupId=groupId;
            if ~isempty(obj.fuserOutputTopic)
                obj.fuserOutputTopic=obj.getDataTopic(...
                    obj.FUSING_MESSAGE_TYPE,...
                    num2str(obj.fuserOutputGroupId),...
                    num2str(obj.id));
            end
        end
        
        function rebuildFusingTopics(obj)
            %re-generate the fusing topics
            if numel(obj.fuserSourceIds)==1
                 warning('No external fusion sources added! Only using local track data (single source).');
            end
            for i=1:numel(obj.fuserSourceIds)
                sourceGroupId=obj.fuserSourceIds(i);
                inputMessageType=obj.fuserSourceType;
                if ~isempty(obj.fuserSourceTypeMap) && isKey(obj.fuserSourceTypeMap,sourceGroupId)
                    newInputMessageType=obj.fuserSourceTypeMap(sourceGroupId);
                    if newInputMessageType ~= obj.FUSER_MESSAGE_DEFAULT
                        inputMessageType=newInputMessageType;
                    end
                end
                sourceTopic=obj.getDataTopic(...
                    inputMessageType,...
                    num2str(sourceGroupId),...
                    '');
                obj.subscribeToTopicWithCallback(sourceTopic,...
                @obj.fusingInputMessageHandler);
            end
            obj.fuserOutputTopic=obj.getDataTopic(...
                obj.FUSING_MESSAGE_TYPE,...
                num2str(obj.fuserOutputGroupId),...
                num2str(obj.id));
            
        end
        
        function fusingInputMessageHandler(obj,time,messages)
            %handle fusing input data
            if ~iscell(messages)
                messages={messages};
            end
            
            
            if obj.fuserType==obj.FUSER_TYPE_TRACK
                for i=1:numel(messages)
                    message=messages{i};
                    if isfield(message,'otherData') % Coming from a fuser
                        for j=1:numel(message.otherData.serializedTracks)
                            tso=message.otherData.serializedTracks{j};
                            trackId=message.ids{j};
                            tracker=eval(message.otherData.trackTypes{j});
                            tracker=tracker.deserialize(tso);
                            actualUpdatedTrack=obj.fuser.multiUpdateTrack(trackId,message.sourceId,tracker);
                            obj.trackUpdatedMap(actualUpdatedTrack)=1;
                        end
                    else
                        for j=1:numel(message.trackSerialObjects)
                            tso=message.trackSerialObjects{j};
                            trackId=tso{1};
                            tso=tso{2};
                            tracker=eval(message.filterType);
                            tracker=tracker.deserialize(tso);
                            actualUpdatedTrack=obj.fuser.multiUpdateTrack(trackId,message.sourceId,tracker);
                            obj.trackUpdatedMap(actualUpdatedTrack)=1;
                        end
                    end
                end
            end
            if obj.usePeriodicOutputs == 0 && any(cell2mat(values(obj.trackUpdatedMap))==1)
                obj.sendFusingOutputs(time);
            end
        end
        
        function sendFusingOutputs(obj,time)
            [allTracks,ids]=obj.fuser.getAllTracks(time);
            serializedTracks=cell(numel(allTracks),1);
            trackTypes=cell(numel(allTracks),1);
            txIds=1:numel(allTracks);
            for i=1:numel(allTracks)
                if isKey(obj.trackUpdatedMap,ids{i}) && obj.trackUpdatedMap(ids{i}) == 0
                    txIds(txIds==i)=[];
                    continue;
                else
                    track=allTracks{i};
                    serializedTracks{i}=track.serialize();
                    trackTypes{i}=class(track);
                    obj.trackUpdatedMap(ids{i})=0;
                end
            end
            
            fusingMessage=obj.FUSING_OUTPUT_MESSAGE;
            fusingMessage.time=time;
            fusingMessage.ids=ids(txIds);
            fusingMessage.sourceId=obj.id;
            otherData.serializedTracks=serializedTracks(txIds);
            otherData.trackTypes=trackTypes(txIds);
            fusingMessage.otherData=otherData;
            obj.publishToTopic(obj.fuserOutputTopic,fusingMessage);
            
            obj.addDefaultLogEntry(obj.FUSING_LOGGING_KEY,fusingMessage);
        end
        
        function fusingPeriodicOutput(obj,time)
            %periodicaly operate the fusion algorithm and produce outputs
            if obj.usePeriodicOutputs==0
                return;
            end
            obj.sendFusingOutputs(time);            
            obj.scheduleAtTime(time+obj.fuserOutputPeriod,@obj.fusingPeriodicOutput);
        end
        
    end
    
end

