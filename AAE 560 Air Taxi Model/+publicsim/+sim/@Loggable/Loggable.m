classdef Loggable < handle & publicsim.tests.UniversalTester
    %LOGGABLE a class that can be logged to the console or disk
    %   Loggable provides methods for storing data to the disk or printing
    %   to the console
    %
    %   addPeriodicLogItems({'property1','function1'},period) periodically
    %   logs property1 and the first output of function1 to the log every
    %   period seconds
    %
    %   addDefaultLogEntry(itemName,itemValue) addes itemName (as a
    %   reference) to the log entry with itemValue--later retreived by
    %   readParamsByClass(...itemName)
    %
    %   setAddDefaultLogs(0) disable the default logs for this loggable
    %
    %
    %   getLoggingTopic('type','subtype','subsubtype') get handle for
    %   writing log entries of this type--avoid using if possible via
    %   callee logs
    %
    %   logToTopic(topic,data) saves data to the topic handle (from
    %   getLoggingTopic) for later retreival by the same topic key
    %
    %   getAgentsByClass(logger,className) gets all properties at init for
    %   agents that are type className
    %
    %   readParamsByClass(logger,className,paramList) reads all log entries
    %   for class of type className and returns ones that are named in the
    %   paramList
    
    properties(Access=private)
        logLevel=publicsim.sim.Logger.log_WARN  %the console log level below which display is ignored
        defaultTopic        %the topic that the loggable will post to by default
        logId               %the callee id or -1 if it is not a callee
    end
    
    properties(Access=private, Hidden=true)
        addDefaultLogs = 1; % Flag to run addAllPropertyLogs() on initialization
        isInit = 0;
    end
    
    properties(Access=private,Transient=true)
        periodicLogItemList     %Items that will be logged periodically
        observableLogItemList   %Items that will be observed on setting events
        Logger                  %back reference to the sim's logger
    end
    
    properties(Constant)
        defaultTopicName='DefaultTopic';    %String for the default entry
        defaultKeyName='logKeyTopic';       %String for the default entry's key
        defaultLogPeriod=1.0;               %Log period, if unset, for periodic entries
    end
    
    properties(Constant,Access=private)
        keyEntry=struct('className',[],'logId',[],'logTopic',[]); %Entry for key used for the current loggable
        periodicEntry=struct('itemName',[],'period',[],...
            'logTopic',[],'functionHandle',[]); % Entry for periodic log items
        observableEntry=struct('itemName',[],'functionHandle',[],...
            'eventHandler',[],'logTopic',[]); %Entry for event-based log items
        logEntry=struct('className',[],'itemName',[],'itemValue',[],'time',[]); %particular entry into the log file
    end
    
    methods
        
        function obj=Loggable()
            %Unused constructor; never called directly
        end
        
        function setLogger(obj,logger)
            %sets the back reference to the sim's logger
            obj.Logger=logger;
            %The ID will be the sim provided callee id else -1
            if ~isa(obj,'publicsim.sim.Callee') && ~isa(obj,'sim.Callee')
                obj.logId=-1;
            else
                obj.logId=obj.id;
            end
            %The default topic is set to be by the class name and id number
            obj.setDefaultTopic(obj.getLoggingTopic(obj.defaultTopicName,class(obj),num2str(obj.logId)));
        end
        
        function setDefaultTopic(obj,topic)
            %override the default topic with another topic
            obj.defaultTopic=topic;
        end
        
        function setLogLevel(obj,level)
            %set the log level for the loggable (for display purposes)
            obj.logLevel=level;
        end
        
        function setAddDefualtLogs(obj, flag) %#ok<INUSD>
            error('depricated name');
        end
        
        function setAddDefaultLogs(obj, flag)
            %function for disabling default logging of the agent
            assert((flag == 0) || (flag == 1), 'Cannot set flag to non-boolean value');
            obj.addDefaultLogs = flag;
        end
        
        function initLog(obj)
            % Prevent double-init, which causes all sorts of duplication
            % problems
            if obj.isInit
                return
            end
            obj.isInit = 1;
            
            newLogEntry=obj.logEntry;
            newLogEntry.className=class(obj);
            newLogEntry.itemName='INIT';
            newLogEntry.itemValue=obj;
            newLogEntry.time=0;
            %The initial properties are logged (non-transient)
            obj.logToTopic(obj.defaultTopic,newLogEntry);
            obj.addObservableLogs();
            obj.addAllPropertyLogs();
            
            newKeyEntry=obj.keyEntry;
            newKeyEntry.className=class(obj);
            newKeyEntry.logId=obj.logId;
            newKeyEntry.topic=obj.defaultTopic;
            %The class name is stored to the log as well for class-based
            %access
            keyTopic=obj.getLoggingTopic(obj.defaultTopicName,obj.defaultKeyName,'');
            obj.logToTopic(keyTopic,newKeyEntry);
        end
        
        function addAllPropertyLogs(obj)
            %addes property logs (calls addPropertyLogs funciton) of each
            %loggable and its superclasses
            if ~obj.addDefaultLogs
                return;
            end
            nameList={};
            allClassNames=[superclasses(obj); {class(obj)}];
            for i=1:numel(allClassNames)
                mco=meta.class.fromName(allClassNames{i});
                if any(ismember({mco.MethodList.Name},'addPropertyLogs'))
                    definingClass=mco.MethodList(ismember({mco.MethodList.Name},'addPropertyLogs')).DefiningClass;
                    if isequal(definingClass.Name,allClassNames{i})
                        %If the superclass has the method addPropertyLogs,
                        %then it is added to the list for calling below
                        nameList{end+1}=allClassNames{i}; %#ok<AGROW>
                    end
                end
            end
            
            allClassNames=nameList;
            for i=1:numel(allClassNames)
                eval([allClassNames{i} '.addPropertyLogs(obj);']);
            end
        end
        
        function addObservableLogs(obj)
            %adds log entries for all observable properties of a class
            mco=metaclass(obj);
            for i=1:numel(mco.PropertyList)
                property=mco.PropertyList(i);
                if property.SetObservable==1
                    obj.addObservableLogItems(property.Name);
                end
            end
        end
        
        function addPeriodicLogItems(obj,items,varargin)
            %adds periodic entries for callee-supported periodic observation 
            if ~isa(obj,'publicsim.sim.Callee') && ~isa(obj,'sim.Callee')
                error('Cannot add periodic logging to non-callee');
            end
            
            if nargin >= 3
                periods=varargin{1};
            else
                periods=obj.defaultLogPeriod;
            end
            
            if ~iscell(items)
                items={items};
            end
            
            for i=1:numel(items)
                % Check if the item is a property of the object or nested
                % in the object
                nest = strsplit(items{i}, '.'); % Nested properties or methods
                base = obj; % Base object at first 
                for j = 1:(numel(nest) - 1)
                    % Get the nested property
                    if isprop(base,nest{j}) || isfield(base, nest{j})
                        base = obj.(nest{j});
                    else
                        error('Adding nested property inspection for non-property');
                    end
                end
                if ~isprop(base,nest{end}) && ~ismethod(base,nest{end}) && ~isfield(base, nest{end})
                    error('Adding property inspection for non-property/non-method');
                end
                
                entryId=numel(obj.periodicLogItemList)+1;
                newPeriodicEntry=obj.periodicEntry;
                newPeriodicEntry.itemName=items{i};
                if numel(periods) > 1
                    newPeriodicEntry.period=periods(i);
                else
                    newPeriodicEntry.period=periods;
                end
                newPeriodicEntry.logTopic=obj.defaultTopic;
                functionHandle=@(time) obj.periodicEventHandler(entryId,time);
                newPeriodicEntry.functionHandle=functionHandle;
                if isempty(obj.periodicLogItemList)
                    obj.periodicLogItemList=newPeriodicEntry;
                else
                    obj.periodicLogItemList(end+1)=newPeriodicEntry;
                end
                obj.scheduleAtTime(0,functionHandle);
            end
        end
        
        function addObservableLogItems(obj,items,varargin)
            %Adds log entries for observable properties
            if ~iscell(items)
                items={items};
            end
            
            if nargin > 2
                observingObject=varargin{3};
            else
                observingObject=obj;
            end
            
            for i=1:numel(items)
                if ~isprop(obj,items{i})
                    error('Adding property inspection for non-property');
                end
                metaProperty=findprop(obj,items{i});
                if metaProperty.SetObservable ~= 1
                    error('Observations require "SetObservable" property');
                end
                
                entryId=numel(obj.observableLogItemList)+1;
                newObservableEntry=obj.observableEntry;
                functionHandle=@(source,eventData) obj.observationEventHandler(entryId,source,eventData);
                newObservableEntry.functionHandle=functionHandle;
                newObservableEntry.itemName=items{i};
                newObservableEntry.eventHandler=addlistener(observingObject,items{i},'PostSet',functionHandle);
                newObservableEntry.logTopic=obj.defaultTopic;
                if isempty(obj.observableLogItemList)
                    obj.observableLogItemList=newObservableEntry;
                else
                    obj.observableLogItemList(end+1)=newObservableEntry;
                end
            end
        end
        
        function periodicEventHandler(obj,entryId,time)
            %process periodic logging events (samples and stores)
            eventPeriodicEntry=obj.periodicLogItemList(entryId);
            obj.scheduleAtTime(time+eventPeriodicEntry.period,...
                eventPeriodicEntry.functionHandle);
            
            newLogEntry=obj.logEntry;
            newLogEntry.className=class(obj);
            newLogEntry.itemName=eventPeriodicEntry.itemName;
            % Unpack if nested
            nest = strsplit(eventPeriodicEntry.itemName, '.');
            base = obj;
            for i = 1:(numel(nest) - 1)
                base = base.(nest{i});
            end
            newLogEntry.itemValue=base.(nest{end});
            newLogEntry.time=time;
            obj.logToTopic(eventPeriodicEntry.logTopic,newLogEntry);
            
        end
        
        function observationEventHandler(obj,entryId,source,eventData)
            %handles Set events for observable properties
            eventObservableEntry=obj.observableLogItemList(entryId);
            if isa(obj,'publicsim.sim.Callee') || isa(obj,'sim.Callee')
                time=obj.instance.Scheduler.currentTime;
            else
                time=-1;
            end
            newLogEntry=obj.logEntry;
            newLogEntry.className=class(eventData.AffectedObject);
            newLogEntry.itemName=eventObservableEntry.itemName;
            newLogEntry.itemValue=eventData.AffectedObject.(source.Name);
            newLogEntry.time=time;
            obj.logToTopic(eventObservableEntry.logTopic,newLogEntry);
        end
        
        function addDefaultLogEntry(obj,itemName,itemValue)
            %Adds an entry to the log based on the agent's default
            %key--useful for agent-based logging and retrevial on the
            %itemName key
			assert(~isempty(itemName) && ischar(itemName),'You must provide an item name as an input');
            assert(~isempty(itemValue),'Logged item must not be empty');
            newLogEntry=obj.logEntry;
            newLogEntry.className=class(obj);
            
            if isa(obj,'publicsim.sim.Callee') || isa(obj,'sim.Callee')
                time=obj.instance.Scheduler.currentTime;
            else
                time=-1;
            end
            newLogEntry.time=time;
            newLogEntry.itemName=itemName;
            newLogEntry.itemValue=itemValue;
            obj.logToTopic(obj.defaultTopic,newLogEntry);
        end
        
        function disp_DEBUG(obj,message)
            %display DEBUG level message
            if obj.logLevel < obj.Logger.log_DEBUG
                return;
            end
            obj.cprintTemplate('Text','DEBUG',message);
        end
        
        function disp_INFO(obj,message)
            %display INFO level message
            if obj.logLevel < obj.Logger.log_INFO
                return;
            end
            obj.cprintTemplate('Keywords','INFO',message);
        end
        
        function disp_WARN(obj,message)
            %display WARN level message
            if obj.logLevel < obj.Logger.log_WARN
                return;
            end
            obj.cprintTemplate('SystemCommands','WARNING',message);
        end
        
        function disp_ERROR(obj,message)
            %display ERROR level message
            if obj.logLevel < obj.Logger.log_ERROR
                return;
            end
            obj.cprintTemplate('Red','ERROR',message);
        end
        
        function disp_FATAL(obj,message)
            %display FATAL error message
            if obj.logLevel < obj.Logger.log_FATAL
                return;
            end
            obj.cprintTemplate('*Red','FATAL',message);
        end
        
        function cprintTemplate(obj,disptype,prefix,message)
            %displays colored text and callee line number
            import publicsim.*;
            if obj.Logger.showLinesInDisp == 1
                dbs=dbstack;
                util.cprintf(disptype,[prefix ': ' message ' (' dbs(3).name ':' num2str(dbs(3).line) ')\n']);
            else
                util.cprintf(disptype,[prefix ': ' message '\n']);
            end
            
        end
        
        function topic=getLoggingTopic(obj,type,subtype,subsubtype)
            %Gets logging topic from the Logger instance
            topic=obj.Logger.getTopic(type,subtype,subsubtype);
        end
        
        function logToTopic(obj,topic,data)
            %Stores data into the Logger instance
            obj.Logger.writeToTopic(topic,data);
        end
     
    end
    
    methods(Static)
        
        function paramData=readParamsByClass(logger,className,paramList)
            %retreives log entries for a particular class (and its
            %children). Only items matching the paramList are retreived,
            %and these items may be strings from addDefaultLogEntry,
            %function names from periodic, or property names from
            %observable entries
            assert(isa(logger,'publicsim.sim.Logger') || isa(logger,'sim.Logger') , 'logger must be publicsim.sim.Logger instance');
			if ~iscell(paramList)
				paramList={paramList};
			end
            
            keyTopic=logger.getTopic(publicsim.sim.Loggable.defaultTopicName,...
                publicsim.sim.Loggable.defaultKeyName,'');
            [~,entries]=logger.readFromTopic(keyTopic);
            keyEntries=entries{1}; %only expecting 1 match here
            matchingKeyTopics={};
            for i=1:numel(keyEntries)
                keyEntry=keyEntries{i};
                allClassNames=[superclasses(keyEntry.className); {keyEntry.className}];
                if any(ismember(allClassNames,className))
                    matchingKeyTopics{end+1}=keyEntry.topic; %#ok<AGROW>
                end
            end
            paramData=cell(numel(paramList),1);
            
            for i=1:numel(matchingKeyTopics)
                dataTopic=matchingKeyTopics{i};
                [~,entries]=logger.readFromTopic(dataTopic);
                logId=str2num(dataTopic.subsubtype); %#ok<ST2NM>
                data=cell2mat(entries{1}); %only expecting one match since unique by Log ID even if '-1' no id
                idxSet=1:numel(data);
                for k=1:numel(paramList)
                    paramIdxSet=idxSet(ismember({data.itemName},paramList{k}));
                    if ~isempty(paramIdxSet)
                        newData=struct();
                        for j=1:numel(paramIdxSet)
                            newData(j).time=data(paramIdxSet(j)).time;
                            newData(j).id=logId;
                            newData(j).className=data(paramIdxSet(j)).className;
                            newData(j).value=data(paramIdxSet(j)).itemValue;
                        end
                        paramData{k}=[paramData{k},newData];
                    end
                end
            end
            
            for i=1:numel(paramList)
                % This could be sped up by unwrapping for struct inputs,
                % but not sure how to do that dynamically/without handles
                try
                    eval(['paramDataOut.', paramList{i}, '=paramData{i};']);
                catch
                    eval(['paramDataOut.p', num2str(i), '=paramData{i};']);
                end
            end
            
            paramData=paramDataOut;
            
        end
        
        function allAgents=getAgentsByClass(logger,className)
            %returns agent handles based on non-transient properties for
            %agents of a particular type
            allAgents=publicsim.sim.Loggable.readParamsByClass(logger,className,{'INIT'});
            allAgents=allAgents.INIT;
        end
            
            
        
        function test_loggable()
            import publicsim.*;
            tsim=sim.Instance('./tmp');
            testCallee=tests.sim.Test_Callee();
            tsim.AddCallee(testCallee);
            tsim.Logger.showLinesInDisp=1;
            
            testCallee.setLogLevel(5);
            
            disp(' ');
            disp('DEBUG INFO WARNING ERROR FATAL');
            testCallee.disp_DEBUG('Debug Disp');
            testCallee.disp_INFO('Info Disp');
            testCallee.disp_WARN('Warn Disp');
            testCallee.disp_ERROR('Error Disp');
            testCallee.disp_FATAL('FATAL Disp');
            disp('DEBUG INFO WARNING ERROR FATAL');
            disp(' ');
        end
        
    end
    
    methods(Static,Access=private)
        
        function addPropertyLogs(obj) %#ok<INUSD>
            %Default function overloaded by loggables with periodic
            %property logs
            %period=2.0; [s]
            %obj.addPeriodicLogItems({'getPosition','getVelocity'},period);
            %obj.addPeriodicLogItems({'getAcceleration'},0.5);
        end
        
    end
    
    
end

