classdef  Tracker < handle
    %TRACKER Summary of this class goes here
    %   Detailed explanation goes here
    %
    %
    % run publicsim.funcs.trackers.Tracker.getStaticQParams to get the Q
    % const matrixs
    
    properties (SetAccess=protected)
        inputType='ECEF';
        Q
        P
        x
        t
        nStates
        processNoiseEvents=[];
        qtilda
    end
    
    properties
        trackPurity
    end
    
    properties(SetAccess=protected,Transient)
        processModelFunction
        measurementModelFunction
        world
        F_pows
        F_consts
        Q_pows
        Q_consts
        useGroundTruth=0;
    end
    
    properties(Constant)
        DEFAULT_WORLD='elliptical'
        PROCESS_NOISE_EVENT=struct('time',-1,...
            'pAdd',[],'qTilda',[],'applied',0,'newStateHandle',[]);
        QPOWS_6=[3 0 0 2 0 0;0 3 0 0 2 0;0 0 3 0 0 2;2 0 0 1 0 0;0 2 0 0 1 0;0 0 2 0 0 1];
        QCONSTS_6=[0.333333333333333 0 0 0.5 0 0;0 0.333333333333333 0 0 0.5 0;0 0 0.333333333333333 0 0 0.5;0.5 0 0 1 0 0;0 0.5 0 0 1 0;0 0 0.5 0 0 1];
        QPOWS_9=[5 0 0 4 0 0 3 0 0;0 5 0 0 4 0 0 3 0;0 0 5 0 0 4 0 0 3;4 0 0 3 0 0 2 0 0;0 4 0 0 3 0 0 2 0;0 0 4 0 0 3 0 0 2;3 0 0 2 0 0 1 0 0;0 3 0 0 2 0 0 1 0;0 0 3 0 0 2 0 0 1];
        QCONSTS_9=[0.05 0 0 0.125 0 0 0.166666666666667 0 0;0 0.05 0 0 0.125 0 0 0.166666666666667 0;0 0 0.05 0 0 0.125 0 0 0.166666666666667;0.125 0 0 0.333333333333333 0 0 0.5 0 0;0 0.125 0 0 0.333333333333333 0 0 0.5 0;0 0 0.125 0 0 0.333333333333333 0 0 0.5;0.166666666666667 0 0 0.5 0 0 1 0 0;0 0.166666666666667 0 0 0.5 0 0 1 0;0 0 0.166666666666667 0 0 0.5 0 0 1];
        QPOWS_12=[7 0 0 6 0 0 5 0 0 4 0 0;0 7 0 0 6 0 0 5 0 0 4 0;0 0 7 0 0 6 0 0 5 0 0 4;6 0 0 5 0 0 4 0 0 3 0 0;0 6 0 0 5 0 0 4 0 0 3 0;0 0 6 0 0 5 0 0 4 0 0 3;5 0 0 4 0 0 3 0 0 2 0 0;0 5 0 0 4 0 0 3 0 0 2 0;0 0 5 0 0 4 0 0 3 0 0 2;4 0 0 3 0 0 2 0 0 1 0 0;0 4 0 0 3 0 0 2 0 0 1 0;0 0 4 0 0 3 0 0 2 0 0 1];
        QCONSTS_12=[0.00396825396825397 0 0 0.0138888888888889 0 0 0.0333333333333333 0 0 0.0416666666666667 0 0;0 0.00396825396825397 0 0 0.0138888888888889 0 0 0.0333333333333333 0 0 0.0416666666666667 0;0 0 0.00396825396825397 0 0 0.0138888888888889 0 0 0.0333333333333333 0 0 0.0416666666666667;0.0138888888888889 0 0 0.05 0 0 0.125 0 0 0.166666666666667 0 0;0 0.0138888888888889 0 0 0.05 0 0 0.125 0 0 0.166666666666667 0;0 0 0.0138888888888889 0 0 0.05 0 0 0.125 0 0 0.166666666666667;0.0333333333333333 0 0 0.125 0 0 0.333333333333333 0 0 0.5 0 0;0 0.0333333333333333 0 0 0.125 0 0 0.333333333333333 0 0 0.5 0;0 0 0.0333333333333333 0 0 0.125 0 0 0.333333333333333 0 0 0.5;0.0416666666666667 0 0 0.166666666666667 0 0 0.5 0 0 1 0 0;0 0.0416666666666667 0 0 0.166666666666667 0 0 0.5 0 0 1 0;0 0 0.0416666666666667 0 0 0.166666666666667 0 0 0.5 0 0 1];
    end
    
    methods
        
        function obj=Tracker(nStates)
            obj.nStates=nStates;
            obj.x=zeros(nStates,1);
            obj.P=zeros(nStates,nStates);
            obj.t=0;
        end
        
        function setMeasurementModel(obj,measurementModelFunction)
            obj.measurementModelFunction=measurementModelFunction;
        end
        
        function setProcessModel(obj,processModelFunction)
            obj.processModelFunction=processModelFunction;
        end
        
        function addProcessNoiseEvent(obj,time,pAdd,qTilda,newStateHandle)
            newEntry=obj.PROCESS_NOISE_EVENT;
            newEntry.time=time;
            newEntry.pAdd=pAdd;
            newEntry.qTilda=qTilda;
            if nargin >= 5 && ~isempty(newStateHandle)
                newEntry.newStateHandle=newStateHandle;
            end
            if isempty(obj.processNoiseEvents)
                obj.processNoiseEvents=newEntry;
            else
                obj.processNoiseEvents(end+1)=newEntry;
            end
        end
        
        function applyProcessNoiseEvent(obj,time)
            if isempty(obj.processNoiseEvents) || ~isfield(obj.processNoiseEvents,'time')
                return;
            end
            eventTimes=[obj.processNoiseEvents.time];
            eventTimes([obj.processNoiseEvents.applied] == 1)=[];
            eventTimes(eventTimes>time)=[];
            eventTimes=sort(eventTimes,'ascend');
            for i=1:numel(eventTimes)
                event=obj.processNoiseEvents([obj.processNoiseEvents.time] == eventTimes(i));
                event.applied=1;
                obj.processNoiseEvents([obj.processNoiseEvents.time] == eventTimes(i))=event;
                obj.qtilda=event.qTilda;
                obj.P=obj.P+event.pAdd;
                obj.P=diag(diag(obj.P));
                if ~isempty(event.newStateHandle)
                    obj.x=event.newStateHandle(obj,time);
                end
            end
        end
        
        function initState(obj,obsData)
            warning('Depricated functionality');
            obj.initByObs(obsData);
        end
        
        function setWorldModel(obj,world)
            obj.world=world;
        end
        
        function initByObs(obj,obsData) %#ok<INUSD>
            error('Not implemented');
        end
        
        function initByState(obj,x0,P0,t) %#ok<INUSD>
            error('Not implemented');
        end
        
        function error=getPositionErrorAtTime(obj,time)
            if isempty(obj.t)
                error=inf;
            else
                [~,P1]=obj.getPositionAtTime(time);
                error=mean(sqrt(eig(P1(1:3,1:3))));
            end
        end
        
        function type=getInputType(obj)
            type=obj.inputType;
        end
        
        function setInputType(obj,type)
            obj.inputType=type;
        end
        
        function groundTruth=requiresGroundTruth(obj)
            groundTruth=obj.useGroundTruth;
        end
        
        function requireGroundTruth(obj)
            obj.useGroundTruth=1;
        end
        
        function processGroundTruth(obj,time,spatial,obsData, observable) %#ok<INUSD>
        end
        
        function buildInitialP(obj,positionError)
            Pdiag=zeros(obj.nStates,1);
            for i=1:obj.nStates/3
                k=3*(i-1)+1;
                Pdiag(k:k+2)=positionError/10^(i-1);
            end
            obj.P=diag(Pdiag,0);
        end
        
        function buildInitialQ(obj,processNoise)
            obj.qtilda=processNoise;
                         numTrueStates=obj.nStates/3;
                         obj.Q_pows=[];
                         obj.Q_consts=[];
                         for i=1:numTrueStates
                                 obj.Q_pows(end+1)=i-1;
                                 obj.Q_consts(end+1)=1/factorial(i-1);
                         end
                         obj.Q_pows=fliplr(obj.Q_pows);
                         obj.Q_consts=fliplr(obj.Q_consts);
            obj.Q=zeros(obj.nStates,obj.nStates);
            %obj.Q_pows=eval(['obj.QPOWS_' num2str(obj.nStates)]);
            %obj.Q_consts=eval(['obj.QPOWS_' num2str(obj.nStates)]);
        end
        
        
        
        function Q=buildProcessNoise(obj,deltaT)
            w=deltaT.^obj.Q_pows.*obj.Q_consts;
            q=obj.qtilda*(w'*w);
            Q=zeros(obj.nStates,obj.nStates);
            for i=1:(obj.nStates/3)
                for j=1:(obj.nStates/3)
                    Q(3*(i-1)+1,3*(j-1)+1)=q(i,j);
                    Q(3*(i-1)+2,3*(j-1)+2)=q(i,j);
                    Q(3*(i-1)+3,3*(j-1)+3)=q(i,j);
                end
            end
            
            %F=obj.buildLinearModelMatrix(deltaT);
            %Qc=obj.qtilda*diag([zeros(obj.nStates-3,1)' ones(3,1)']);
            %Qp=F*Qc*F';
            %             Qtest=Qp-Q;
            %             Qtest(Qp<=0)=0;
            %             if any(Qtest>0)
            %
            %             end
            %Q=Qp;
            %Q=obj.qtilda*obj.Q_consts.*deltaT.^obj.Q_pows;
        end
        
        function H=linearMeasurementModel(obj)
            H=[eye(3) zeros(3,obj.nStates-3)];
        end
        
        function [x,P]=linearProcessModel(obj,deltaT)
            if deltaT==0
                x=obj.x;
                P=obj.P;
            else
                F=obj.buildLinearModelMatrix(deltaT);
                x=F*obj.x;
                Qt=obj.buildProcessNoise(deltaT);
                %Qt(F==0)=0;
                %Qt=triu(Qt)+triu(Qt,1)';
                P=F*(obj.P)*F' + Qt;
            end
        end
        
        function F=buildLinearModelMatrix(obj,deltaT)
            if isempty(obj.F_consts) || isempty(obj.F_pows)
                numTrueStates=obj.nStates/3;
                obj.F_consts=diag(ones(obj.nStates,1));
                for i=1:numTrueStates
                    obj.F_consts=obj.F_consts+diag(ones(obj.nStates-i*3,1)*1/factorial(i),3*i);
                end
                obj.F_pows=diag(zeros(obj.nStates,1));
                for i=1:numTrueStates
                    obj.F_pows=obj.F_pows+diag(ones(obj.nStates-i*3,1)*i,3*i);
                end
            end
            F=obj.F_consts.*deltaT.^obj.F_pows;
        end
        
        function serialOutput=serialize(obj)
            mco=metaclass(obj);
            propertyNames={mco.PropertyList.Name}';
            pruneList=[mco.PropertyList.Transient];
            pruneList=pruneList | [mco.PropertyList.Constant];
            propertyNames(pruneList)=[];
            dataObject=[];
            for i=1:numel(propertyNames)
                dataObject.(propertyNames{i})=obj.(propertyNames{i});
            end
            serialOutput=getByteStreamFromArray(dataObject);
        end
        
        function obj=deserialize(obj,serialOutput)
            assert(isa(obj,'publicsim.funcs.trackers.Tracker'),'Must be called after creating tracker handle');
            dataObject=getArrayFromByteStream(serialOutput);
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
        
        function recoverDefaultFunctionHandles(obj)
            tempObj=eval(class(obj));
            obj.processModelFunction=tempObj.processModelFunction;
            obj.measurementModelFunction=tempObj.measurementModelFunction;
        end
        
        function checkWorld(obj)
            if isempty(obj.world)
                obj.world=publicsim.util.Earth();
                obj.world.setModel(obj.DEFAULT_WORLD);
            end
        end
        
        function updatePurity(obj,appendId)
            obj.trackPurity(end+1) = appendId;
        end
        
    end
    
    methods(Static)
        
        function obj=deserializeWithType(serialOutput,trackerType)
            dataObject=getArrayFromByteStream(serialOutput);
            obj=eval([trackerType '(dataObject.nStates)']);
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
        
        function [Qpows,Qconsts]=buildSymbolicQ(nStates)
            syms dt
            syms phi
            numTrueStates=nStates/3;
            F_consts=diag(ones(nStates,1));
            for i=1:numTrueStates
                F_consts=F_consts+diag(ones(nStates-i*3,1)*1/factorial(i),3*i);
            end
            F_pows=diag(zeros(nStates,1));
            for i=1:numTrueStates
                F_pows=F_pows+diag(ones(nStates-i*3,1)*i,3*i);
            end
            F_k=F_consts.*dt.^F_pows;
            Q_c=phi*diag([zeros(nStates-3,1)' ones(3,1)']);
            Q=int(F_k*Q_c*F_k',dt,0,dt);
            Q=Q/phi;
            Qpows=zeros(size(Q,1),size(Q,2));
            Qconsts=zeros(size(Q,1),size(Q,2));
            for i=1:size(Q,1)
                for j=1:size(Q,2)
                    Qpows(i,j)=length(sym2poly(Q(i,j)))-1;
                    Qconsts(i,j)=max(sym2poly(Q(i,j)));
                end
            end
        end
        
        function getStaticQParams()
            nStates=[6 9 12];
            for nState=nStates
                [Qpows,Qconsts]=publicsim.funcs.trackers.Tracker.buildSymbolicQ(nState);
                fprintf(1,'Qpows_%d=%s\n',nState,mat2str(Qpows));
                fprintf(1,'Qconsts_%d=%s\n',nState,mat2str(Qconsts));
            end
        end
        
    end
    
    methods(Abstract)
        addObservation(obj,obsData);
        [x,P]=getPositionAtTime(obj,time)
    end
    
end

