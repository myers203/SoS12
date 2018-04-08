classdef Scheduler < handle
    %SCHEDULER Event-Based Scheduling Logic
    %   Logic for scheduling events in a queue
    
    properties (SetAccess=private)
        eventQueue %JAVA queue of events
        eventMap %Map of event id to list of callees
        lastMapIdx=0; %progressive idx
        currentTime=0; %current time for preventing time travel
        instance %back-reference to the sim instance
    end
    
    properties(Constant)
        calleeStruct=struct('calleeId',[],'calleeFunction',[]);
    end
    
    methods
        function obj=Scheduler(instance)
            %returns a scheduler instance
            import java.util.*;
            obj.eventQueue=java.util.TreeMap;
            obj.eventMap=containers.Map('KeyType','int64','ValueType','any');
            obj.instance=instance;
        end
        
        function setCurrentTime(obj,time)
            %Sets the current time
            obj.currentTime=time;
        end
        
        function time=getCurrentTime(obj)
            %Gets the current time
            time=obj.currentTime;
        end
        
        function AddEvent(obj,callee,time,functionHandle)
            %Adds an event to the queue; if time < current time, time =
            %current time
            if time<obj.currentTime
                time=obj.currentTime;
            end
            V=obj.eventQueue.get(time);
            newCalleeEntry=obj.calleeStruct;
            newCalleeEntry.calleeId=callee.id;
            newCalleeEntry.calleeFunction=functionHandle;
            if isempty(V)
                idx=obj.lastMapIdx+1;
                obj.lastMapIdx=idx;
                obj.eventMap(idx)=newCalleeEntry;
                obj.eventQueue.put(time,idx);
            else
                calleeList=obj.eventMap(V);
                %If there is already a callee of this ID on the list at
                %this timestamp
                if any([calleeList.calleeId]==callee.id)
                    handleList={calleeList([calleeList.calleeId]==callee.id).calleeFunction};
                    exists=0;
                    for i=1:numel(handleList)
                        if isequal(handleList{i},functionHandle)
                            exists=1;
                            break;
                        end
                    end
                    if exists==0
                        calleeList(end+1)=newCalleeEntry;
                    end
                else
                    %No callee of this ID found at this time, add entry
                    calleeList(end+1)=newCalleeEntry;
                end
                obj.eventMap(V)=calleeList;
            end
            
        end
        
        function [callee,time,calleeFunction]=getNextCallee(obj)
            %returns the next callee in the event queue
            cid=obj.eventQueue.pollFirstEntry();
            %Events have ended
            if isempty(cid) || ~isKey(obj.eventMap,cid.getValue)
                callee=[];
                time=[];
                calleeFunction=[];
                return;
            end
            %JAVA returns the next time entry, entry map pair
            time=cid.getKey;
            calleeList=obj.eventMap(cid.getValue);
            calleeIdx=calleeList(1).calleeId;
            calleeFunction=calleeList(1).calleeFunction;
            
            %allows multiple events to occur simultaneously
            if length(calleeList) > 1
                calleeList=calleeList(2:end);
                obj.eventMap(cid.getValue)=calleeList;
                obj.eventQueue.put(time,cid.getValue);
            else
                remove(obj.eventMap,cid.getValue);
            end
            
            %Ignores removed callees
            if isKey(obj.instance.CalleeMap, calleeIdx)
                callee=obj.instance.CalleeMap(calleeIdx);
                if time < obj.currentTime %Nested popping
                    [callee,time,calleeFunction] = obj.getNextCallee();
                elseif time > obj.currentTime
                    obj.currentTime=time;
                end
            else
                [callee,time,calleeFunction] = obj.getNextCallee();
            end
            
        end
    end
    
    %%%%%%%% BEGIN TESTING %%%%%%%%%%%
    methods (Static)
        function test_Scheduler()
            import publicsim.*;
            logpath='./tmp';
            simInst=sim.Instance(logpath);
            c1=sim.Callee();
            c2=sim.Callee();
            simInst.AddCallee(c1);
            simInst.AddCallee(c2);
            sch=sim.Scheduler(simInst);
            sch.AddEvent(c1,5.1,'runAtTime');
            sch.AddEvent(c1,5.2,'OtherFunc');
            sch.AddEvent(c2,5.15,'OtherFunc2');
            
            [a1,t1,f1]=sch.getNextCallee();
            [a2,t2,f2]=sch.getNextCallee();
            [a3,t3,f3]=sch.getNextCallee();
            
            
            assert(isequal(a1,c1),'Scheduler Error!');
            assert(isequal(t1,5.1),'Scheduler Error!');
            assert(isequal(f1,'runAtTime'),'Scheduler Error!');
            assert(isequal(a2,c2),'Scheduler Error!');
            assert(isequal(t2,5.15),'Scheduler Error!');
            assert(isequal(f2,'OtherFunc2'),'Scheduler Error!');
            assert(isequal(a3,c1),'Scheduler Error!');
            assert(isequal(t3,5.2),'Scheduler Error!');
            assert(isequal(f3,'OtherFunc'),'Scheduler Error!');
            
            sch.AddEvent(c1,7.0,'runAtTime');
            sch.AddEvent(c2,7.0,'runAtTime');
            [a1,t1]=sch.getNextCallee(); %#ok<ASGLU>
            [a2,t2]=sch.getNextCallee(); %#ok<ASGLU>
            
            assert((isequal(a1,c1) && isequal(a2,c2)) || ...
                (isequal(a1,c2) && isequal(a2,c1)),'Scheduler Error!');
            util.cprintf('Text','Passed Scheduler Test!\n');
        end
    end
    
end

