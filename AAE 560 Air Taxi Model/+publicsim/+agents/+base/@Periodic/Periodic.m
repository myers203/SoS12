classdef Periodic < publicsim.sim.Callee
    %PERIODIC Agent that performs periodic activities
    %   Useful for sensors, movement, and any other periodic behaviors
    %
    %   addExtendedPeriodic(functionHandle,functionPeriod) calls
    %   functionHandle every functionPeriod seconds--useful for having
    %   multiple simultaneous loops executing with different periods
    %
    %   runAtTime:
    %   isRunTime() returns 1 if it is time to execute the periodic
    %   activity
    %
    %   
    
    properties(Access=private)
        runPeriod; %[s] running perioid for runAtTime
        lastRunTime=-Inf; %[s] last time agent executed based on the periodic function
        extraPeriodics %functions other than runAtTime for the periodic 
        okTimes = []; % Times of which it is OK to run that do not fall in the normal periodic time steps
        override = 0; % Overrides ability to run in between periodically scheduled times, but will not continuously re-schedule during overridden time
        lastOverrideTime = -inf;
    end
    
    properties(Constant)
        PERIODIC_ENTRY=struct('functionHandle',[],...
            'functionPeriod',[],...
            'periodicHandler',[]); %entry for extra periodics
    end
    
    methods
        function obj=Periodic()
        end
        
        function addExtendedPeriodic(obj,functionHandle,functionPeriod)
            %adds function handle to the periodic call list with the
            %provided period
            newPeriodicId=numel(obj.extraPeriodics)+1;
            periodicHandler=@(time) obj.extendedPeriodicHandler(newPeriodicId,time);
            newPeriodic=obj.PERIODIC_ENTRY;
            newPeriodic.functionHandle=functionHandle;
            newPeriodic.functionPeriod=functionPeriod;
            newPeriodic.periodicHandler=periodicHandler;
            if isempty(obj.extraPeriodics)
                obj.extraPeriodics=newPeriodic;
            else
                obj.extraPeriodics(end+1)=newPeriodic;
            end
            obj.scheduleAtTime(0,periodicHandler);
        end
        
        function extendedPeriodicHandler(obj,periodicId,time)
            periodicEntry=obj.extraPeriodics(periodicId);
            periodicEntry.functionHandle(time);
            obj.scheduleAtTime(time+periodicEntry.functionPeriod,periodicEntry.periodicHandler);
        end
        
        function v=isRunTime(obj,time)
            %returns true if runAtTime should process a periodic event
            if obj.lastRunTime+obj.runPeriod <= time
                v=1;
                obj.lastRunTime=time;
                obj.scheduleAtTime(time+obj.runPeriod);
            elseif any(find(time == obj.okTimes))
                % Time was previously marked as OK to run
                v = 1;
            elseif obj.override && (obj.lastOverrideTime ~= time)
                obj.lastOverrideTime = time;
                v = 1;
            else
                v=0;
            end
        end
        
        function setRunPeriod(obj,period)
            %set the period between periodic runs
            
            % Check to make sure the next call will execute
            if (period > obj.runPeriod)
                obj.scheduleAtTime(obj.lastRunTime + period);
            end
            obj.runPeriod=period;
        end
        
        function initPeriodic(obj,runPeriod)
            %starts the periodic execution process
            obj.runPeriod=runPeriod;
            obj.scheduleAtTime(0);
        end
        
        function addOkTime(obj, time)
            % Add OK run time to list
            obj.okTimes(end + 1) = time;
        end
        
        function enablePeriodicOverride(obj)
            % Enables override
            obj.override = 1;
            obj.lastOverrideTime = obj.lastRunTime; % Prevent double-run at current time
        end
        
        function disablePeriodicOverride(obj)
            obj.override = 0;
        end
        
        function runPeriod = getPeriodicRunPeriod(obj)
            runPeriod = obj.runPeriod;
        end
        
        %Overload these
        %         function runAtTime(obj,time)
        %             if obj.isRunTime(time)
        %                 obj.disp_DEBUG(['Run at time ' num2str(time)]);
        %             end
        %         end
        
        %Overload these
        %         function init(obj)
        %             obj.setLogLevel(sim.Logger.log_DEBUG);
        %             obj.disp_WARN('Unoverloaded Periodic Agent');
        %             obj.initPeriodic(1.5);
        %         end
        
        % Resets the last run time to 0
    end
    
    methods(Static,Access=private)
        function addPropertyLogs(obj) %#ok<INUSD>
            
            %No logs by default
        end
    end
    
    %%%% TEST METHDOS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.agents.base.Periodic.test_Periodic()';
        end
    end
    
    methods(Static)
        function test_Periodic()
            startTime = 0;
            endTime = 100.1;
            testSim=publicsim.sim.Instance('./tmp');
            periodicAgent=publicsim.tests.agents.base.PeriodicTest();
            testSim.AddCallee(periodicAgent);
            testSim.runUntil(startTime,endTime);
            assert(periodicAgent.timesRun == (floor(endTime - startTime) + 1), 'Periodic agent did not run the expected number of times!')
        end
    end
    
end

