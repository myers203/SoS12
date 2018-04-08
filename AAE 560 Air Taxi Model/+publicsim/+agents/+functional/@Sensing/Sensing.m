classdef Sensing < publicsim.agents.base.Periodic & publicsim.agents.base.Locatable & publicsim.agents.functional.Base & publicsim.agents.functional.Taskable
    %SENSING agent functional for publicsim.funcs.sensors.Sensor
    %   Provides agent functionality for the sensor functions
    %
    %   setObservableManager(observableObjectManager) sets an observable
    %   manager that contains the set of things that can be seen/observed
    %   (REQUIRED)
    %
    %   setSensorParameter(paramName,paramValue) sets paramName to
    %   paramValue for the funcs.sensors.Sensor. The Sensor must implement
    %   setParamName so the value can be set
    %
    %   enableSensing(sensorType) enables sensing where sensorType is a
    %   string for a publicsim.funcs.sensors.Sensor
    %
    %   setObservationTopicGroup(groupId) sets the observation message
    %   output subtype
    %
    %   enableObservationTransmission() enable message outputs vs. just
    %   function callbacks
    %
    %   registerSensorCallbackFunc(functionHandle,messageType) calls
    %   functionHandle with the message of type (ecef/azelr), usually not
    %   needed manually since tracking will auto-set this
    
    properties(SetAccess=private)
        sensor                              %sensor function instance
        observationTopicKey='Observation';  %output topic key
        observationGroupId=1;               %output topic subtype key
        observableObjectManager             %observable object manager (as a publicsim.funcs.groups.ObjectManager)
        transmitObservations=0;             %output obervations over the network
        observationCallbackFunc;            %function handle for non-network notification of observations
        observationCallbackInput            %type of input for filter--ECEF/AZELR
    end
    
    properties(Access=private)
        observationMessageTopic             %Data topic for message publication
        sensorParamName                    %sensor properties changed at orchestration
        sensorParamVal                     % Raw sensor values for when strings can't be used
    end
    
    properties(Constant)
        OBSERVATION_LOGGING_KEY='Observations'; %key for disk storage
        OBSERVATION_MESSAGE=struct('time',[],'measurements',[],'ids',[],... %obervation message
            'errors',[],...
            'sensorPosition',[],...
            'sensorId',[],...
            'sensorOrientation',[]);
        TASKABLE_TYPE_SENSING='Sensor'; %key for linking back to taskables
    end
    
    methods
        
        function obj=Sensing()
        end
        
        function setObservableManager(obj,observableObjectManager)
            %sets the observable manager
            obj.observableObjectManager=observableObjectManager;
        end
        
        function setSensorParameter(obj,paramName,paramValue)
            %sets a sensor function parameter
            paramName(1)=upper(paramName(1));
            newParamEval=['set' paramName];
            obj.sensorParamName{end+1}=newParamEval;
            obj.sensorParamVal{end+1} = paramValue;
        end
        
        function rebuildObservationMessageTopic(obj)
            %sets/updates the message topic
            obj.observationMessageTopic=obj.getDataTopic(...
                obj.observationTopicKey,...
                num2str(obj.observationGroupId),...
                num2str(obj.id));
        end
        
        function enableSensing(obj,sensorType)
            %enable sensing with a sensor of sensorType
            obj.sensor=eval([sensorType '();']);
            for i=1:numel(obj.sensorParamName)
                obj.sensor.(obj.sensorParamName{i})(obj.sensorParamVal{i});
            end
            assert(~isempty(obj.observableObjectManager),'Must set observable manager before sensing!');
            obj.rebuildObservationMessageTopic();
            obj.scheduleAtTime(0,@obj.periodicSensing);
            if isa(obj.sensor,'publicsim.funcs.taskers.Taskable')
                obj.enableTaskable(obj.TASKABLE_TYPE_SENSING,@obj.processTaskableCommand,@obj.getTaskableStatus);
            end
        end
        
        function setObservationTopicKey(obj,key)
            %sets the obeservation topic type (optional)
            obj.observationTopicKey=key;
            obj.rebuildObservationMessageTopic();
        end
        
        function setObservationTopicGroup(obj,groupId)
            %sets the observation output topic subtype
            obj.observationGroupId=groupId;
            if ~isempty(obj.sensor)
                obj.rebuildObservationMessageTopic();
            end
        end
        
        function setObservationMessageKeys(obj,topicKey,groupId)
            %combination of setObservationTopicKey and setObservationTopicGroup
            obj.observationTopicKey=topicKey;
            obj.observationGroupId=groupId;
            obj.rebuildObservationMessageTopic();
        end
        
        function enableObservationTransmission(obj)
            %enable messaging outputs for the sensor
            obj.transmitObservations=1;
        end
        
        function registerSensorCallbackFunc(obj,callbackFunction,inputType)
            %ties in the sensor to a tracker callback function
            obj.observationCallbackFunc=callbackFunction;
            obj.observationCallbackInput=inputType;
        end
        
        function disableObservationTransmission(obj)
            %disables message transmission (rarely used)
            obj.transmitObservations=0;
            if isempty(obj.observationCallbackFunc)
                warning('No callback function registered, sensor will do nothing unless set!');
            end
        end
        
        function sensorStatus=getSensorStatus(obj,time)
            %returns a sensor status structure for creating sensor-relative
            %observations
            sensorStatus=publicsim.funcs.sensors.Sensor.SENSOR_STATUS;
            sensorStatus.position=obj.getPosition();
            sensorStatus.velocity=obj.getVelocity();
            sensorStatus.acceleration=obj.getAcceleration();
            sensorStatus.time=time;
            % TODO: Add orientation here?
        end
        
        function status=getTaskableStatus(obj,time)
            %gets the taskable status if the sensor is taskable
            if ~isa(obj.sensor,'publicsim.funcs.taskers.Taskable')
                status=[];
            else
                sensorStatus=obj.getSensorStatus(time);
                status=obj.sensor.getTaskableStatus(sensorStatus,time);
            end
        end
        
        function processTaskableCommand(obj,time,command)
            %handles the taskable command
            if isa(obj.sensor,'publicsim.funcs.taskers.Taskable')
                obj.sensor.processTaskableCommand(time,command);
            end
        end
        
        function periodicSensing(obj,time)
            if isa(obj, 'publicsim.agents.physical.Destroyable') && obj.isDestroyed
                return;
            end
            %periodic observation generation--queries sensor for period
            observables=obj.observableObjectManager.getObservables(time);
            sensorStatus=obj.getSensorStatus(time);
            
            if ~isempty(observables)
                
                if isa(obj.sensor,'publicsim.funcs.taskers.Taskable')
                    obj.sensor.updatePointingAngle(time,sensorStatus);
                end
                
                [observations, local_ids, errors]=...
                    obj.sensor.getObservations(observables,sensorStatus);
                
                % Using local_ids here because observations is a structure
                % with empty fields when no observations are generated.  It
                % still has length one.

                visible_ids = zeros(1, numel(local_ids));
                for i = 1:numel(local_ids)
                    visible_ids(i) = observables{i}.movableId;
                end
                
                if ~isempty(local_ids)
                    observationMessage=obj.OBSERVATION_MESSAGE;
                    observationMessage.sensorPosition=obj.getPosition();
                    observationMessage.sensorId=obj.id;
                    observationMessage.sensorOrientation = obj.getOrientation();
                    observationMessage.time=time;
                    observationMessage.ids=local_ids;
                    observationMessage.measurements=observations;
                    observationMessage.errors=errors;
                    
                    %Log the observations for later evaluation.  May want
                    %to do this outside the observations loop so we have
                    %them even when observations arent generated.
                    loggedObservationMessage = observationMessage;
                    az = obj.sensor.azimuth_bounds;
                    el = obj.sensor.elevation_bounds;
                    loggedObservationMessage.lookDirection = [az,el];
                    obj.addDefaultLogEntry(obj.OBSERVATION_LOGGING_KEY,...
                        loggedObservationMessage);
                    
                    if obj.transmitObservations==1
                        %Covers all types
                        obj.publishToTopic(obj.observationMessageTopic,observationMessage); %Comes from Networked
                        observationMessageTypes=obj.sensor.getOutputType();
                        for i=1:numel(observationMessageTypes)
                            messageType=observationMessageTypes{i};
                            typeTopic=obj.getDataTopic(...
                                [obj.observationTopicKey '-' messageType],...
                                num2str(obj.observationGroupId),...
                                num2str(obj.id));
                            observationMessage.measurements=observations.(messageType);
                            observationMessage.errors=errors.(messageType);
                            obj.publishToTopic(typeTopic,observationMessage);
                        end
                    end
                    if ~isempty(obj.observationCallbackFunc)
                        messageType=obj.observationCallbackInput;
                        observationMessage.measurements=observations.(messageType);
                        observationMessage.errors=errors.(messageType);
                        obj.observationCallbackFunc(time,observationMessage);
                    end
                    if isempty(obj.observationCallbackFunc) && obj.transmitObservations == 0
                        warning('No dataflow from Sensor!');
                    end
                    
                end
            end
            
            waitTime=obj.sensor.getNextScanTime();
            obj.scheduleAtTime(time+waitTime,@obj.periodicSensing);
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

