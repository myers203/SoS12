classdef Instance < publicsim.tests.UniversalTester
    %INSTANCE Collection of simlulation elements required to run
    %   Contains runtime logic for executing events in order
    %
    %   Instance(logpath) returns a sim instance with logs in the logpath
    %
    %   AddCallee(callee) adds a callee to the callee list, required for it
    %   to be in the event queue
    %
    %   RemoveCallee(callee) removes the callee from the list, never to be
    %   called again
    %
    %   getAllCallees() returns a list of all callees, useful for finding
    %   particular callees
    %
    %   runUntil(startTime,endTime) runs the simulation from start to end
    
    properties(SetAccess = immutable,Transient=true)
        Scheduler %reference to sim.Scheduler
        Logger    %reference to sim.Logger
    end
    
    properties(SetAccess = private)
        CalleeMap       %Map between callee ID and object
        LastCalleeId=0; %Progressive callee id index
        endTime         %End of simulation time [s]
        startTime       %Start of simulation time [s]
        internalLogger  %Logger for sim-instance related messages
    end
    
    methods
        function obj = Instance(logpath)
            %Creates a new sim instance with a root logpath for file I/O
            obj.Scheduler=publicsim.sim.Scheduler(obj);
            obj.Logger=publicsim.sim.Logger(logpath);
            obj.CalleeMap=containers.Map('KeyType','int64','ValueType','any');
            obj.internalLogger=publicsim.sim.Loggable();
            obj.internalLogger.setLogger(obj.Logger);
            obj.internalLogger.setLogLevel(publicsim.sim.Logger.log_INFO);
        end
        
        function AddCallee(obj,callee)
            %Addes a callee to the list of callable callees
            id=obj.LastCalleeId+1;
            obj.LastCalleeId=id;
            obj.CalleeMap(id)=callee;
            callee.setId(id);
            callee.setInstance(obj);
            if isa(callee,'sim.Loggable') || isa(callee,'publicsim.sim.Loggable')
                callee.setLogger(obj.Logger);
            end
        end
        
        function RemoveCallee(obj,callee)
            %Removes a callee from the list--it will never be called
            id=callee.id;
            if isKey(obj.CalleeMap,id)
                obj.CalleeMap.remove(id);
            end
            %callee.setInstance([]);
        end
        
        function callees=getAllCallees(obj)
            %Returns a list of all callees useful for scanning
            callees=values(obj.CalleeMap);
        end
        
        function callee = getCallee(obj, id)
            if ~isKey(obj.CalleeMap, id)
                callee = [];
            else
                callee = obj.CalleeMap(id);
            end
        end
        
        function callInits(obj)
            %Initialize all the callees
            keyList=obj.CalleeMap.keys;
            for i=1:length(keyList)
                callee=obj.CalleeMap(keyList{i});
                if ~callee.hasBeenInit
                    callee.init();
                    callee.hasBeenInit=1;
                end
            end
        end
        
        function callLogInits(obj)
            %Initialize all callee logs
            keyList=obj.CalleeMap.keys;
            for i=1:length(keyList)
                callee=obj.CalleeMap(keyList{i});
                if ismethod(callee,'initLog')
                    callee.initLog();
                end
            end
        end
        
        function callFinis(obj)
            %Clean up for the callees, flush buffers etc.
            keyList=obj.CalleeMap.keys;
            for i=1:length(keyList)
                callee=obj.CalleeMap(keyList{i});
                callee.fini();
            end
            obj.Logger.fini();
        end
        
        function runUntil(obj,startTime,endTime)
            %Run the simulation from the start to the end time [s]
            obj.startTime=startTime;
            obj.endTime=endTime;
            obj.Scheduler.setCurrentTime(startTime);
            obj.internalLogger.disp_INFO(['\n Initializing Simulation at ' num2str(startTime) ' s' ...
                '\n Running Until ' num2str(endTime) ' s \n']);
            obj.callInits();
            obj.callLogInits();
            nextDispTime=-Inf;
            while (1)
                [callee,time,calleeFunction]=obj.Scheduler.getNextCallee();
                if isempty(callee) || isempty(time) || time>endTime
                    break;
                end
                calleeFunction(time);
                if time>=nextDispTime
                    obj.internalLogger.disp_INFO(['Sim Time ' num2str(round(time)) ' s']);
                    nextDispTime=floor(time/10)*10+10;
                end
            end
            obj.internalLogger.disp_INFO(['\n Finished Running at ' num2str(endTime) ' s' '\n Running Fini''s \n']);
            obj.callFinis();
            obj.Logger.fini();
            obj.internalLogger.disp_INFO('Finished Simulation');
        end
        
    end
    
    
    
    %%%%%%%% BEGIN TESTING %%%%%%%%%%%
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.sim.Instance.test_Instance()';
        end
    end
    
    methods(Static)
        function test_Instance()
            import publicsim.*;
            logpath='./tmp';
            simInst=sim.Instance(logpath);
            c1=tests.sim.Test_Callee();
            c2=tests.sim.Test_Callee();
            simInst.AddCallee(c1);
            simInst.AddCallee(c2);
            
            numExec=10000;
            startTime=10;
            endTime=400;
            execTimes_c1=rand(numExec,1)*500;
            execTimes_c2=rand(numExec,1)*500;
            for i=1:numExec
                c1.scheduleAtTime(execTimes_c1(i));
                c2.scheduleAtTime(execTimes_c2(i));
            end
            
            tic
            simInst.runUntil(startTime,endTime);
            etime=toc;
            util.cprintf('Text',['Time for Test 1: ' num2str(etime) '\n']);
            
            for i=1:numExec
                t1=execTimes_c1(i);
                if t1>=startTime && t1 <= endTime
                    assert(any(c1.timesCalled == t1),'Instance Test Error!');
                end
            end
            
            for i=1:length(c1.timesCalled)
                t1=c1.timesCalled(i);
                assert(any(execTimes_c1==t1),'Instance test Error!');
            end
            
            for i=1:numExec
                t2=execTimes_c2(i);
                if t2>=startTime && t2 <= endTime
                    assert(any(c2.timesCalled == t2),'Instance Test Error!');
                end
            end
            
            for i=1:length(c2.timesCalled)
                t2=c2.timesCalled(i);
                assert(any(execTimes_c2==t2),'Instance test Error!');
            end
            
            clear simInst c1 c2;
            
            simInst=sim.Instance(logpath);
            c1=tests.sim.Test_Callee();
            c2=tests.sim.Test_Callee();
            simInst.AddCallee(c1);
            simInst.AddCallee(c2);
            
            c1.setRunTimes(execTimes_c1);
            c1.setMode(2);
            c2.setRunTimes(execTimes_c2);
            c2.setMode(2);
            
            tic
            simInst.runUntil(startTime,endTime);
            etime=toc;
            util.cprintf('Text',['Time for Test 2: ' num2str(etime) '\n']);
            
            for i=1:numExec
                t1=execTimes_c1(i);
                if t1>=startTime && t1 <= endTime
                    assert(any(c1.timesCalled == t1),'Instance Test Error!');
                end
            end
            
            for i=1:length(c1.timesCalled)
                t1=c1.timesCalled(i);
                assert(any(execTimes_c1==t1),'Instance test Error!');
            end
            
            for i=1:numExec
                t2=execTimes_c2(i);
                if t2>=startTime && t2 <= endTime
                    assert(any(c2.timesCalled == t2),'Instance Test Error!');
                end
            end
            
            for i=1:length(c2.timesCalled)
                t2=c2.timesCalled(i);
                assert(any(execTimes_c2==t2),'Instance test Error!');
            end
            disp('Passed Instance Test!');
        end
        
    end
    
    
end

