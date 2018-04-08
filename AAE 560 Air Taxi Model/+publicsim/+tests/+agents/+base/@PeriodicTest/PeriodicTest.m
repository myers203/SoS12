classdef PeriodicTest < publicsim.agents.base.Periodic
    %PERIODICTEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        timesRun = 0; % Number of times runAtTime has run
    end
    
    methods
        
        function init(obj)
            obj.initPeriodic(1); % Run every second
        end
        
        function runAtTime(obj, time)
            % Increment the run counter
            if (obj.isRunTime(time))
                obj.timesRun = obj.timesRun + 1;
            end
        end
    end
    
end

