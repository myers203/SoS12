classdef Tracking < publicsim.agents.functional.Base & publicsim.agents.physical.Worldly
    %TRACKING functional implementation for tracking
    %   Agent for publicsim.funcs.trackers.Tracker
    %
    %   setTrackObservationMessageKeys(topicKey,groupId) sets the type and
    %   subtype for input observation messages
    %
    %   setTrackObservationGroupId(groupId) set the input observation key
    %   subtype
    %
    %   setTrackMessageKeys(topicKey,groupId) where the topicKey is the
    %   type, and groupId is the subtype for output 
    %
    %   trackingEnableRemoteSensing() connect tracker to external source
    %
    %   enableTracking(trackerType) where trackerType is a string for the
    %   publicsim.funcs.trackers.Tracker
    
    properties(SetAccess=private)
        trackDatabase               %Database of track objects
        trackObservationGroupId=1;  %subtype ID for observation subscription
        trackObservationTopicKey='Observation'; %message type key for observation subscription
        trackTopicKey='Track';      %output topic type
        trackGroupId=1;             %output topic subtype
        trackingIsRemote=0;         %tracker separate from observer
        transmitTracks=0;           %trasnmit track messages
        provideGroundTruth=0;       %provide ground truth data to the tracker (used for particle filter tuning?)
        trackingOracle              %Used to provide ground truth data, if needed
        trackerType                 %Type of template tracker used, set internally
        enableNonIdealAssociation=0;%Enable/Diable non-ideal association
        missAssociationProb=0.99;      %Non-ideal assocaition probability
    end
    
    properties(Access=private)
        trackingMessageTopic        %topic for track message outputs
        observationMessageTopic     %topic for observation inputs
    end
    
    properties(Constant)
        TRACK_LOGGING_KEY='Tracks'; %key for disk storage of logs
        TRACK_MESSAGE=struct('time',[],'ids',[],'sourceId',[],... %message structure for track output
            'trackSerialObjects',[],...
            'filterType',[],...
            'databaseSerialObject',[]);
    end
    
    methods
        
        function obj=Tracking()
        end
        
        function setTrackObservationMessageKeys(obj,topicKey,groupId)
            %set the input observation topic type, subtype
            obj.trackObservationGroupId=groupId;
            obj.trackObservationTopicKey=topicKey;
        end
        
        function setTrackObservationGroupId(obj,groupId)
            %set input observation topic subtype
            obj.trackObservationGroupId=groupId;
        end
        
        function setTrackMessageKeys(obj,topicKey,groupId)
            %set track output topic type and subtype
            if ~isempty(groupId)
                obj.trackGroupId=groupId;
            end
            if ~isempty(topicKey)
                obj.trackTopicKey=topicKey;
            end
            if ~isempty(obj.trackDatabase)
                obj.rebuildTrackingMessageTopic();
            end
        end
        
        function rebuildTrackingMessageTopic(obj)
            %create topic for track outputs
            obj.trackingMessageTopic=obj.getDataTopic(...
                obj.trackTopicKey,...
                num2str(obj.trackGroupId),...
                num2str(obj.id));
        end
        
        function trackingEnableRemoteSensing(obj)
            %enable subscription to remote observation messages
            obj.trackingIsRemote=1;
            templateTracker=eval(obj.trackerType);
            inputType=templateTracker.getInputType();
            obj.observationMessageTopic=obj.getDataTopic(...
                [obj.trackObservationTopicKey '-' inputType],...
                num2str(obj.trackObservationGroupId),...
                '');
            obj.subscribeToTopicWithCallback(obj.observationMessageTopic,...
                @obj.trackingObservationMessageHandler);
        end
        
        function enableTracking(obj,trackerType)
            %enable tracking function
            obj.trackDatabase=publicsim.funcs.databases.TrackDatabase(trackerType);
            obj.trackerType=trackerType;
            templateTracker=eval(trackerType);
            if ~obj.trackingIsRemote && isa(obj,'publicsim.agents.functional.Sensing')
                inputType=templateTracker.getInputType();
                obj.registerSensorCallbackFunc(@obj.trackingObservationMessageHandler,inputType);
            end
            obj.rebuildTrackingMessageTopic();
            if templateTracker.requiresGroundTruth() == 1
                obj.provideGroundTruth=1;
            end
            if obj.provideGroundTruth == 1
                obj.trackingOracle=publicsim.funcs.oracles.Observables(obj.instance);
            end
        end
        
        function trackingObservationMessageHandler(obj,time,messages)
            %handle observation messages and generate track output messages
            assert(~isempty(obj.trackDatabase),'Tracking Not Initialized!');
            
            if ~iscell(messages)
                messages={messages};
            end
            
            if obj.provideGroundTruth==1
                [spatials,movableIds, observables]=obj.trackingOracle.getSpatials();
            end
           
            updatedIds=[];
            currentTracks = values(obj.trackDatabase.map);
            currentTracksKeys = cell2mat(keys(obj.trackDatabase.map));
            for i=1:numel(messages)
                observations=messages{i};
                for j=1:numel(observations.ids)
                    obsId = observations.ids(j);
                    obsData.measurements = observations.measurements(j,:);
                    if any(isnan(obsData.measurements))
                        continue;
                    end
                    
                  
                    obsData.time = observations.time;
                    obsData.errors = observations.errors(j,:);
                    obsData.sensorId = observations.sensorId;
                    obsData.sensorPosition = observations.sensorPosition;
                    obsData.sensorOrientation = observations.sensorOrientation;
                    obsData.trueId = obsId;
                    
                    if obj.enableNonIdealAssociation && any(find(currentTracksKeys == obsId))
                        % Miss correlation not used while initalizing a track
                        
                        obsToTrackId = nonIdealAssociation(obj,currentTracks,obsId,obsData);
                    else
                        obsToTrackId = obsId;
                    end
                    
                    updatedIds=[updatedIds, obsToTrackId]; %#ok<AGROW>
                    
                    obj.trackDatabase.updateMap(obsToTrackId,obsData);
                    if obj.provideGroundTruth==1
                        track=obj.trackDatabase.map(obsId);
                        spatial=spatials{movableIds==obsId};
                        observable=observables{movableIds==obsId};
                        track.processGroundTruth(time,spatial,obsData,observable);
                    end
                    
                    % NOTE FOR DOPPLER SHIFTING: Do separation within the
                    % track database!
                end
            end
            
            updatedIds = unique(updatedIds);
            [allTracks,allIds]=obj.trackDatabase.serialize();
            allIds=cell2mat(allIds);

            updatedTracksMessage=obj.TRACK_MESSAGE;
            updatedTracksMessage.time=time;
            updatedTracksMessage.ids=updatedIds;
            updatedTracksMessage.trackSerialObjects=cell(numel(updatedIds),1);
            for j=1:numel(updatedIds)
                updatedTracksMessage.trackSerialObjects(j)=allTracks(allIds==updatedIds(j));
            end
