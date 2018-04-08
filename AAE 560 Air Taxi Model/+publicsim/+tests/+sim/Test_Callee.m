classdef Test_Callee < publicsim.sim.Callee
    %TEST_CALLEE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        numTimesCalled=0
        timesCalled
        mode=1
        runTimes
        lastRunId=1
    end
    
    methods
        
        function obj=Test_Callee()
            
        end
        
        function init(obj)
            if obj.mode==2
                rt=obj.runTimes;
                rt(rt<obj.instance.startTime)=[];
                obj.scheduleAtTime(min(rt));
                rt(1)=[];
                rt(rt>obj.instance.endTime)=[];
                obj.runTimes=rt;
            end
        end
            
        
        function runAtTime(obj,time)
            obj.disp_INFO(['Callee ' num2str(obj.id) ' called at ' num2str(time)]);
            obj.timesCalled=[obj.timesCalled time];
            obj.numTimesCalled=obj.numTimesCalled+1;
            
            if obj.mode==2
                if obj.lastRunId <= length(obj.runTimes)
                    obj.scheduleAtTime(obj.runTimes(obj.lastRunId));
                    obj.lastRunId=obj.lastRunId+1;
                end
            end
        end
        
        function setMode(obj,mode)
            obj.mode=mode;
        end
        
        function setRunTimes(obj,runTimes)
            obj.runTimes=sort(runTimes);
        end
        
    end
    
end

