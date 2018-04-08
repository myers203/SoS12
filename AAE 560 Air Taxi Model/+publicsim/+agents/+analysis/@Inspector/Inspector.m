classdef Inspector < publicsim.agents.base.Periodic
    %INSPECTOR <Depricated, use agent logs> Periodic inspection and logging 
    %   Periodically checks list of callee's matching class and logs
    %   parameter at period requested to log topic requested
    
    properties
    end
    
    properties(SetAccess=private)
        baseLogTopic
        inspectionPoints
        objectInspectionPoints
        listenerPoints
        logPeriod
    end
    
    properties (Constant)
        CALLEE_ENTRY_STRUCT=struct('classType',[],...
            'paramName',[],...
            'logTopic',[]);
        
        OBJECT_ENTRY_STRUCT=struct('object',[],...
            'eventHandler',[],...
            'objectName',[],...
            'paramName',[],...
            'logTopic',[]);
        
    end
    
    methods
        
        function obj=Inspector(inspectorName,logPeriod)
            obj.baseLogTopic=inspectorName;
            obj.logPeriod=logPeriod;
        end
        
        function init(obj)
            obj.initPeriodic(obj.logPeriod);
        end
        
        function addPeriodicInspection(obj,classType,paramNames)
            inspectionPoint=obj.CALLEE_ENTRY_STRUCT;
            inspectionPoint.classType=classType;
            if ~iscell(paramNames)
                paramNames={paramNames};
            end
            inspectionPoint.paramNames=paramNames;
            inspectionPoint.logTopic=obj.getLoggingTopic(obj.baseLogTopic,classType,cell2mat(paramNames));
            if isempty(obj.inspectionPoints)
                obj.inspectionPoints=inspectionPoint;
            else
                obj.inspectionPoints(end+1)=inspectionPoint;
            end
        end
        
        function addPeriodicObjectInspection(obj,object,objectName,paramNames)
            inspectionPoint=obj.OBJECT_ENTRY_STRUCT;
            inspectionPoint.object=object;
            inspectionPoint.objectName=objectName;
            if ~iscell(paramNames)
                paramNames={paramNames};
            end
            inspectionPoint.paramNames=paramNames;
            inspectionPoint.logTopic=obj.getLoggingTopic(obj.baseLogTopic,objectName,cell2mat(paramNames));
            if isempty(obj.objectInspectionPoints)
                obj.objectInspectionPoints=inspectionPoint;
            else
                obj.objectInspectionPoints(end+1)=inspectionPoint;
            end
        end
        
        function addListenerInspection(obj,object,objectName,paramNames)
            inspectionPoint=obj.OBJECT_ENTRY_STRUCT;
            inspectionPoint.object=object;
            inspectionPoint.objectName=objectName;
            if ~iscell(paramNames)
                paramNames={paramNames};
            end
            inspectionPoint.paramNames=paramNames;
            inspectionPoint.logTopic=obj.getLoggingTopic(obj.baseLogTopic,objectName,cell2mat(paramNames));
            propertyList=cell(numel(paramNames),1);
            for i=1:numel(paramNames)
                paramName=paramNames{i};
                mco=metaclass(object);
                for k=1:numel(mco.PropertyList)
                    property=mco.PropertyList(k);
                    if isequal(paramName,property.Name)
                        propertyList{i}=property;
                        break;
                    end
                end
            end
            nListenPts=numel(obj.listenerPoints);
            listenHFunc=@(source,EventData) obj.listenerHandler(nListenPts+1,source,EventData);
            inspectionPoint.eventHandler=event.proplistener(object,propertyList,'PostSet',listenHFunc);
            if nListenPts == 0
                obj.listenerPoints=inspectionPoint;
            else
                obj.listenerPoints(end+1)=inspectionPoint;
            end
        end
        
        function listenerHandler(obj,entryId,source,eventData)
            time=obj.instance.Scheduler.currentTime;
            inspectionPoint=obj.listenerPoints(entryId);
            if isprop(eventData.AffectedObject,'id')
                logEntry.calleeId=eventData.AffectedObject.id;
            else
                logEntry.calleeId=-1;
            end
            logEntry.time=time;
            logEntry.calleeClass=inspectionPoint.objectName;
            params=struct('paramName',source.Name,'paramValue',...
                eventData.AffectedObject.(source.Name));
            
            logEntry.params=params;
            obj.logToTopic(inspectionPoint.logTopic,logEntry);
        end
        
        function sampleAllPoints(obj,time)
            callees=obj.instance.getAllCallees();
            for i=1:numel(obj.inspectionPoints)
                inspectionPoint=obj.inspectionPoints(i);
                for j=1:numel(callees)
                    callee=callees{j};
                    if isa(callee,inspectionPoint.classType)
                        logEntry.calleeId=callee.id;
                        logEntry.calleeClass=class(callee);
                        logEntry.time=time;
                        nParams=numel(inspectionPoint.paramNames);
                        params=struct('paramName',[],'paramValue',[]);
                        params(nParams)=...
                            struct('paramName',[],'paramValue',[]);
                        
                        for k=1:nParams
                            params(k).paramName=inspectionPoint.paramNames{k};
                            params(k).paramValue=eval(['callee.' inspectionPoint.paramNames{k}]);
                        end
                        logEntry.params=params;
                        obj.logToTopic(inspectionPoint.logTopic,logEntry);
                    end
                end
            end
            
            for i=1:numel(obj.objectInspectionPoints)
                inspectionPoint=obj.objectInspectionPoints(i);
                logEntry.time=time;
                if isprop(inspectionPoint.object,'id')
                    logEntry.calleeId=inspectionPoint.object.id;
                else
                    logEntry.calleeId=-1;
                end
                logEntry.calleeClass=inspectionPoint.objectName;
                nParams=numel(inspectionPoint.paramNames);
                params=struct('paramName',[],'paramValue',[]);
                params(nParams)=...
                    struct('paramName',[],'paramValue',[]);
                
                for k=1:nParams
                    params(k).paramName=inspectionPoint.paramNames{k};
                    params(k).paramValue=eval(['inspectionPoint.object.' inspectionPoint.paramNames{k}]);
                end
                logEntry.params=params;
                obj.logToTopic(inspectionPoint.logTopic,logEntry);
            end
        end
        
        function runAtTime(obj,time)
            if obj.isRunTime(time)
                obj.sampleAllPoints(time);
            end
        end
        
        
    end
    
    methods (Static)
        
        function [output]=loadParam(logPath,inspectorName,keyName,paramName)
            logInst=publicsim.sim.Logger(logPath);
            logInst.restore();
            topicList=logInst.getAllTopics();
            x={}; t={}; id={}; classNames={};
            for i=1:numel(topicList)
                if isequal(topicList{i}.type,inspectorName)
                    if isequal(topicList{i}.subtype,keyName)
                        if any(strfind(topicList{i}.subsubtype,paramName))
                            [~,entries]=logInst.readFromTopic(topicList{i});
                            entries=entries{1};
                            tmpx=cell(numel(entries),1);
                            tmpt=zeros(numel(entries),1);
                            tmpid=zeros(numel(entries),1);
                            tmpClassNames=cell(numel(entries),1);
                            rmIdx=[];
                            
                            for k=1:numel(entries)
                                logEntry=entries{k};
                                paramList={logEntry.params.paramName};
                                paramVals={logEntry.params.paramValue};
                                if ~any(ismember(paramList,paramName))
                                    rmIdx(end+1)=k; %#ok<AGROW>
                                    continue;
                                end
                                tmpx{k}=paramVals{ismember(paramList,paramName)};
                                tmpt(k)=logEntry.time;
                                tmpid(k)=logEntry.calleeId;
                                tmpClassNames{k}=logEntry.calleeClass;
                            end
                            
                            tmpx(rmIdx)=[];
                            tmpt(rmIdx)=[];
                            tmpid(rmIdx)=[];
                            tmpClassNames(rmIdx)=[];
                            
                            [tmpt,idx]=sort(tmpt);
                            tmpx=tmpx(idx);
                            tmpid=tmpid(idx);
                            tmpClassNames=tmpClassNames(idx);
                            x{end+1}=tmpx; %#ok<AGROW>
                            t{end+1}=tmpt; %#ok<AGROW>
                            id{end+1}=tmpid; %#ok<AGROW>
                            classNames{end+1}=tmpClassNames; %#ok<AGROW>
                        end
                    end
                end
            end
            output.t=t;
            output.x=x;
            output.id=id;
            output.classNames=classNames;
            output.numMatches=numel(id);
        end
        
        function test_inspector()
            import publicsim.*;
            logpath='./tmp/test';
            simInst=sim.Instance(logpath);
            testInspector1=tests.agents.analysis.InspectorTest();
            testInspector2=tests.agents.analysis.InspectorTest();
            simInst.AddCallee(testInspector1);
            simInst.AddCallee(testInspector2);
            
            %Log to myTestInspector topic with a period of 1 second
            inspector=agents.analysis.Inspector('myTestInspector',1.0);
            simInst.AddCallee(inspector); %Must be added prior to adding points
            
            inspector.addPeriodicObjectInspection(testInspector1,'objectInspect1',{'publicParam','getOtherParam'});
            inspector.addPeriodicInspection('publicsim.sim.Callee','id');
            inspector.addPeriodicInspection('publicsim.tests.agents.analysis.InspectorTest','publicParam');
            inspector.addPeriodicInspection('publicsim.tests.agents.analysis.InspectorTest',{'publicParam','getOtherParam'});
            inspector.addListenerInspection(testInspector1,'objectListen1',{'listenParam1','listenParam2'});
            
            simInst.runUntil(0,10-1e-9);
            
            tlog=sim.Logger('./tmp/test');
            tlog.restore();
            tlist=tlog.getAllTopics();
            
            for i=1:3
                assert(isequal(tlist{i}.type,'myTestInspector'),'Logging Irregularity');
                [topics,entries]=tlog.readFromTopic(tlist{i});
                entries=entries{1};
                if isequal(topics{1}.subtype,'publicsim.sim.Callee')
                    assert(numel(entries)==3*10,'Not enough log entries');
                    idLogList=zeros(numel(entries),1);
                    for k=1:numel(entries)
                        logEntry=entries{k};
                        idLogList(k)=logEntry.params(1).paramValue;
                    end
                    assert(sum(idLogList==1)==10 && sum(idLogList==2)==10 && sum(idLogList==3)==10,'Incorrect callee entries');
                elseif isequal(topics{1}.subtype,'publicsim.tests.agents.analysis.InspectorTest')
                    assert(numel(entries)==2*10,'Not enough log entries');
                    if isequal(topics{1}.subsubtype,'publicParam')
                        publicParamList=zeros(numel(entries),1);
                        for k=1:numel(entries)
                            logEntry=entries{k};
                            publicParamList(k)=logEntry.params(1).paramValue;
                        end
                        assert(~any(publicParamList~=99),'Error in param storage');
                    elseif isequal(topics{1}.subsubtype,'publicParamgetOtherParam')
                        publicParamList=zeros(numel(entries),1);
                        otherParamList=zeros(numel(entries),1);
                        for k=1:numel(entries)
                            logEntry=entries{k};
                            paramList={logEntry.params.paramName};
                            paramVals={logEntry.params.paramValue};
                            publicParamList(k)=paramVals{ismember(paramList,'publicParam')};
                            otherParamList(k)=paramVals{ismember(paramList,'getOtherParam')};
                        end
                        assert(~any(publicParamList~=99),'Error in param storage');
                        assert(~any(otherParamList~=89),'Error in param storage');
                    end
                end
            end
            
            param=agents.analysis.Inspector.loadParam('./tmp/test','myTestInspector','publicsim.tests.agents.analysis.InspectorTest','publicParam');
            assert(size(param.t,2)==2,'Load Failure');
            assert(size(param.id,2)==2,'Load Failure');
            assert(size(param.x,2)==2,'Load Failure');
            assert(size(param.t{1},1)==20,'Load Failure');
            assert(size(param.t{2},1)==20,'Load Failure');
            assert(size(param.id{1},1)==20,'Load Failure');
            assert(size(param.id{2},1)==20,'Load Failure');
            assert(size(param.x{1},1)==20,'Load Failure');
            assert(size(param.x{2},1)==20,'Load Failure');
            
            param=agents.analysis.Inspector.loadParam('./tmp/test','myTestInspector','objectInspect1','publicParam');
            assert(~any(cell2mat(param.x{1})~=99),'Loading Error');
            assert(size(param.x{1},1)==10,'Loading Error');
            
            param=agents.analysis.Inspector.loadParam('./tmp/test','myTestInspector','objectListen1','listenParam1');
            assert(sum(cell2mat(param.x{1}))==sum(12:1:(11+20)),'Loading Error');
            assert(size(param.x{1},1)==20,'Loading Error');
            
            
        end
    end
    
end