%             for j=1:numel(updatedTracksMessage.trackSerialObjects)
%                 tmp=lmc.funcs.trackers.ABTTracker_KF.deserialize(updatedTracksMessage.trackSerialObjects{j}{2});
%                 offset=time-tmp.t
%             end
            updatedTracksMessage.filterType=obj.trackDatabase.filter_type;
            updatedTracksMessage.sourceId=obj.id;
            updatedTracksMessage.databaseSerialObject=[];
            obj.publishToTopic(obj.trackingMessageTopic,updatedTracksMessage);
            
%             allTracksMessage=obj.TRACK_MESSAGE;
%             allTracksMessage.time=time;
%             allTracksMessage.ids=allIds;
%             allTracksMessage.trackSerialObjects=allTracks;
%             allTracksMessage.databaseSerialObject=getByteStreamFromArray(obj.trackDatabase);
            obj.addDefaultLogEntry(obj.TRACK_LOGGING_KEY,updatedTracksMessage);
            
        end
        
        function nonIdealId = nonIdealAssociation(obj,currentTracks,obsId,obsData)
            trackKeys = keys(obj.trackDatabase.map);
            mdist = [];
            for i = 1:numel(currentTracks)
                [zp,Sp] = currentTracks{i}.getPositionAtTime(obsData.time);
                zp = zp(1:3);
                Sp = Sp(1:3,1:3);
                mdist(i) = sqrt((obsData.measurements(1:3)'-zp)'*Sp^-1*(obsData.measurements(1:3)'-zp));
                trackKeyVal(i) = cell2mat(trackKeys(i)); 
            end
            
            [~,minIndex] = min(mdist);
            %Get Track Key corresponding to minimum distance
            trackKeySingle = trackKeyVal(minIndex);

            if trackKeySingle ~= obsId && rand < obj.missAssociationProb
                nonIdealId = trackKeySingle;   
            else
                nonIdealId = obsId;  
            end
        end
        
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()            
            tests = {}; 
        end
    end
    
end

